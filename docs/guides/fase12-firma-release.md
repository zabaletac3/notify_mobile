# Fase 12 · Firma del APK de release

Plan §5.4 y §12.5. El APK de release se firma con un almacén de claves **local, fuera del repo**.
Las contraseñas las conoce solo el dueño; **nunca** entran al repositorio ni a este documento.

## 1. Crear el almacén de claves (lo hace el dueño, una sola vez)

Elegir un directorio fuera del repo (por ejemplo `~/.axonote/`) y generar el `JKS`. `keytool`
preguntará las contraseñas de forma interactiva (no las escribas en ningún archivo versionado):

```bash
mkdir -p ~/.axonote
keytool -genkeypair -v \
  -keystore ~/.axonote/axonote-release.jks \
  -alias axonote -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=AxoNote, OU=Movil, O=AxoNote, L=, S=, C=ES"
```

Guardar el almacén y su contraseña en un sitio seguro. Si se pierde, no se pueden publicar
actualizaciones de la app con la misma firma.

## 2. Configurar `key.properties` (local, ignorado por git)

Copiar la plantilla `app/android/key.properties.example` a `app/android/key.properties` y rellenar:

```
storePassword=<contraseña del almacén>
keyPassword=<contraseña de la clave>
keyAlias=axonote
storeFile=/home/<usuario>/.axonote/axonote-release.jks
```

`app/android/key.properties` y los `.jks`/`.keystore` están en `.gitignore`; no se versionan.

`app/android/app/build.gradle.kts` lee ese archivo si existe y firma el release con él. Si no
existe (CI, desarrollo), cae a la clave de debug, de modo que `flutter build apk --release` y el
build de debug de la CI siguen funcionando sin secretos.

## 3. Compilar y verificar el release firmado

```bash
cd app
flutter build apk --release --split-per-abi --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=API_URL=https://<api-de-qa>/v1 \
  --dart-define=SHARE_ORIGIN=https://<web-de-qa>
```

> En el build de release `CF_ACCESS_ID`/`CF_ACCESS_SECRET` **no** deben ir definidos (plan §4.5).

Verificar la firma con `apksigner` (del SDK de Android):

```bash
$ANDROID_HOME/build-tools/<versión>/apksigner verify --verbose \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Debe indicar `Verifies` y `Verified using v2 scheme (APK Signature Scheme v2): true`.

## 4. Instalar en el ZTE

```bash
adb install -r app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Si ya había una versión firmada con otra clave, desinstalar antes (`adb uninstall com.axonote.app`).
