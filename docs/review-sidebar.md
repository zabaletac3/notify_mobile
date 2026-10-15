# Revisión del menú lateral (drawer) — rama `fase-10-editor`

> **Estado: corregido (2026-10-15).** Las correcciones de la §5 están aplicadas; el resultado y las
> cifras están en la última sección, «Correcciones aplicadas». El resto del documento conserva el
> diagnóstico original.

Alcance: `app/lib/ui/components/drawer.dart`, `app/lib/features/notes/ui/notes_screen.dart`
(`_buildDrawer` y navegación) y `app/lib/router/app_router.dart`. Contraste con el tablero de Pencil
**«Android — Menú lateral»** (`axonote.pen` → frame *Movil v2* `n5R1U` → board `gmDDZ` → `Drawer`
`YjqDM`) y con las capturas de `app/test/design_refs/` (`Android — Menú lateral.png`). Pruebas nuevas:
`app/test/features/notes/notes_drawer_test.dart` (no se tocó código de producción; sin commits).

## Resumen

- **El drawer no se abre nunca desde la app.** Causa raíz: `Scaffold.of(context)` en
  `notes_screen.dart:226-227` se llama con el `context` del propio `NotesScreen` (que está **por
  encima** del `Scaffold` que ese mismo `build` devuelve), no con uno por debajo. Flutter lanza
  `Scaffold.of() called with a context that does not contain a Scaffold` y el gesto no hace nada
  visible. Es exactamente el «el sidebar no funciona» del ZTE.
- **Una vez abierto a mano, las cinco entradas funcionan**: navegan/filtran y las rutas destino
  existen (`/notes`, `/folders/:id`, `/trash`) salvo que el destino no esté implementado (Ajustes,
  fase 11). No hay enlaces roscados entre las entradas actuales.
- **Falta el estado activo** (diseño: variante `State=Selected`) en todo salvo «Todas las notas».
- **El drawer no tiene ninguna prueba ni golden**: por eso el fallo pasó la fase 9.

## 1. Entradas de hoy, destino y estado

Código: `notes_screen.dart:308-373`. Orden: `Biblioteca` (Todas las notas, Fijadas), `Carpetas`
(cada carpeta), `Etiquetas` (solo si hay), `Papelera`, y al pie `Nueva carpeta`
(`notes_screen.dart:299-374`; `drawer.dart:96-194`).

| Entrada | Acción (`onTap`) | Destino | Ruta/pantalla destino | ¿Existe? | Prueba |
| --- | --- | --- | --- | --- | --- |
| Todas las notas | `_goFolder(context, ref, null)` → `setFilter(All)` + `context.go('/notes')` | `/notes` | `NotesScreen` — `app_router.dart:97-107` | Sí | **PASA** |
| Fijadas | `setFilter(Pinned)` + `context.go('/notes')` | `/notes` | `NotesScreen` (misma ruta, filtro) | Sí | **PASA** |
| Cada carpeta | `_goFolder(context, ref, folder.id)` → `setFilter(Folder)` + `context.go('/folders/$id')` | `/folders/:id` | `NotesScreen(folderId: …)` — `app_router.dart:108-112` | Sí | **PASA** |
| Cada etiqueta | `setFilter(Tag)` + `context.go('/notes')` | `/notes` | `NotesScreen` (misma ruta, filtro) | Sí | **PASA** |
| Papelera | `context.go('/trash')` | `/trash` | `TrashScreen` — `app_router.dart:113` | Sí | **PASA** |
| Nueva carpeta | `showNewFolderSheet(context, ref)` | diálogo | `note_sheets.dart:341` | Sí | (no cubierta) |
| Cerrar (aspa) | `Navigator.of(context).pop()` | — | cierra el drawer | Sí | (Vía gesto/metadata) |

Resultado de `flutter test test/features/notes/notes_drawer_test.dart` (**8 pruebas, 5 pasan, 3 fallan**):

