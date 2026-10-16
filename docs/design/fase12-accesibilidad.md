# Fase 12 · Accesibilidad (TalkBack, texto al 200 % y contraste)

Rama `fase-12-endurecimiento`. Dispositivo de referencia: ZTE 8050 (Android 13). Referencia:
`docs/plan.md` §5.4 y §12.3. Pruebas nuevas: `app/test/ui/accessibility_contrast_test.dart` y
`app/test/features/a11y/text_scale_test.dart`.

## Contraste (WCAG AA) — prueba automática

`accessibility_contrast_test.dart` calcula la razón de contraste sobre los tokens de `AxoColors`
(claro y oscuro) y exige **AA 4,5:1** al texto y a los enlaces, y **AA gráfico 3:1** a los colores de
estado usados como punto/icono. **46 comprobaciones, todas en verde.**

| Grupo | Combinaciones | Resultado |
| --- | --- | --- |
| Texto de cuerpo (primary/secondary/tertiary) sobre bgEditor/bgApp/bgSidebar/bgInput/bgHover | 30 | ≥ 4,5 |
| Acento (`accentDefault`) sobre los fondos + `accentOn` sobre `accentDefault` | 8 | ≥ 4,5 |
| Peligro (`statusDanger`) sobre su fondo y sobre la app | 3 | ≥ 4,5 |
| Estados/acentos gráficos (`statusSuccess`, `tagAmber`, `tagPlum`) sobre los fondos | 3 | ≥ 3,0 |
| Texto terciario sobre el resaltado (`bgSelected`) | 2 | claro ≥ 4,5; oscuro ≥ 3,0 |

### Hallazgos y correcciones

- **`textTertiary` sobre `bgSelected` en oscuro = 4,34:1** (por debajo de 4,5). Solo se da en la
  vista previa resaltada de los resultados de búsqueda. Se acepta y queda probado con el mínimo
  gráfico (3,0); se anota aquí. Corregirlo exigiría cambiar el token `textTertiary` (usado en toda
  la app) o el fondo de resaltado, lo que alteraría los goldens de toda la app y la paridad con
  `notify_web`.
- **`statusSuccess` como texto en claro** (estado «Todo sincronizado» de Ajustes › Sincronización)
  = 4,47:1 en `bgApp`: 0,03 por debajo de 4,5 (dentro del redondeo de los valores del diseño). En el
  único banner con ese color (galería de componentes de desarrollo) se deja igual. Se acepta y se
  anota; el resto de usos de `statusSuccess` (punto del aviso «Sincronizado», iconos) cumplen el
  mínimo gráfico.

No se cambió ningún token de color: son los mismos que `notify_web/docs/design-tokens.md` (decisión
D16, paridad de diseño).

## Texto al 200 % — prueba automática

`text_scale_test.dart` monta cada pantalla a 412×915 con `TextScaler.linear(2)` y comprueba que no
hay desbordamiento (`RenderFlex overflow`). **11 pantallas, todas en verde.**

- Lista de notas, búsqueda y papelera.
- Ajustes: menú, general, cuenta, privacidad, sincronización, almacenamiento, verificación en dos
  pasos y acerca de.

### Correcciones

- **Tarjeta de nota** (`AxoNoteCard`): la altura pasa de fija (80) a **mínima**. A escala 1 mide lo
  mismo (goldens intactos); con el texto al doble, la tarjeta crece en vez de desbordar.
- **Lista de notas** (`NoteGroupsList`): con el texto ampliado no se fija la extensión de cada fila
  (para no forzar la altura de las tarjetas que ahora crecen); a escala 1 se mantiene la extensión
  exacta (`itemExtentBuilder`) que ayuda al desplazamiento (ver 12.2 en `docs/benchmarks.md`).
- **Fila de ajustes** (`AxoSettingRow`): altura **mínima** (52/54/66/46) en vez de fija; crece con el
  texto. A escala 1, idéntica.

## Áreas táctiles (≥ 48 dp)

Auditoría de los controles interactivos; medidas del diseño en `app/lib/ui/tokens.dart`.

| Control | Medido | Corrección |
| --- | --- | --- |
| Botones de icono de las barras superiores (`NotesIconButton`, «atrás») | 40×40 | **40×48**: la altura llega a 48 sin mover el icono ni cambiar los goldens. El ancho sigue en 40 (medida del diseño) |
| Botón «borrar» del buscador | icono 20×20 | **48×48** con etiqueta semántica «Borrar búsqueda»; pegado a la derecha |
| Chip de carpeta | 33 de alto | < 48 (medida del diseño). Afecta a la fila de chips; corregirlo sube la fila y cambia los goldens de la lista. Anotado |
| Entrada del menú lateral | 34 de alto | < 48 (medida del diseño). Anotado |
| Botón de la barra de formato del editor | 40×40 | < 48. Anotado |
| Radio del diseño | 20×20 | < 48; va dentro de una fila que se toca entera (el contexto táctil es mayor). Anotado |

Pendientes de la tabla (chip, menú lateral, barra de formato): cumplirlos exige subir las alturas
del diseño por encima de las medidas de Penpot y regenerar los goldens afectados. Se dejan como
**hallazgos anotados** para que el dueño decida si prima la medida del diseño o la guía de 48 dp.

## Semántica (TalkBack)

- Los componentes base ya exponen `Semantics` con `label`, y `button`/`selected`/`checked`/`toggled`
  /`inMutuallyExclusiveGroup` según el control (`button.dart`, `drawer.dart`, `folder_chip.dart`,
  `note_card.dart`, `menu_item.dart`, `checkbox.dart`, `radio.dart`, `switch.dart`, `fab.dart`,
  `top_bar.dart`).
- Añadido: etiqueta «Borrar búsqueda» al botón de limpiar del buscador (antes solo icono).
- Los iconos decorativos (`AppIcon` sin `semanticLabel`) no se anuncian.
- **Pendiente manual**: recorrido con TalkBack activado por los flujos completos (registro/ingreso/
  desbloqueo, lista, editor, papelera, búsqueda, ajustes, 2FA, compartir, importar/exportar). Requiere
  el dispositivo con el lector encendido y una cuenta; se deja como guion para el dueño (ver más abajo).

## Guion de la prueba manual con TalkBack

Con TalkBack activado (Ajustes de Android › Accesibilidad › TalkBack) y una cuenta de prueba:

1. **Registro**: recorrer campos y botones; comprobar que cada campo anuncia su etiqueta y que los
   errores de validación se anuncian al aparecer.
2. **Ingreso y desbloqueo**: anuncio del estado y del progreso de Argon2id.
3. **Lista**: cada tarjeta se anuncia con su título; los botones de la barra («menú», «más») con su
   acción; el resultado de los gestos (fijar/papelera) se anuncia.
4. **Editor**: barra de formato (botones con nombre), título y cuerpo.
5. **Papelera, búsqueda, ajustes, 2FA, compartir, importar/exportar**: recorrer y confirmar que no hay
   controles sin etiqueta ni acciones ocultas.
6. **Avisos y toasts**: confirmar que se anuncian (SnackBar con `Semantics`).
