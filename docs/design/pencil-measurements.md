# Medidas de Pencil — Fase 9 (Notas)

Fuente de verdad del diseño: documento de Pencil **«axonote»**
(`/home/cristian/.pencil/documents/31878e13-9a73-448f-891e-9066150ee94e/axonote.pen`),
sección **Móvil**, tableros `Android — …` de 412×915. Leído tablero por tablero con el MCP `pencil`
(`Get` con visitante + `TakeScreenshot`), 2026-10-14. Sustituye a Penpot para esta fase (D16:
manda el diseño; ahora el diseño vive en Pencil).

El documento usa el nombre antiguo **«Apunte»**; en la app se escribe **AxoNote**.

## Tableros de la fase 9 (leídos)

| Tablero (Pencil) | Ruta | Qué aporta |
| --- | --- | --- |
| Android — Lista de notas | `/notes` | Lista con grupos, buscador, chips de carpeta, FAB |
| Android — Lista (oscuro) | `/notes` | Verifica el set oscuro |
| Android — Primera vez (vacío) | `/notes` vacío | Estado vacío «sin notas» |
| Android — Carpeta vacía | `/folders/:id` | Vacío de carpeta + chips |
| Android — Papelera | `/trash` | Días restantes, aviso, «Vaciar» |
| Android — Resultados de búsqueda | `/search` | Resultados |
| Android — Búsqueda sin resultados | `/search` vacío | Vacío de búsqueda |
| Android — Menú lateral | drawer | Carpetas y etiquetas |
| Android — Menú contextual de nota | hoja inferior | Fijar, mover, compartir, renombrar, duplicar, papelera |
| Android — Modal mover nota | hoja inferior | Selector de carpeta + nueva carpeta |
| Android — Modal nueva carpeta | diálogo | Campo + contador |
| Android — Confirmar eliminación | diálogo | Peligro |
| Android — Conflicto de sincronización | hoja inferior | Las tres opciones (esta / nube / ambas) |
| Android — Cargando (skeletons) | carga | Esqueletos de la lista |
| Android — Sin conexión | global | Aviso persistente |
| Android — Error de servidor | global | Aviso + reintento |
| Android — Toasts | global | 4 variantes |
| Android — Sesión expirada | global | Diálogo |

## Pantalla base (lista, claro)

`#f6f2ea` (`bgApp`), radio del chasis 28. Barra de estado 412×39 (reloj 14/600 `textPrimary`).
**Barra superior** 412×48, relleno [4,8], hueco 4: botón de menú 40×40 radio 20 (icono 22, trazo 1,75);
selector de carpeta (título `topTitle` 22/700 ls −0,44 + chevron 18 `textSecondary`); botón «más»
40×40 radio 20.

**Contenido** 412×740, relleno [0,12], hueco 2:

- **Conteo** 13/500 `textSecondary` («12 notas»; en búsqueda «3 resultados»), relleno [0,0,12,12].
- **Buscador** 388×48, radio **28**, relleno [14,18], hueco 12, relleno `bgInput` (`#eae4d9`); icono
  `search` 20 `textSecondary`; texto **16/400** (placeholder `textTertiary`, valor `textPrimary`);
  botón `close` 20 a la derecha cuando hay texto.
- **Chips de carpeta** 388×53, hueco 8, relleno [14,0,6,2]; chip **33** de alto, radio **10**, relleno
  [8,14], hueco 6, borde `borderDefault` 1; etiqueta **14/500** `textSecondary`. Activo: relleno
  `bgSelected`, icono `folder` 15 `accent`, etiqueta **14/600** `accent`.
- **Cabecera de grupo** 38 de alto, relleno [16,0,6,14]; etiqueta **13/600** `textSecondary`
  («Fijadas», «Esta semana», «Septiembre»).
- **Tarjeta de nota** 388×**80**, radio **10**, hueco 4, relleno [12,14], **sin relleno de fondo**
  (fila plana sobre `bgApp`): fila superior con pin 13 `tagAmber` + título **14/600** `textPrimary`;
  fila meta (hueco 8) con fecha **12/500** `textSecondary` + vista previa **12/400** `textTertiary`;
  fila de carpeta (hueco 4) con icono `folder` 11 + etiqueta **11/500** `textTertiary`.

