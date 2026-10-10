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