| # | Prueba | Resultado |
| --- | --- | --- |
| 1 | el botón de menú abre el drawer | **FALLA** (excepción `Scaffold.of`) |
| 2 | el título abre el drawer | **FALLA** (excepción `Scaffold.of`) |
| 3 | «Todas las notas» está activa al abrir el drawer | PASA |
| 4 | «Fijadas» filtra las fijadas (y cierra el drawer) | PASA |
| 5 | una carpeta navega a `/folders/:id` | PASA |
| 6 | una etiqueta filtra por etiqueta | PASA |
| 7 | «Papelera» navega a `/trash` | PASA |
| 8 | la entrada activa (Fijadas) queda marcada al reabrir | **FALLA** |

Nota: las pruebas 3-7 abren el drawer con `ScaffoldState.openDrawer()` (no con el botón), para aislar
la navegación del fallo de apertura. La 4 comprueba además que el drawer se cierra al navegar
(`Navigator.of(context).pop()` con la entrada de historial local del `Scaffold`): funciona.

## 2. Diferencias con el tablero del menú lateral

El tablero `gmDDZ` (y el `Sidebar` de Escritorio `ZSnOb` y de la Web `pRnwt`) contienen **exactamente**
estas entradas: `Apunte` + icono *sidebar* en la marca, `BIBLIOTECA` (Todas las notas *seleccionada*,
Fijadas), `CARPETAS` (4 carpetas), `ETIQUETAS` (3 etiquetas), un espaciador, `Papelera` y
`+ Nueva carpeta`, todas con contador. La app replica esa estructura, con estas diferencias:

- **Marca**: el diseño dice «Apunte» con icono `sidebar`; la app dice «AxoNote»
  (`drawer.dart:146`) y usa `x` para cerrar (`drawer.dart:153`). Ya está anotado como desviación
  deliberada en `docs/decisions.md:988-992` (el set de `assets/icons/` no tiene `sidebar`).
- **Estado activo/foco**: el diseño define la variante `State=Selected` del `SidebarItem`
  (`f25kqx`): fondo `#DCE7F5` (token `bgSelected`), etiqueta 14/600 y contador en `accent`. La app
  **solo** marca «Todas las notas» (`notes_screen.dart:317`); Fijadas, cada carpeta, cada etiqueta y
  Papelera no se marcan nunca al estar activas (`notes_screen.dart:323-371`, ninguna pasa
  `selected`). En claro y oscuro el token existe (`tokens.dart:56-57,76-77`).
- **Contadores**: el diseño los muestra siempre; la app los cubre, pero muestra `0` cuando los
  conteos aún son `null` (`counts?.all ?? 0`, `notes_screen.dart:316`, etc.), mientras el diseño
  mostraría el valor real/esqueleto.
- **Posición de Papelera / Nueva carpeta**: en el diseño ambas están pegadas al pie (Papelera arriba
  de Nueva carpeta). En la app `Nueva carpeta` va fija al pie (`drawer.dart:159-187`) pero Papelera
  está **dentro** del `ListView` que hace scroll (`notes_screen.dart:362-371`); con muchas carpetas
  Papelera se desplaza y se separa de «Nueva carpeta».
- **Scroll**: sin problema funcional detectado; el `ListView` de secciones scrollea bajo la marca y
  sobre el pie.
- **Modo oscuro**: no hay tablero móvil «Menú lateral (oscuro)» ni PNG en `design_refs/`. El drawer
  usa el `AxoColors` del tema, así que debería derivar bien, pero **no está verificado** por golden.
- **Entradas que NO están en el diseño**: `Ajustes`, `Buscar` y `usuario/correo` **no aparecen en el
  tablero móvil** (ni en el `Sidebar` de escritorio/web). No son un hueco del drawer; meterlos sería
  un cambio de diseño. `Buscar` se resuelve con la barra de búsqueda de la lista
  (`notes_screen.dart:120-123`); `Ajustes`/cuenta son fase 11 (ver §4).

## 3. Defectos concretos

