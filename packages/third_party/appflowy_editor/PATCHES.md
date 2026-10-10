# appflowy_editor (vendorizado)

Copia de `appflowy_editor 6.2.0` (de pub.dev) con un parche mínimo. Se vendoriza porque la
versión publicada no compila con el Flutter estable actual — es la alternativa ya prevista en la
§12 del plan (`docs/plan.md`).

- Origen: `~/.pub-cache/hosted/pub.dev/appflowy_editor-6.2.0`
- Licencia: MPL-2.0 / AGPL-3.0 (ver `LICENSE`).

## Parches

### 1. `onFocusReceived` en `DeltaTextInputService`

`lib/src/editor/editor_component/service/ime/delta_input_service.dart`

Flutter 3.47 añadió el miembro `TextInputClient.onFocusReceived`. El mixin
`DeltaTextInputClient` de Flutter hace `implements TextInputClient` (no `extends`), por lo que la
clase `DeltaTextInputService` debe implementarlo aunque el original tenga valor por defecto.
Se añade:

```dart
@override
bool onFocusReceived() => false;
```

Se documenta en `docs/decisions.md` (fase 0). Al actualizar Flutter, revisar si el parche sigue
siendo necesario.
