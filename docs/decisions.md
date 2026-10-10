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