**FAB** «Nueva nota» 155×54, radio **18**, relleno `accent`, hueco 10, relleno [16,22,16,18]; icono
`compose` 22 blanco; etiqueta **15/600** blanca.

En **oscuro**: `bgApp #1b1a18`, buscador `bgInput #2a2826`, chip activo `bgSelected #26364d`, FAB
`accent #7ba7e6`. Las tarjetas también sin relleno.

## Estados vacíos / error

- **Primera vez (vacío):** buscador + estado vacío centrado: ilustración **88** radio 22 `accent` con
  «A» 40/700 blanca (marca), título 20/700 `textPrimary` («Bienvenido a Apunte»), subtítulo 14/400
  `textSecondary`, botón primario 198×**48** radio **12** etiqueta 15/600.
- **Carpeta vacía / sin resultados:** ilustración **80** circular radio 40 `bgSelected`; título
  20/700; subtítulo 14/400; botón (primario o secundario) 48 de alto, radio 12, etiqueta 15/600.
- **Error de servidor:** ilustración 80 circular `statusDangerBg` con «!» 40/700 `statusDanger`;
  título 20/700; detalle 14/400 `textSecondary`; botón 46/12 15/600; «Código de error {code}» 12/400
  `textTertiary`.
- **Cargando (skeletons):** buscador + chips + 5 filas «Skeleton — nota» de **92** de alto, relleno
  [12,14], hueco 8; barras de relleno `#e6dfd3` (claro) radio 6 (medidas 197×14, 348×10, 251×10,
  70×10). En oscuro se usa `bgHover`.

## Papelera

Barra superior: atrás (40/20), título **18/600** (`heading`), acción «Vaciar» **14/600** `accent`.
Aviso 388×62 radio 12 relleno `bgSelected`, relleno [12,14], texto **13/400** `textPrimary`.
Tarjetas iguales que la lista, con la fila de carpeta mostrando **«Se elimina en N días»** (11/500
`textTertiary`, icono `folder` 11).

## Menú contextual (hoja inferior)

Hoja redondeada arriba radio **24**, relleno **`bgEditor`**, relleno [12,20,36,20], hueco 16; asa
36×4 radio 2 `borderDefault`. Encabezado: título 17/600 `textPrimary`, meta 13/400 `textSecondary`
(«Universidad · hoy 09:12»). Contenedor de acciones relleno `bgApp`, radio 14, borde `borderDefault`;
opción **48** de alto, relleno [14,16], hueco 12, icono 20, etiqueta **15/500** `textPrimary`
(destructiva `statusDanger`); divisor 1 px `borderDefault`.

## Modal mover nota (hoja inferior)

Título 20/700; nota 14/400 `textSecondary`. Lista de carpetas relleno `bgApp` radio 14 borde 1; fila
**46** de alto, relleno [13,16], hueco 12: radio 20×20 radio 10 borde 2 (punto 10 `accent` cuando está
elegida), icono `folder` 18, etiqueta **15/600** (elegida) / 15/500, cantidad 13/400 `textTertiary`.
«+ Nueva carpeta» 18/600 + 14/600 `accent`. Botones 46/12 (secundario 180, primario 180).

## Modal nueva carpeta (diálogo)

348 de ancho, radio 20, relleno 24, hueco 16, relleno `bgEditor`, borde 1; título 20/700; subtítulo
14/400 `textSecondary`; campo: etiqueta 13/500, entrada 52 de alto radio 12 relleno `bgEditor` borde
2 (foco `accent`), valor 15/400; contador «9/30» 12/400 `textTertiary`; botones 46/12.

## Confirmar eliminación (diálogo)

348 de ancho, radio 20, relleno 24, hueco 16: ilustración **56** circular radio 28 `statusDangerBg`
con icono `trash` 26; título 20/700; detalle 14/400 `textSecondary` (interlineado 1.5); botones 46/12
(secundario + **peligro sólido** `statusDanger`), etiqueta 15/600.

## Conflicto de sincronización (hoja inferior)

Título 20/700; detalle 14/400 `textSecondary`. Dos tarjetas «versión» (esta / nube): relleno
`bgSelected` (esta, borde 2 `accent`) o `bgApp` (nube, borde 1), radio 12, relleno [12,14], hueco 6;
cabecera con radio + título 15/600; meta 12/400 `textSecondary` («Pixel 8 · editada hoy 09:12»); vista
previa 13/400 `textPrimary`. Botones 46/12: «Conservar ambas» (secundario) y «Usar la seleccionada»
(primario).