- **D1 (crítico) — el drawer no se abre.** `notes_screen.dart:226-227`:
  `onMenu: () => Scaffold.of(context).openDrawer()` y `onTitleTap` con el mismo `Scaffold.of(context)`.
  `context` es el de `NotesScreen` (el que construye el `Scaffold`), no un descendiente: `Scaffold.of`
  busca un `Scaffold` *ancestro* y no lo encuentra. La excepción se captura en el gesto y no se ve
  pantalla roja; simplemente «no pasa nada». Afecta a los dos disparadores (botón de menú y toque en
  el título), que son las dos únicas formas de abrir el drawer en la lista
  (`grep openDrawer` solo lo encuentra ahí).
- **D2 — estado activo incompleto.** Solo «Todas las notas» recibe `selected`
  (`notes_screen.dart:317`). El helper `folderIdIsAll(ref, null)` (`notes_screen.dart:377-380`)
  ignora su segundo parámetro y solo comprueba `filter is NotesFilterAll`; para Fijadas / carpeta /
  etiqueta / Papelera no se consulta el filtro actual. El usuario ve que la lista cambia, pero al
  reabrir el drawer ninguna otra entrada aparece resaltada (prueba 8 falla).
- **D3 — ausencia de cobertura.** No existía ninguna prueba ni golden del drawer
  (`grep` de `AxoDrawer`/`openDrawer` en `app/test/`: sin resultados). Tampoco está en
  `notes_screens_golden_test.dart`. Por eso D1 llegó al dispositivo.
- **D4 (menor) — `counts == null` se muestra como `0`** al pie de cada entrada
  (`notes_screen.dart:316,326,340,352,366`), que se ve como «vacío» durante la carga.
- No se encontraron defectos de **gestos**, **scroll**, **drawer sobre el teclado** (la lista no tiene
  campo de texto) ni **cierre al navegar** (el `Navigator.pop` sobre la entrada de historial cierra el
  drawer; se verificó en la prueba 4). El gesto de borde para abrir (por defecto en `Drawer`) y el
  toque en el *scrim* funcionan, pero quedan inalcanzables en la práctica porque el botón visible es
  el que falla.

## 4. Lo que falta en la app

### (a) Fallo/hueco de la fase 9

- D1: el drawer no abre (bloqueante de la pantalla «Menú lateral» de `docs/screens.md` §3/§4).
- D2: estado activo del drawer.
- D3: prueba de widget + golden del drawer (claro y oscuro).

### (b) Pertenece a la fase 11 (según `docs/plan.md:603-611` y `docs/screens.md` §6)

- **Ajustes completos**: las ocho rutas `/settings/*` son marcadores `PlaceholderScreen`
  (`app_router.dart:116-138`). Falta todo su contenido y el acceso (hoy no hay ninguna entrada a
  Ajustes ni a la cuenta: ni en el drawer ni en el menú «más» de la lista).
- **Compartir nota / enlace público** (`/notes/:id/share`): sin ruta ni pantalla; la entrada del
  menú contextual se omite a propósito (`docs/handoff-fase9.md:80`).
- **Bloquear / Cerrar sesión**: viven provisionalmente en el menú «más» de la lista hasta que existan
  los ajustes (`docs/handoff-fase9.md:81-82`).
- **Verificación en dos pasos (en ajustes), cambio de correo/contraseña, rotación de la clave,
  borrar cuenta, dispositivos, uso de espacio, importar/exportar, acerca de y legales**
  (`docs/plan.md:605-608`), más las pantallas sin tablero de `docs/screens.md:120-130`.

### (c) Fuera de alcance

- `Ajustes`, `Buscar`, `usuario/correo` como entradas del drawer móvil: no están en el diseño; sería
  un cambio de diseño, no una corrección.
- Acceso con Google y dispositivos de confianza: fuera de v1 (D5).
- Ficha de tienda / publicación: fase 13.
- iOS y escritorio: la app es solo Android (`docs/plan.md` §2).

## 5. Correcciones priorizadas para la fase 9 (no aplicadas)

