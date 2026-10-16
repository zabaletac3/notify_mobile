# Traspaso · Fase 12 (endurecimiento y entrega local)

Rama `fase-12-endurecimiento`. Fecha: 2026-10-16. Los commits, el push y el PR los hace el dueño.
Plan detallado: `docs/plan-fase12.md`. Referencia: `docs/plan.md` §5.4, §11, §12 y fase 12.

## Estado por subfase

| Subfase | Contenido | Estado |
| --- | --- | --- |
| **12.1** | Medición base (release+perfil) | **Hecha** (tabla medido vs límite) |
| **12.2** | Optimización de lo que falle | **Hecha** (desplazamiento; el resto cumple) |
| **12.3** | Accesibilidad (TalkBack, 200 %, contraste) | **Hecha** (automático); TalkBack manual pendiente |
| **12.4** | Revisión de seguridad (`docs/security-review.md`) | **Hecha** (2 hallazgos corregidos) |
| **12.5** | Release firmado (R8 + firma) | **Configurado**; falta el almacén de claves del dueño |
| **12.6** | Prueba contra QA | **Guion listo**; falta el token de servicio y las URLs de QA |
| **12.7** | Cobertura, puerta Pencil de fase 9 y deuda | **Hecha** |
| **12.8** | README y cierre | **Hecha** |

## 12.1 · Presupuestos de la §11 (medido vs límite, ZTE 8050)

| Medida | Límite | Medido | Estado |
| --- | --- | --- | --- |
| Arranque en frío hasta la primera pantalla | 1,5 s | 469–594 ms | Cumple |
| Desbloqueo con biometría hasta la lista | 500 ms | — (requiere sesión + sensor; ver riesgo) | Pendiente manual |
| Argon2id real (64 MiB, t=3) | 3 s | 675 ms | Cumple |
| Abrir una nota de 10 KB | 150 ms | 10 ms | Cumple |
| Búsqueda por pulsación | 100 ms | 11 ms (frío) / 7 ms (caliente) | Cumple |
| Desplazamiento de 10 000 notas (p99) | ≤ 16 ms | 14,7–16,5 ms (mediana 15,7) | Cumple con reserva |
| Primera sincronización de 2 000 notas | 15 s, sin bloquear | 6 252 ms, bloqueo máx. 21 ms | Cumple |
| Memoria en reposo con la lista (2 000 notas) | 200 MB | PSS 180–182 MB | Cumple |
| Tamaño del APK arm64-v8a | 40 MB | 26,8 MB | Cumple |
| Nota de 100 KB: abrir / escribir | < 300 ms / sin retraso | 96 ms / 66 ms | Cumple |

Comandos y detalle en `docs/benchmarks.md` (sección «Fase 12»).

## 12.2 · Optimización

Solo el desplazamiento estaba en el filo. Se añadió **extensión exacta por fila**
(`itemExtentBuilder`, cabeceras 38 y tarjetas 80) a la lista de notas: los cuadros sobre 16 ms
bajaron de 8–15 a 4–13 por tanda y el p99 mejoró (14,7–16,5 ms). El p50 es de ~11,7 ms porque el
dispositivo refresca a 90 Hz. El margen sigue siendo estrecho y la medición debe repetirse con el
dispositivo en reposo; **no se cambia el límite**.

## 12.3 · Accesibilidad

Informe: `docs/design/fase12-accesibilidad.md`. Pruebas nuevas:
`app/test/ui/accessibility_contrast_test.dart` (46 comprobaciones de contraste WCAG, todas en verde)
y `app/test/features/a11y/text_scale_test.dart` (11 pantallas a texto 200 %, sin desbordes).

- **Correcciones**: tarjeta de nota y fila de ajustes pasan de altura fija a **mínima** (a escala 1
  miden igual; con el texto al doble crecen en vez de desbordar); la lista no fija la extensión de
  fila con texto ampliado; botones de icono de las barras a 40×48; botón «borrar» del buscador a
  48×48 con etiqueta semántica.
- **Hallazgos anotados**: `textTertiary` sobre `bgSelected` en oscuro 4,34:1 (solo en el resaltado de
  búsqueda); `statusSuccess` como texto en claro 4,47:1 (estado de sincronización); chips (33),
  menú lateral (34), barra de formato (40) y radio (20) por debajo de 48 dp. Corregirlos altera las
  medidas del diseño y los goldens; **decisión para el dueño**.
- **Pendiente manual**: recorrido con TalkBack por todos los flujos (guion en el informe). Requiere
  el dispositivo con el lector encendido y una cuenta.

