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

### 2026-10-10 · Penpot congelado durante la fase 2; tokens desde el sistema ya validado

> **NO VALE COMO CIERRE (D16, manda Penpot).** Se está rehaciendo la base visual con lo que diga
> Penpot. Progreso y estado en [`docs/design/penpot-progress.md`](design/penpot-progress.md).

- **Situación:** la pestaña de Penpot del MCP se congeló (el navegador la suspendió) al consultar
  valores de tokens y medidas. Sí se pudo explorar antes: página `App Mobile` con 41 tableros de
  412×915, dos sets de color (`Apunte/Color/Light`, `Apunte/Color oscuro/Dark`) y tipografía **Inter**.
- **Decisión:** los valores de color, la escala tipográfica, los radios y las medidas de componentes
  se toman de `notify_web/docs/design-tokens.md` y `components.md`, que ya están validados contra este
  mismo diseño. Cuando Penpot vuelva, se contrastan los 34 valores y, si difieren, **manda Penpot**
  (se actualizará `app/lib/ui/tokens.dart` y se anotará aquí). No se inventan estilos.

### 2026-10-10 · Dependencias nuevas de la fase 2 fuera de la §9

- **`flutter_svg`** (`^2.2.0`): renderizar los iconos **Lucide** empaquetados como SVG con trazo 1,75
  (los SVG están en `app/assets/icons/`, con `stroke-width` 1,75). En la web se usa Lucide con trazo 1,75.
- **`intl`** (`^0.20.3`): lo trae `flutter_localizations` y lo usa la localización `es` (ARB).
- `flutter_riverpod` y `go_router` están en la §9 (D9), no requieren nota.