1. **D1 — abrir el drawer (bloqueante).** La vía más robusta es no depender del `context` del
   `build`: declarar un `GlobalKey<ScaffoldState>` en `NotesScreen`, asignarlo al
   `Scaffold(key: …)` (`notes_screen.dart:213`) y usar `_scaffoldKey.currentState?.openDrawer()` en
   `onMenu`/`onTitleTap`. Alternativa equivalente: envolver `NotesTopBar` en un `Builder` y usar el
   `context` interno con `Scaffold.of`, pero el `GlobalKey` es más simple y deja el mismo disparador
   para los dos botones.
2. **D3 — prueba de regresión.** Añadir `app/test/features/notes/notes_drawer_test.dart` (ya
   escrito) al conjunto de la fase; las pruebas 1-2 fallan hoy y pasan al corregir D1.
3. **D2 — estado activo.** Calcular `selected` para Fijadas (`filter is NotesFilterPinned`), cada
   carpeta (`filter is NotesFilterFolder` con el id, o `folderId` de la ruta), cada etiqueta
   (`filter is NotesFilterTag`) y Papelera (comparar con la ruta `/trash` o un estado equivalente).
   Retirar el `folderIdIsAll(ref, null)` engañoso.
4. **D3 — golden del drawer** en claro y oscuro dentro de `notes_screens_golden_test.dart`, abriendo
   el drawer con el `GlobalKey`/`ScaffoldState` para fijar la paridad con el tablero `gmDDZ`.
5. **D4 (menor).** No pintar `0` cuando `counts == null`; reservar el espacio o mostrar el esqueleto,
   como el resto de la pantalla en carga.

Diferencia deliberada que **no** hay que «corregir» salvo decisión: la marca «Apunte» vs «AxoNote» y
el icono `sidebar` vs `x` (ya documentados en `docs/decisions.md:988-992`).

## Correcciones aplicadas (2026-10-15)

Sin commits. Solo se tocó lo del drawer/lista de notas; nada del editor (fase 10).

| # | Corrección | Archivo |
| --- | --- | --- |
| D1 | El drawer se abre con `GlobalKey<ScaffoldState>`; `NotesScreen` pasa a `ConsumerStatefulWidget`. Botón de menú y título usan `_scaffoldKey.currentState?.openDrawer()` | `app/lib/features/notes/ui/notes_screen.dart` |
| D2 | `selected` derivado del filtro/ruta actual en Todas, Fijadas, cada carpeta, cada etiqueta y Papelera; se retira `folderIdIsAll` | `app/lib/features/notes/ui/notes_screen.dart` |
| D3 | Prueba de regresión del drawer (10 casos) y golden claro/oscuro | `app/test/features/notes/notes_drawer_test.dart`, `app/test/features/notes/notes_screens_golden_test.dart` |
| D4 | Con `counts == null` no se pinta `0`; el contador se reserva con `AxoSkeleton` | `app/lib/ui/components/drawer.dart`, `notes_screen.dart` |
| Pie | `Papelera` sale del `ListView` y va al pie fijo del `AxoDrawer`, junto a «Nueva carpeta» y «Ajustes» | `app/lib/ui/components/drawer.dart`, `notes_screen.dart` |
| Ajustes | Fila «Ajustes» al pie (icono `settings` del set vendorizado) → `/settings/menu` (sigue siendo `PlaceholderScreen`, fase 11). Desviación deliberada del tablero, anotada en `docs/decisions.md` | `app/lib/features/notes/ui/notes_screen.dart` |

Pruebas del drawer (`flutter test test/features/notes/notes_drawer_test.dart`): **10/10 pasan** —
apertura por menú y por título, «Todas las notas» activa, Fijadas (filtra y cierra), carpeta →
`/folders/:id`, etiqueta, Papelera → `/trash`, Ajustes → `/settings/menu`, contador en carga sin `0`,
y estado activo al reabrir. Golden nuevo: `notes-menu-lateral-{light,dark}`.

### Cifras de las puertas

| Puerta | Resultado |
| --- | --- |
| `dart format --output=none --set-exit-if-changed` (rutas de CI) | **OK** · `Formatted 233 files (0 changed)` |
| `flutter analyze` | **OK** · `No issues found!` |
| `cd app && flutter test` | **OK** · **281 pruebas, 0 fallos** (incluye `app/test/design` del editor) |
| `dart run tool/check_imports.dart` | **OK** · `Arquitectura correcta.` |

