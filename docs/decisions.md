# Decisiones

Anotación de cualquier decisión no prevista en el plan (§2) o de las alternativas de la §12 que
se hayan tenido que aplicar. Formato: fecha, fase, decisión, motivo, referencia.

## Fase 0

### 2026-10-10 · appflowy_editor no compila con Flutter 3.47.7

- **Riesgo §12 detectado:** «`appflowy_editor` no compila con el Flutter estable».
- **Síntoma:** al compilar la app de comprobación, el compilador de Dart falla con
  `The non-abstract class 'DeltaTextInputService' is missing implementations for these members:
  TextInputClient.onFocusReceived`. Flutter 3.47 añadió `TextInputClient.onFocusReceived`; el
  mixin `DeltaTextInputClient` de Flutter hace `implements TextInputClient` (no `extends`), así
  que la clase de AppFlowy queda obligada a implementarlo aunque el original tenga valor por
  defecto.
- **Alternativa aplicada (§12):** copiar el paquete a
  `packages/third_party/appflowy_editor` y corregirlo allí. Commit del parche documentado en
  `packages/third_party/appflowy_editor/PATCHES.md`. El códec de Markdown del proyecto no depende
  de AppFlowy, por lo que el parche queda contenido.

### 2026-10-10 · compileSdk de plugins transitivos de appflowy_editor

- **Síntoma:** Gradle falla en `:keyboard_height_plugin:checkDebugAarMetadata` («currently
  compiled against android-31», pero una dependencia androidx exige ≥ 34).
- **Decisión:** en `android/build.gradle.kts` de la app se fuerza `compileSdk = 36` a los
  subproyectos (plugins) con un valor antiguo. No cambia el `compileSdk` propio de la app (que
  sigue siendo el de Flutter estable, D17). Es el ajuste estándar para plugins desactualizados.

## Fase 2

### 2026-10-10 · Base visual reextraída de Penpot (resuelto; D16, manda Penpot)

- **Antes:** durante la fase 2 la pestaña de Penpot del MCP se congeló y los valores salieron de
  `notify_web`; eso **no valía como cierre**. Reanudado el MCP, se reextrajo todo de Penpot.
  Medidas en [`docs/design/penpot-measurements.md`](design/penpot-measurements.md); crudo en
  [`docs/design/penpot-extract.json`](design/penpot-extract.json).
- **Colores:** los 34 tokens de color coinciden **exactamente** con los que había. **Iconos:** Lucide
  con trazo **1,75** (confirmado). Sin cambios en eso.

#### Penpot frente a lo que había (tomado de la web)

| Qué | Antes (web) | Penpot (ahora) |
| --- | --- | --- |
| Título de pantalla | 28/700, int. 34/28 | **24/700**, int. 1.2, `letterSpacing` -0.4 |
| Encabezado | 18/600, int. 24/18 | **18/600**, int. 1.2 |
| Cuerpo | 15/400, int. 22/15 | **15/400**, int. 1.2 |
| Etiqueta | 13/500, int. 18/13 | **13/500**, int. 1.2 |
| Pie/caption | 12/400, int. 16/12 | **12/400**, int. 1.2 |
| Título de nota | (no había rol) | **14/600** (`AxoType.noteTitle`) |
| Radio tarjeta/buscador | (no había) | **28** (`AxoRadii.card`) |
| Casilla OTP | 48×60 | **53×60**, hueco 8 |
| Elemento de menú | 38 alto, relleno 9/12 | **48 alto**, relleno 16, icono 20, label 15/500 |
| Toast (ancho) | 380 | **388** |
| Tarjeta de nota | preview `text.secondary` | preview **`text.tertiary`**; título 14/600; pin `tag.amber` |
| Hoja inferior | asa 32×4 | asa **36×4**; título 17/600 |
| Diálogo | ancho 420/480 | **348** |
| Radios botones | 12 (md) / 14 (lg) | primario/Google **14**; diálogo **12** |
| Colores usados no-token | — | `#b7791f` (resplandor decorativo), `#4285f4` (logo Google) |

Sin diferencias en: los 34 colores de token, el trazo de iconos, y radios que ya coincidían (12 inputs,
20 diálogo, 24 hoja, 10 tarjeta de nota, casilla 20, interruptor 44×26). Los tamaños de botón 46/54 y la
altura de input 52 también coincidían.

> Nota: los **PNG de los 41 tableros** no se pudieron guardar (el `export_shape` del MCP devuelve la imagen
> al chat, no escribe a disco; y devolver SVG por API son ~135 KB por tablero). El archivo de Penpot sigue
> siendo la referencia visual; ver `docs/design/penpot-progress.md`.

### 2026-10-10 · Dependencias nuevas de la fase 2 fuera de la §9

- **`flutter_svg`** (`^2.2.0`): renderizar los iconos **Lucide** empaquetados como SVG con trazo 1,75
  (los SVG están en `app/assets/icons/`, con `stroke-width` 1,75). En la web se usa Lucide con trazo 1,75.
- **`intl`** (`^0.20.3`): lo trae `flutter_localizations` y lo usa la localización `es` (ARB).
- `flutter_riverpod` y `go_router` están en la §9 (D9), no requieren nota.

