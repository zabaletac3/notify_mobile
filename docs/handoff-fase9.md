# Traspaso · Fase 9 (notas)

Rama `fase-9-notas`. Fuente de diseño: documento de **Pencil** «axonote» (sección *Móvil*), leído
tablero a tablero; medidas en `docs/design/pencil-measurements.md`. Comportamiento de referencia:
`notify_web` (no se tocó). No se hizo commit, push ni PR (los hace el dueño).

## Hecho

- **Pantallas** (`app/lib/features/notes/ui/`), todas en claro y oscuro con goldens:
  - `notes_screen.dart` — lista de notas (`/notes`) y de carpeta (`/folders/:id`): barra superior
    (menú, título con chevron, «más»), conteo, buscador, chips de carpeta, grupos
    (Fijadas · Hoy · Esta semana · mes), tarjetas y FAB «Nueva nota». Estados: vacío de primera vez
    (`/notes` sin notas), carpeta vacía, carga (esqueletos), error de servidor y sin conexión.
  - `trash_screen.dart` — papelera (`/trash`): aviso de 30 días, días restantes por nota, «Vaciar»
    con confirmación y vacío.
  - `search_screen.dart` — búsqueda (`/search`): término, conteo, resultados con el término
    resaltado y vacío con «Borrar búsqueda».
  - Hojas y diálogos (`note_sheets.dart`, `conflict_sheet.dart`): menú contextual de la nota
    (fijar/desfijar, mover, cambiar nombre, duplicar, papelera; restaurar y eliminar
    definitivamente en la papelera), selector de carpeta para mover, «Nueva carpeta» con contador,
    confirmación de papelera, conflicto de sincronización con las tres opciones (esta versión,
    versión de la nube, conservar ambas) y menú de orden.
- **Acciones por gesto (deslizar)** en la lista y en la papelera (`swipe_tile.dart`, `AxoSwipeTile`
  + `AxoSwipeAction`): a la derecha fija/desfija (vuelve a su sitio) y a la izquierda manda a la
  papelera con «Deshacer»; en la papelera, a la derecha restaura y a la izquierda elimina con
  confirmación. Ni el tablero de Pencil ni `notify_web` definen los gestos: se decidieron y
  documentaron en `docs/decisions.md` (fase 9, «Gestos de la lista»), con pruebas en
  `app/test/features/notes/notes_swipe_test.dart`.
- **Papelera con días restantes**: la regla (`daysUntilPurge`, 30 días, mínimo 0) y el texto
  («Se elimina en N día(s)») son los mismos que en `notify_web`, con pruebas que los fijan
  (`packages/axonote_domain/test/note_query_test.dart` y
  `app/test/features/notes/note_dates_test.dart`), prueba de pantalla
  (`notes_swipe_test.dart` comprueba los textos en la papelera) y el golden `notes-papelera-*`. Se
  alinearon además los demás textos de avisos y diálogos con la web y crear una carpeta desde
  «Mover a carpeta» ahora mueve la nota a la carpeta nueva.
- **Estado** (`app/lib/features/notes/state/`): `notes_view` (filtro+orden), `notes_providers`
  (lista paginada, filas agrupadas, carpetas, conteos, búsqueda), `notes_actions` (acciones →
  `Result`), `note_dates` (fechas de la lista y de la papelera).
- **Componentes** nuevos en `app/lib/ui/components/`: `folder_chip`, `note_group_header`,
  `search_field`, `fab`, `skeleton`, `empty_state`, `offline_banner`, `option_row`, `radio`,
  `drawer`. Actualizados: `note_card` (tarjeta plana del diseño nuevo), `bottom_sheet` (`bgEditor`),
  `dialog` (relleno 24 e ilustración 56/64 con variante de peligro), `banner` (variante `note`).
- **Tokens** nuevos en `tokens.dart` (tipografía 16/400, 15/500, 15/600, 14/500, 14/600, 13/600,
  12/500, 11/500, 11/600; radios 10 y 18; tamaños 48, 33, 38, 34, 304, 92, 80, 48), medidos y
  documentados con su tablero.
- **Lista por páginas**: páginas de 200, `ListView.builder` sobre filas aplanadas, agrupado
  memoizado (`notesRowsProvider`) y conteos desacoplados de la paginación.
- **Sesión local**: `app/lib/app/local_session.dart` abre `SyncSession` al desbloquear y lo cierra al
  bloquear/cerrar sesión; `VaultLifecycle.onLocked` nuevo; `deviceId` en el almacén seguro.
