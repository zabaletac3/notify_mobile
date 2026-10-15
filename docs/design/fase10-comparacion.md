# Comparación Pencil «Movil v2» ↔ goldens del editor (fase 10)

- Referencias: `app/test/design_refs/crop/editor-normal-{claro,oscuro}.png` (capturas de Pencil
  recortadas al **área del dispositivo, 412×915**, sin marco ni sombra). Capturas completas en
  `app/test/design_refs/` (nombre = tablero).
- Goldens: `app/test/design/goldens/editor-<estado>-<modo>.png` (412×915, dpr 1).
- Lado a lado para revisión a ojo: `docs/design/fase10-pencil-vs-golden-{claro,oscuro}.png`
  (Pencil | golden).
- Pruebas: `test/design/editor_golden_test.dart` (12 goldens + 1 de tokens) y
  `test/design/editor_compare_test.dart` (puerta con Pencil).

## La puerta: geométrica (±4 px por banda + colores clave)

`editor_compare_test.dart` comprueba, en claro y en oscuro:

1. **Geometría**: cada banda de texto del tablero tiene una banda en el golden a **≤ 4 px** en
   vertical, alineando por la banda de la barra superior (la captura trae la barra de estado como
   primera banda; se salta). Se compara la tinta por **diferencia de luminancia con el fondo** (sirve
   en claro y en oscuro) y se fusionan bandas separadas ≤ 6 px.
2. **Colores clave**: el fondo del editor es el token del modo (`bg/editor` claro/oscuro) y la zona
   de tareas tiene píxeles `bg/selected` (resguardo de la tarea marcada).

**Resultado: en verde, claro y oscuro.** 19 pruebas en `test/design/`.

## El % de píxeles distintos (medida documentada, NO puerta)

| Modo | Píxeles distintos (canal > 24/255) |
| --- | --- |
| Claro | **13,72 %** |
| Oscuro | **9,53 %** |

**Por qué no es la puerta:** el export de Pencil (2×→1× con LANCZOS) y un render nítido a 1× tienen
rasterizados distintos. Al mismo umbral de tinta (140), el tablero trae **22 740** píxeles de tinta y
el golden **12 209** (≈1,9×): es rasterizado, no contenido. Buscando el mejor offset posible el diff
no baja del 16 %; a 1/2, 1/3 y 1/6 de escala sigue en 17–21 %. Una tolerancia de píxeles “pequeña”
es inalcanzable por construcción, así que la puerta es la geométrica y el porcentaje se deja como
medida (no se sube ninguna tolerancia para que pase).

## Ritmo vertical: qué se ajustó

Los rellenos por bloque se midieron contra el tablero, banda a banda, hasta dejar la geometría dentro
de ±4 px:

- `EditorStyle.padding` `(24, 2, 24, 0)` (el editor lo aplica **por bloque**).
- Encabezado del documento `(24, 14, 24, 12)`; **28/700 ls −0.56** el título.
- Párrafo `bottom 11` (0 si está vacío); encabezado H2 `top 6, bottom 9`; viñeta `bottom 10`; tarea
  `bottom 12`; cita 12; separador 12.
- **Párrafo vacío final**: el editor deja uno tras el último bloque y separaba el pie ~30 px; ahora
  no aporta alto (padding 0 cuando el delta no tiene texto) y el adaptador no lo duplica.

## Diferencias conocidas que quedan

1. **% de píxeles**: ver arriba; es rasterizado, no maquetación.
2. **Barra de estado y de gestos**: la captura las dibuja y la app no (las pone Android); quedan
   fuera de la puerta (se salta la banda de estado y se corta antes del pie de gestos).
3. **Barra de formato**: va pegada abajo en los dos; su posición exacta depende del inset del sistema
   (`viewInsets`/gestos), así que queda fuera de la puerta de bandas.

## Excepciones (bloques que el tablero no dibuja)

- **Código**, **cita**, **separador** y **bloque opaco** (tabla): el tablero `Android — Editor` no los
  muestra; se toman de `notify_web` (`prose.css`) y del componente opaco propio. El **bloque de
  código** no existe en el editor vendorizado: se implementó (`ui/code_block.dart`).

## Cómo se verifica

```
cd app && flutter test test/design/                       # goldens + puerta con Pencil
cd app && flutter test --update-goldens test/design/editor_golden_test.dart   # regenerar líneas base
```
