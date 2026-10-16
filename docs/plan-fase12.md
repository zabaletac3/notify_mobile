# Plan de la fase 12 · Endurecimiento y entrega local

Rama `fase-12-endurecimiento` (parte de `fase-11-paridad`, PR #10 aún abierto). Referencia: `docs/plan.md`
§5.4, §11, §12 y fase 12 de la §10. **Hecho cuando** (plan): APK de release instalado y usado en el ZTE
contra QA; todos los presupuestos cumplidos y anotados en `docs/benchmarks.md`; ninguna tarea abierta en
`docs/blockers.md`.

## Reglas
- Una subfase a la vez. Al cerrar cada una: puertas completas (format de CI, `flutter analyze` sin avisos,
  `flutter test` de la app y de cada paquete con `test/`, `tool/check_imports.dart`, `NOTIFY_WEB=… tool/check_contract.sh`,
  `flutter build apk --debug`), y actualizar `docs/handoff-fase12.md` y `docs/benchmarks.md`.
- Nunca se debilita una prueba, un vector ni un golden. Nunca se registran contraseñas, claves, tokens,
  códigos ni texto de notas.
- Las medidas se hacen en el ZTE (Android 13, build de perfil o release, cuenta de prueba con 2 000 notas
  sembradas, no la cuenta real). Si `adb devices` no lo ve: sigue con lo que no lo necesite, anótalo y avisa.
- Si un presupuesto no se alcanza: busca la causa, corrige si es razonable; si no, anota medida real y causa
  en `docs/benchmarks.md` (plan §11). No cambies el límite.
- Sin commits, push ni PR (los hace el dueño). El almacén de claves y sus contraseñas NUNCA entran al repo.

## 12.1 Medición base (sin cambiar código)
Compila release (`flutter build apk --release --split-per-abi`) y perfil. Mide y registra en `docs/benchmarks.md`
con comando, dispositivo y número de ejecuciones: arranque en frío hasta el desbloqueo (1,5 s), desbloqueo con
biometría hasta la lista (500 ms), Argon2id real (3 s), abrir nota de 10 KB (150 ms), búsqueda por pulsación
(100 ms), desplazamiento (p99 ≤ 16 ms con 2 000 y con 10 000 notas), primera sincronización de 2 000 notas
(15 s, con progreso y sin bloquear), memoria en reposo con la lista (200 MB), tamaño del APK arm64 (40 MB),
nota de 100 KB (abrir < 300 ms; escribir sin retraso). Entrega una tabla medido vs límite.

## 12.2 Optimización de lo que falle
Para cada medida fuera de límite: perfila (DevTools/timeline), corrige la causa (shaders, carga diferida,
isolates, tree-shaking de iconos/fuentes, R8/ProGuard, recorte de recursos, ABI split, dependencias pesadas),
vuelve a medir y anota antes/después. Revisa que la lista no regrese (el margen del p99 era estrecho).

## 12.3 Accesibilidad
TalkBack en todos los flujos (registro/ingreso/desbloqueo, lista, editor, papelera, búsqueda, ajustes,
2FA, compartir, importar/exportar): etiquetas semánticas, orden de foco, estados (activo/seleccionado),
anuncio de errores y toasts, áreas táctiles ≥ 48 dp. Texto al 200 %: ninguna pantalla desborda ni oculta
acciones (pruebas de widget con `textScaler` 2.0 y goldens donde aporte). Contraste AA en claro y oscuro
(prueba automática sobre los tokens). Lista los hallazgos y corrígelos.

## 12.4 Revisión de seguridad
Recorre la lista de la §5.4 del plan y `notify_backend/docs/security.md`; para cada casilla, evidencia
(archivo/línea o prueba) o hallazgo. Mínimo: `allowBackup`/copias, `FLAG_SECURE` y vista previa en recientes,
captura de pantalla, almacenamiento seguro y su borrado al cerrar sesión/`device-revoked`, bloqueo por tiempo y
al salir, tráfico solo HTTPS (cleartext solo en debug), `network_security_config`, pinning (decidir y
documentar), logs sin secretos (grep + prueba), portapapeles (enlaces/códigos de respaldo), deep links y
`exported` en el manifiesto, permisos mínimos, ofuscación en release, rotación de clave y cambio de
contraseña no dejan material viejo, la base local cifrada. Entrega `docs/security-review.md` con hallazgos y
correcciones aplicadas; los que no se corrijan, con riesgo y motivo.

## 12.5 Release firmado
Crea un almacén de claves LOCAL fuera del repo (por ejemplo `~/.axonote/release.jks`), con contraseñas que
solo yo conozco: NO las generes ni las muestres en chat ni en archivos versionados; deja `key.properties`
(ya ignorado por `.gitignore`) para que el dueño ponga los valores, y un script/README que lo explique. Configura
`signingConfigs` leyendo `key.properties`, R8 con minify y shrink, y que la CI siga compilando debug sin
secretos. Compila el APK de release firmado, verifica con `apksigner verify`, y si el dueño provee el
almacén, instálalo en el ZTE.

## 12.6 Prueba contra QA
Con la API de QA y el token de servicio (te lo daré yo en el momento; no lo escribas en ningún archivo ni
log): flujo completo registro → verificación → nota → sincronización → bloqueo → desbloqueo → compartir →
importar/exportar → cambio de contraseña, con una cuenta de prueba, desde el release en el ZTE. Si no tienes
el token, deja el guion paso a paso en `docs/guides/fase12-prueba-qa.md` y avisa. Extremo a extremo con
`integration_test` contra el backend local (plan §11) si aún no existe.

## 12.7 Cobertura y deuda
Mide cobertura por capa contra los mínimos de la §11 (crypto/markdown/sync 95 %, domain/api 90 %, data 85 %,
estado 80 %) y añade las pruebas que falten. Puerta geométrica contra Pencil para las pantallas de la fase 9
(patrón de `app/test/design/`) y su informe. Revisa `docs/blockers.md` y `docs/decisions.md` por pendientes.

## 12.8 README y cierre
`README.md` con requisitos, instalación del toolchain, ejecución (`--dart-define=API_URL`, `SHARE_ORIGIN`),
pruebas, medidas, compilación de release y firma. `docs/handoff-fase12.md` con: qué se hizo, tabla de
presupuestos medido vs límite, hallazgos de accesibilidad y seguridad, riesgos y pendientes (fase 13 y fuera
de v1). `docs/blockers.md` sin tareas abiertas.

## Orden y paradas
12.1 → 12.2 → 12.3 → 12.4 → 12.5 → 12.6 → 12.7 → 12.8. Continúa sin esperar OK entre subfases salvo bloqueo
real (anótalo en `docs/blockers.md`) o necesidad de algo que solo el dueño tiene (almacén de claves, token QA,
ZTE conectado): en ese caso termina lo demás y lista exactamente qué falta. Si tu contexto se acerca al límite,
cierra la subfase en curso con puertas en verde y deja el estado exacto en `docs/blockers.md`.
