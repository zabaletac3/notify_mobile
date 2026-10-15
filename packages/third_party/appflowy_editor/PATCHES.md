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

### 2. `device_info_plus` retirado de `keyboard_height_observer`

`lib/src/editor/toolbar/mobile/utils/keyboard_height_observer.dart` y `pubspec.yaml`

La app usa `flutter_secure_storage` ^11, que exige `win32` ^6, mientras que `device_info_plus` ^11
(que el editor usaba solo para leer `androidSDKVersion`) arrastra `win32` ^5. En Android ambas
ramas no se compilan juntas, pero la resolución de dependencias sí choca. `androidSDKVersion` solo
se escribía, nunca se leía, así que se retira la consulta (el campo queda en `-1`) y la dependencia
`device_info_plus` del `pubspec.yaml`. Documentado en `docs/decisions.md` (fase 10).

### 3. `file_picker` retirado (choque de `win32`/`dbus`)

`lib/src/editor/util/file_picker/*`, `image_upload_widget.dart` y `pubspec.yaml`

`file_picker` ^10 pide `win32` ^5 (choca con `flutter_secure_storage`, que pide ^6) y las 11.x/12.x
piden `dbus` ^0.7 (choca con `connectivity_plus`, que pide ^0.8); la 13.x usa métodos estáticos y
`saveFile` con `bytes`, incompatible con el envoltorio del editor. Como AxoNote no inserta imágenes
(son bloque opaco), se retira la dependencia: `file_picker_service.dart` define tipos propios
(`PickedFile`, `PickedFileType`) y `file_picker_impl.dart` lanza `UnsupportedError`. No afecta al
editor de texto.