## Menú lateral (drawer)

Ancho **304**, relleno `bgSidebar` (`#ede7dc`), radios [0,20,20,0], relleno [54,12,14,12], hueco 2,
borde derecho 1; velo `#1f1d1a`. Marca: cuadro 28 radio 8 `accent` con «a» 20/700, nombre 20/700,
icono `sidebar` 18. Encabezado de sección **11/600** `textTertiary` en mayúsculas («BIBLIOTECA»,
«CARPETAS», «ETIQUETAS»), relleno [14,0,6,10]. Elemento **34** de alto radio 8, relleno [7,10], hueco
10: icono 18, etiqueta **14/500** `textPrimary`, contador **12/500** `textTertiary`. Activo: relleno
`bgSelected`, etiqueta 14/600 `accent`, icono y contador `accent`. Al pie «+ Nueva carpeta» 13/600
`accent`.

## Sin conexión

Aviso 412×60, relleno `#e6dfd3` (`bgHover`), relleno [12,16], hueco 10: punto 8 `tagAmber`, texto
13/500 `textPrimary`, acción 13/600 `accent` («Reintentar»).

## Toasts

388 de ancho, radio 12, relleno [12,14], hueco 12, relleno `bgEditor` borde 1; punto 10 (success
`statusSuccess`, info `accent`, error `statusDanger`); mensaje **14/500** `textPrimary`; acción
**14/600** `accent`.

## Sesión expirada (diálogo)

348 de ancho, radio 20, relleno 24, hueco 16: ilustración **64** circular radio 32 `bgSelected` con
candado; título 20/700; detalle 14/400 `textSecondary`; botones 46/12 («Seguir sin conexión»
secundario + «Iniciar sesión» primario).

## Tokens nuevos (documentados con el tablero)

Añadidos a `app/lib/ui/tokens.dart` (no había rol/valor equivalente):

| Token | Valor | Tablero |
| --- | --- | --- |
| `AxoType.search` | 16/400 | Buscador («Search bar») |
| `AxoType.chip` | 14/500 | Chip de carpeta |
| `AxoType.chipActive` | 14/600 | Chip activo / elemento de drawer activo |
| `AxoType.navItem` | 14/500 | Elemento de menú lateral |
| `AxoType.groupHeader` | 13/600 | Cabecera de grupo |
| `AxoType.option` | 15/500 | Opción de hoja inferior |
| `AxoType.sectionLabel` | 11/600 | Encabezado «BIBLIOTECA» |
| `AxoType.meta11` | 11/500 | Etiqueta de carpeta en la tarjeta |
| `AxoType.meta12med` | 12/500 | Fecha de la tarjeta |
| `AxoType.buttonSm` | 15/600 | Etiquetas de botón de diálogo/FAB |
| `AxoRadii.chip` | 10 | Chip / tarjeta de nota |
| `AxoRadii.fab` | 18 | FAB |
| `AxoSizes.searchBar` | 48 | Buscador |
| `AxoSizes.chip` | 33 | Chip |
| `AxoSizes.groupHeader` | 38 | Cabecera de grupo |
| `AxoSizes.sidebarItem` | 34 | Elemento de drawer |
| `AxoSizes.drawer` | 304 | Menú lateral |
| `AxoSizes.noteSkeleton` | 92 | Esqueleto de nota |
| `AxoSizes.illustration` | 80 | Ilustración de estado |
| `AxoSizes.optionRow` | 48 | Opción de hoja inferior |

## Diferencias con lo que había (fase 2, Penpot)

- La **tarjeta de nota** del diseño nuevo es una **fila plana sin relleno** (antes tenía `bgEditor`).
- La **hoja inferior** lleva `bgEditor` con el contenedor de acciones en `bgApp` (el componente de la
  fase 2 usaba `bgApp` de fondo).
- El **diálogo** se rellena a 24 (antes 28) y su ilustración es 56 (peligro `statusDangerBg`) o 64
  (`bgSelected`) según el caso.
- El **aviso de sin conexión** usa `bgHover`; el aviso de la papelera usa `bgSelected`; el `AxoBanner`
  de la fase 2 usaba `bgInput` para «info».
