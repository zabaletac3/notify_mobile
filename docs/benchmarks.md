# Benchmarks

Mediciones reales. La §11 del plan fija los presupuestos; aquí se anotan los valores medidos.

Dispositivo de referencia: ZTE 8050 (Android 13, API 33, arm64). Flutter 3.47.7 (stable) ·
Dart 3.13.5 · JDK Temurin 17 · Android SDK 36.

## Fase 0 · Comprobaciones de dependencias

**Resultado: las cuatro comprobaciones pasan en el ZTE (2026-10-10).**

App de comprobación (desechable, fuera del repo): `~/development/axonote_dep_probe`.
La compilación a APK de debug incluye `libsodium.so` y `libsqlite3mc.so` (arm64-v8a,
armeabi-v7a, x86_64). Requirió vendorizar y parchear `appflowy_editor` y subir el `compileSdk` de
plugins (ver `docs/decisions.md`).

| Comprobación | Resultado | Tiempo | Notas |
| --- | --- | --- | --- |
| `sodium` Argon2id = `authKey` de `kdf.json` (caso `light`, 1 MiB / t=1) | OK | 65 ms | coincide byte a byte |
| `sodium` Argon2id = `authKey` de `kdf.json` (caso `default`, 64 MiB / t=3) | OK | **593 ms** | límite ≤ 3 s; muy por debajo |
| `drift` + `sqlite3mc`: `PRAGMA cipher` responde | OK | — | `chacha20` |
| `drift` + `sqlite3mc`: `PRAGMA compile_options` incluye `ENABLE_FTS5` | OK | — | FTS5 disponible |
| `drift` + `sqlite3mc`: abrir con clave, cerrar, reabrir con clave errónea falla | OK | — | clave errónea rechazada; relee bien con la correcta |
| `appflowy_editor` compila y edita con Flutter 3.47.7 | OK | — | vendorizado + parche (§12); documento inicial 1 bloque |
| `cryptography`: casos de `sealed.json` abren | OK | — | `contexto`, `nota-data`, `vacio` |

Conclusión de la fase: las dependencias elegidas (D10, D11, D12, editor) funcionan en el
dispositivo de referencia con el Flutter estable actual. Argon2id cumple el presupuesto.

## Fase 6 · Datos locales

**ZTE 8050 (Android 13, API 33), `--profile`, 2026-10-11.** Comando:

```
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/local_performance_test.dart -d LZ0V50COPBC002769 --profile
```

La lista inicial es una **página de 200 notas** (plan §4.4: no se materializa toda la colección).
Desde la revisión de la fase 6 la prueba usa la **base cifrada real** (archivo en el directorio de
la app, clave derivada del Vault), como en producción, y mide en frío (tras cerrar y reabrir) y en
caliente.

| Medida (base cifrada) | 2 000 notas | 10 000 notas | Límite §11 |
| --- | --- | --- | --- |
| Lista inicial, frío | 7 ms | **8 ms** | < 50 ms |
| Lista inicial, caliente | 5 ms | **7 ms** | < 50 ms |
| Búsqueda, frío | 8 ms | **12 ms** | < 100 ms |
| Búsqueda, caliente | 5 ms | **10 ms** | < 100 ms |
| Generar 10 000 notas (semilla) | — | ~10 s | — |

```
Fase 6 · 2000 cifrada: seed=1722ms cold list=7ms search=8ms · warm list=5ms search=5ms
Fase 6 · 10000 cifrada: seed=9960ms cold list=8ms search=12ms · warm list=7ms search=10ms
```

El índice `notes(deleted_at, updated_at)` (ver `docs/decisions.md`) fue lo que bajó la lista de
10 000 notas de 74 ms a ~8 ms. La lista sin límite no cumple el presupuesto, y por eso la interfaz
trabaja por páginas.

## Fase 9 · Desplazamiento de la lista

**ZTE 8050 (Android 13, API 33), `--profile`, 2026-10-14.** Comando:

```
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/notes_scroll_performance_test.dart -d LZ0V50COPBC002769 --profile
```

Siembra 10 000 notas en la base cifrada real, abre la pantalla de notas y la desplaza con 12
lanzamientos; mide el tiempo por cuadro con `SchedulerBinding.addTimingsCallback` y exige el
presupuesto de la §11 (sin cuadros > 16 ms en el percentil 99). La pantalla carga por páginas de
200 notas (plan §4.4), el agrupado se calcula una vez por cambio de datos y los conteos no se
reagregan al crecer la ventana.

| Medida | Valor (última ejecución) | Límite §11 |
| --- | --- | --- |
| p50 por cuadro | **11,7 ms** | — (≈ un cuadro de 90 Hz) |
| p99 por cuadro | **15,8 ms** | ≤ 16 ms |
| Cuadros > 16 ms | **8 de 962** | — |
| Semilla (10 000 notas) | ~10,6 – 13,5 s | — |

```
Fase 9 · 10000 notas scroll: seed=10592ms frames=961 en 24867ms · p50=11.8ms p99=16.4ms cuadros>16ms=11
Fase 9 · 10000 notas scroll: seed=12372ms frames=961 en 24818ms · p50=11.0ms p99=18.3ms cuadros>16ms=26
Fase 9 · 10000 notas scroll: seed=12800ms frames=962 en 24932ms · p50=11.7ms p99=17.1ms cuadros>16ms=16
Fase 9 · 10000 notas scroll: seed=13465ms frames=962 en 24898ms · p50=11.7ms p99=15.8ms cuadros>16ms=8   ← código final
```

**Cumple el presupuesto de la §11** en el código final (p99 15,8 ms ≤ 16 ms; la mediana es un cuadro
de 90 Hz). Las tres primeras filas son mediciones intermedias, cuando la lista aún reagregaba los
conteos en cada página: el p99 se quedaba entre 0,4 y 2,3 ms por encima. Al desacoplar los conteos
de la paginación (`notesChangedProvider`) y memoizar el agrupado (`notesRowsProvider`) bajó a 15,8.
La medición varía entre ejecuciones (8, 11, 16 y 26 cuadros sobre 16 ms), así que el margen es
estrecho y conviene repetirla con el dispositivo en reposo antes de dar el presupuesto por bueno.

### (En memoria, **no válidas** · superadas)

Estas cifras se midieron antes de la revisión con `LocalDatabase.memory` (sin cifrar). **No son
válidas** como medición de producción y quedan solo como histórico:

| Medida (en memoria) | 2 000 notas | 10 000 notas |
| --- | --- | --- |
| Lista inicial (página de 200) | 6 ms | 4 ms |
| Búsqueda (página de 200) | 6 ms | 7 ms |
| Lista completa sin límite | 46 ms | 271 ms |