## 12.4 · Seguridad

Informe: `docs/security-review.md`. Dos hallazgos **corregidos**:

1. **El APK de release no declaraba `INTERNET`** (Flutter solo lo aporta en debug/profile): el
   release no podía hablar con la API. Añadido al manifiesto principal y verificado con `aapt2`.
2. **No había configuración de red para el backend local**: añadida una `network_security_config`
   de debug que permite texto en claro solo a `localhost`/`127.0.0.1`/`10.0.2.2`. El release queda
   solo HTTPS (sin config, bloqueo por defecto con `targetSdk ≥ 28`).

El resto de la §5.4 está cubierto (evidencia por control en el informe). Pinning y App Links quedan
fuera de v1 (plan §1).

## 12.5 · Release firmado

- `app/android/app/build.gradle.kts` lee `key.properties` (si existe) para firmar el release; si no,
  cae a la clave de debug (la CI y los builds de desarrollo siguen sin secretos).
- Plantilla `app/android/key.properties.example` y guía `docs/guides/fase12-firma-release.md`.
- R8 con `minify`+`shrink`; la ofuscación de nombres la añade el comando con
  `--obfuscate --split-debug-info`.
- Verificado `apksigner verify` sobre el release (firmado con debug por ausencia del almacén):
  `Verifies`, esquema v2 correcto.
- **Falta**: crear el almacén local (`~/.axonote/axonote-release.jks`) y `key.properties` con las
  contraseñas (solo el dueño), y reinstalar el release firmado en el ZTE.

## 12.6 · Prueba contra QA

Guion paso a paso en `docs/guides/fase12-prueba-qa.md` (registro → verificación → nota →
sincronización → bloqueo → desbloqueo → compartir → importar/exportar → cambio de contraseña). La
prueba extremo a extremo automática contra el backend local ya existe
(`app/integration_test/auth_flow_integration_test.dart`). **Falta** el token de servicio y las URLs
de QA, que aporta el dueño.

## 12.7 · Cobertura, puerta Pencil y deuda

Cobertura por capa contra los mínimos de la §11:

| Capa | Mínimo | Medido |
| --- | --- | --- |
| `axonote_crypto` / `axonote_markdown` / `axonote_sync` | 95 % | 98,2 % / 99,1 % / 100 % |
| `axonote_domain` / `axonote_api` | 90 % | 93,3 % / 100 % |
| `app/lib/data` | 85 % | 87,2 % |
| Estado (`features/*/state`) | 80 % | 81,2 % |

Pruebas añadidas: `app/test/data/auth/api_auth_repository_test.dart` (19),
`app/test/features/settings/settings_controllers_test.dart` (7),
`packages/axonote_domain/test/models_test.dart`, y el arnés de medición
`app/integration_test/hardening_measurements_test.dart`.

Puerta geométrica de la fase 9: `app/test/features/notes/notes_compare_test.dart` (16 comprobaciones
de bandas y color contra Pencil; las capturas de 1076×2082 se recortan en memoria, sin tocar
`test/design_refs/`). Dos diferencias de espaciado del *chrome* (papelera ~6 px y etiqueta de
resultados ~5 px) quedan anotadas y acotadas en la prueba.

`docs/blockers.md` sin tareas abiertas. `docs/decisions.md` sin pendientes accionables nuevos (los
señalados son históricos y ya resueltos en fases posteriores).

## 12.8 · README y cierre

`README.md` con requisitos, instalación del toolchain, ejecución (`--dart-define`), pruebas y
puertas, medidas, y compilación de release con firma.

## Riesgos y pendientes

- **Solo el dueño puede cerrar**: crear el almacén de claves y `key.properties` y firmar/instalar el
  release en el ZTE (12.5); aportar token de servicio y URLs de QA y ejecutar el guion (12.6);
  recorrido manual con TalkBack (12.3). Nada de esto bloquea el resto.
- **Desbloqueo con biometría** (500 ms): no medido automáticamente (necesita sesión y sensor); se
  mide en la prueba manual del ZTE.
- **Desplazamiento**: presupuesto cumplido con reserva; repetir con el dispositivo en reposo.
- **Fase 13 (opcional, fuera de v1)**: identificador definitivo, App Links (`assetlinks.json`),
  restablecimiento de contraseña dentro de la app, ficha de privacidad y publicación por pruebas
  internas.
- **Fuera de v1** (plan §1): iOS, Google, completar el restablecimiento en la app, sincronización en
  segundo plano, Play Store y pinning de certificado.