Nota: durante la aplicación se detectó y corrigió una regresión propia en el test de «primera vez
(vacío)» (se había sustituido `buildNotesHarness(seed: false)` por `buildNotesHarness`); restaurado,
el golden vuelve a coincidir sin tocar su línea base.

Verificación en dispositivo (ZTE): `flutter build apk --debug
--dart-define=API_URL=https://3-12-7-249.sslip.io/v1` **OK** y `adb install -r` **OK**
(`package:com.axonote.app`).

## Segunda ronda (2026-10-15): salida de pantallas y crash al crear carpeta

Tres fallos más reportados en el ZTE. Sin commits; solo drawer/lista de notas (nada del editor).

### A · Papelera y Ajustes sin salida

- **Causa**: el drawer navegaba a `/trash` y `/settings/menu` con `context.go`, que **reemplaza** la
  pila. El botón «atrás» de `trash_screen.dart` hacía `context.pop()` con de pila vacía (no hacía
  nada) y el `AppBar` de `PlaceholderScreen` no mostraba flecha, así que no había forma de volver.
- **Corrección**: regla única en `app/lib/router/navigation.dart`
  (`canGoBack`/`goBack = canPop ? pop : go('/notes')`). El drawer abre Papelera y Ajustes con
  `context.push`; `TrashScreen`, `SearchScreen` y `PlaceholderScreen` usan `goBack` y envuelven su
  `Scaffold` en `PopScope` para el atrás del sistema (con `canGoBack` basado en `Navigator`, válido
  también sin router en los goldens). `PlaceholderScreen` gana flecha de atrás con `AppIcon`.
- **Búsqueda** ya se abría con `push` (por eso no fallaba), pero se unificó al mismo helper.

### B · «Nueva carpeta» con `Failed assertion: dependents.isEmpty`

- **Causa real** (reproducida): no era el context del drawer (se abre con el context estable de la
  pantalla y el drawer se cierra antes), sino el ciclo de vida del `TextEditingController`. Se creaba
  fuera del diálogo y se destruía al volver `showDialog`, mientras el `TextField` seguía montado
  durante la animación de cierre: primero `A TextEditingController was used after being disposed` y
  después la aserción `'_dependents.isEmpty': is not true`.
- **Corrección**: el controlador vive en el `State` del diálogo (`_NewFolderDialogState` y el nuevo
  `_RenameDialogState`), se crea en el `State` y se destruye en `dispose()` tras desmontarse.
  Mismo patrón corregido en «Cambiar nombre» (tenía el mismo defecto); el resto de hojas/diálogos
  (mover, vaciar, eliminar, contexto, orden) no usan controlador.

### Pruebas de regresión (fallan antes, pasan después)

- `app/test/features/notes/notes_navigation_test.dart` — 6 casos: Papelera, Ajustes y Búsqueda, cada
  uno volviendo con el **botón de la pantalla** y con el **atrás del sistema**
  (`popRoute` de plataforma). Antes: 6 fallos (Papelera/Ajustes) + 2 ya verdes (Búsqueda).
- `app/test/features/notes/notes_new_folder_test.dart` — 2 casos: crear carpeta desde el drawer y
  desde «Mover a carpeta». Antes: 2 fallos (`dependents.isEmpty`).
- Soporte compartido: `app/test/features/notes/support/notes_router.dart`.

### Cifras (tras la segunda ronda)

| Puerta | Resultado |
| --- | --- |
| `dart format --output=none --set-exit-if-changed` (rutas de CI) | **OK** · `Formatted 237 files (0 changed)` |
| `flutter analyze` | **OK** · `No issues found!` |
| `cd app && flutter test` | **OK** · **289 pruebas, 0 fallos** (incluye `app/test/design` del editor) |
| `dart run tool/check_imports.dart` | **OK** · `Arquitectura correcta.` |

Verificación en dispositivo (ZTE): APK debug y `adb install -r` **OK** (`package:com.axonote.app`).


