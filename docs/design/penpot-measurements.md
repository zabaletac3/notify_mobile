# Medidas de Penpot (componentes, iconos, radios)

Extraído del MCP (solo lectura), 2026-10-10. D16: manda Penpot. Complementa
[`penpot-extract.json`](penpot-extract.json). Estado detallado en [`penpot-progress.md`](penpot-progress.md).

## Los 10 componentes base (medidos en los tableros)

| Componente | Medidas en Penpot | Estados / notas |
| --- | --- | --- |
| **Botón** | primario de formulario **54 de alto, radio 14** (324/362 de ancho, label 16/600, `accent` + `accent.on`); secundario/Google **52 de alto, radio 14**, `bg.editor`, label 15/600; botón de diálogo **46 de alto, radio 12**; FAB **54 de alto, radio 18**, icono 22 | peligro sólido (`status.danger`), outline en diálogo. **No aparece** estado deshabilitado en los tableros |
| **Campo de texto** | input **52 de alto, radio 12**, relleno 14, `bg.input`; etiqueta **13/500** `text.primary`; valor/placeholder **15/400** `text.tertiary`; ayuda **12/400** `text.secondary` | **No aparece** estado de error en los tableros auth (solo en la web) |
| **Interruptor** | **44×26, radio 13**, knob **20**; encendido `accent`, apagado `text.tertiary` (knob blanco) | — |
| **Casilla** | **20×20, radio 10** (círculo) | marcada/sin marcar |
| **Casilla OTP** | casilla **53×60, radio 12**, `bg.input`; la activa `bg.editor`; dígito **24/700**; hueco **8** | — |
| **Tarjeta de nota** | **386×80, radio 10**, relleno 14; título **14/600** `text.primary`; preview **12/400** `text.tertiary`; fecha **12/500** `text.secondary`; etiqueta de carpeta **11/500** `text.tertiary` + icono carpeta 11; pin **13** (`tag.amber`) | — |
| **Hoja inferior** | radio superior **24**, `bg.editor`; asa **36×4 radio 2** `border.default`; relleno lateral 20; título **17/600**; meta **13/400** `text.secondary`; contenedor de acciones **radio 14** `bg.app` | — |
| **Elemento de menú** | **48 de alto**, relleno 16, hueco 12, icono **20**, label **15/500**; destructivo en `status.danger`; divisor 1 px `border.default` | — |
| **Diálogo** | **348 de ancho, radio 20**, `bg.editor`, relleno ~24; título **20/700**; detalle **14/400** (interlineado 1.5) `text.secondary`; ilustración **56 circular** `status.danger-bg` + icono 26; botones **46/12** | — |
| **Aviso/Toast** | **388 de ancho, radio 12**, `bg.editor`; acción **14/600** `accent` | variantes error/éxito/info (mismos colores de texto que en la web) |

## Iconos

Lucide, **trazo 1,75** (comprobado en los `path`). Tamaños medidos por contexto: **24** (botón atrás),
**22** (más, menú, compartir, deshacer, compose), **20** (menú/buscar/papelera/carpeta/pin/compartir en hoja),
**18** (chevron), **15** (carpeta en chip), **13** (pin), **11** (carpeta en tarjeta). Botón de la barra
superior: **40×40, radio 20** (círculo).

## Radios (valores distintos, por contexto)

28 (marco del dispositivo, tarjeta de auth, buscador) · 24 (hoja) · 20 (diálogo, botón de icono) ·
18 (FAB) · 14 (botón primario/Google, contenedor de acciones) · 13 (interruptor) · 12 (input, botón de
diálogo, toast, casilla OTP) · 10 (tarjeta de nota, chip, casilla) · 8 · 4 · 2.

## Colores no-token usados

- `#b7791f`: resplandor decorativo (elipse) en las pantallas de autenticación (p. ej. Registro).
- `#4285f4`: logo de marca de Google (texto «G»), única excepción de marca.

## Comparación «Android — Editor» vs «3 · Notas — Android — Editor»

- **«Android — Editor»**: solo las barras (superior y de estado) con botones `back`/`share`/`undo`/`more` y
  el selector de carpeta; **sin documento ni barra de formato**.
- **«3 · Notas — Android — Editor»**: el editor **completo** = las mismas barras + **Component 2/Document**
  (etiquetas, checklist, viñetas, títulos, párrafo, título de nota y fecha) + **Component 2/Format bar row**
  (barra de formato).
- Es decir, el nuevo añade el contenido y la barra de formato; el antiguo era solo el chasis. Se usa el nuevo.

## Tipografía: rol → tamaño/peso/interlineado/espaciado → dónde aparece → n.º de usos

Conteos de `penpot-extract.json` (`tipografia.estilos`). El diseño **convive** tamaños e interlineados
distintos por contexto; no se borra ningún rol que use.

| Rol (`AxoType`) | Tamaño / peso / interlineado / ls | Dónde | Usos |
| --- | --- | --- | --- |
| `title` | 28 / 700 / 34 (1.214) / -0.56 | Título de autenticación grande («Verifica tu correo») | 14 |
| `screenTitle` | 24 / 700 / 1.2 / 0 | Título de pantalla («Crea tu cuenta») | 10 |
| `topTitle` | 22 / 700 / 1.2 / -0.44 | Selector de carpeta / título superior de la lista | 19 |
| `dialogTitle` | 20 / 700 / 1.2 / 0 | Título de diálogo | 13 |
| `sheetTitle` | 17 / 600 / 1.2 / 0 | Título de hoja inferior | 3 |
| `heading` | 18 / 600 / 1.2 / 0 | Encabezados de sección | 9 |
| `noteTitle` | 14 / 600 / 1.2 / 0 | Título de nota en la lista | 153 |
| `body` | 15 / 400 / 22 (1.467) / 0 | Texto de lectura (editor; subtítulo de auth) | 9 |
| `bodyUi` | 15 / 400 / 1.2 / 0 | Texto de interfaz (campos, botones, opciones) | 16 |
| `label` | 13 / 500 / 1.2 / 0 | Etiquetas de campo | 32 |
| `caption` | 12 / 400 / 1.2 / 0 | Pie, ayuda, metadatos | 78 |

Otros estilos presentes que **no** se han creado como rol propio (pesos/conteos): `16/600` (label de botón
primario, 20), `13/600` (encabezado de grupo, 39), `11/500` (etiqueta de carpeta y de carpeta en tarjeta,
66+3), `12/500` (fecha, 80), `15/500` (label de menú/opción, 48), `13/400` (16), `20/400` (texto de ajustes,
21), y los tamaños menores de la ficha de tienda (reducida). `sourcesanspro` aparece 2× (probablemente en
la ficha de tienda): a revisar, no se usa.