- **`Note.preview`** en el dominio (la tarjeta necesita la vista previa y `list()` no trae `content`).
- **Goldens nuevos**: 14 pantallas × claro/oscuro en `app/test/features/notes/goldens/`
  (`notes_screens_golden_test.dart`); regenerados los de `note-card`, `bottom-sheet`, `dialog` y
  «diálogo de sesión expirada» por los cambios de componente.

## Puertas

Ejecutadas en esta terminal (Flutter estable, JDK 17, Android SDK cargados).

| Puerta | Resultado |
| --- | --- |
| `dart format --output=none --set-exit-if-changed …` (el de CI) | **OK** (`Formatted 209 files (0 changed)`) |
| `flutter analyze` | **OK** (`No issues found!`) |
| `flutter test` (app) | **OK** · 235 pruebas |
| `flutter test` por paquete con `test/` | **OK** · domain 66 · crypto 133 · api 72 (+1 omitida) · sync 10 · platform 26 |
| `dart run tool/check_imports.dart` | **OK** (`Arquitectura correcta.`) |
| `NOTIFY_WEB=… bash tool/check_contract.sh` | **OK** (`Contrato correcto.`) |
| `cd app && flutter build apk --debug` | **OK** (`Built build/app/outputs/flutter-apk/app-debug.apk`) |
| `flutter drive … notes_scroll_performance_test.dart --profile` (ZTE) | **OK** · p50 11,7 ms · **p99 15,8 ms ≤ 16 ms** (§11) |

## Pendiente / riesgos

- **El desplazamiento cumple la §11 pero con poco margen**: p99 15,8 ms frente al límite de 16 ms
  (8 cuadros de 962 por encima de 16 ms), y la medida varía mucho entre ejecuciones (8, 11, 16 y 26
  cuadros). Si se toca la paginación, el agrupado o los conteos de la lista, hay que volver a medir
  (`docs/benchmarks.md` tiene el comando y las cifras).
- **Iconos**: el set vendorizado `assets/icons/` no tiene `compose`, `more`, `share`, `notes`,
  `close` ni `sidebar` (los del documento de Pencil). Se usan los equivalentes existentes
  (`pencil`, `ellipsis`, `share-2`, `file-text`, `x`, `menu`) en vez de dibujar SVG nuevos. Faltan
  también `rotate-ccw` (restaurar → `arrow-left`) y `folder-x` (→ `folder`).
- **Compartir** en el menú contextual es de la fase 11: la entrada del tablero no se implementa.
- **«Bloquear» y «Cerrar sesión»** viven en el menú «más» de la lista mientras no existan los ajustes
  (fase 11), para no perder el ciclo de sesión de la fase 8. No están en el tablero.
- **La fase 9 tocó la costura 7↔8**: abre la base local al desbloquear (`SyncSession.open`), lo que no
  había hecho ninguna fase; conviene que la fase que cierre la sincronización no la duplique.
- **`Note.preview`** cambia el dominio (campo nuevo con valor por defecto): si otra rama toca `Note`,
  hay que integrarlo.
- No se probó la interfaz de notas a mano en el dispositivo (solo goldens y la prueba de
  desplazamiento); queda para el recorrido manual.

## Diferencias de diseño encontradas (Pencil ↔ lo que había)

- La tarjeta de nota del diseño nuevo es una **fila plana sin relleno** (el componente de la fase 2
  usaba `bgEditor`).
- La **hoja inferior** es `bgEditor` con el contenedor de acciones en `bgApp` (la fase 2 la tenía
  `bgApp` de fondo); el diálogo se rellena a **24** (la fase 2, 28) y su ilustración es **56**
  (peligro, `statusDangerBg`) o **64** (`bgSelected`).
- El **aviso de sin conexión** usa `bgHover`; el de la papelera, `bgSelected`; el `AxoBanner` «info»
  de la fase 2 usaba `bgInput`.
- El **buscador** lleva texto 16/400 y radio 28; los **chips** 33 de alto, radio 10 y etiqueta
  14/500 (14/600 el activo); el **FAB** 54 de alto, radio 18 y etiqueta 15/600.
- El **drawer** es 304 de ancho, `bgSidebar`, radios [0,20,20,0], elementos de 34 (radio 8) y
  encabezados de sección 11/600 en mayúsculas.
- El **conflicto de sincronización** es una **hoja inferior** (no un diálogo) con dos tarjetas de
  versión y dos botones.
- El botón de los estados vacíos mide 48 de alto; se usa `AxoButton` medio (46) — 2 px de diferencia,
  anotada.
- **Los gestos (deslizar) no están en el diseño**: el documento de Pencil no los define y
  `notify_web` tampoco los tiene, así que se decidieron y se documentaron en `docs/decisions.md`
  (fase 9). No hay golden de un estado deslizado porque el tablero no lo muestra.
