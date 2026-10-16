# Cómo generar y repartir el APK de release (para otros usuarios)

Resumen de lo necesario para pasar la app a otras personas **fuera de Play Store**. El detalle de la firma
está en `fase12-firma-release.md`. El APK de release pesa unos 26,8 MB (arm64); el de debug, más de 200 MB.

## 1. Una sola vez: almacén de claves y `key.properties`

Las contraseñas las eliges tú; **no las pegues en chats ni en archivos versionados**. Escribe el comando
en tu terminal (en Claude Code, con `!` delante para que `keytool` te las pida de forma interactiva):

```bash
mkdir -p ~/.axonote
keytool -genkeypair -v -keystore ~/.axonote/axonote-release.jks -alias axonote \
  -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=AxoNote, OU=Movil, O=AxoNote, C=CO"
cp app/android/key.properties.example app/android/key.properties   # y rellénalo
```

`key.properties` lleva `storePassword`, `keyPassword`, `keyAlias=axonote` y `storeFile` con la ruta
absoluta del `.jks`. Ambos archivos están ignorados por git.

**Guarda el `.jks` y sus contraseñas en un lugar seguro (gestor de contraseñas o copia cifrada).** Si se
pierden, no se podrán instalar actualizaciones sobre las versiones ya repartidas: cada usuario tendría que
desinstalar y volver a empezar. Este archivo no se sube a Git ni se copia por el repositorio.

## 2. Compilar el release

Con el toolchain cargado (JDK 17, Android SDK, Flutter) y desde `app/`:

```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols \
  --dart-define=API_URL=https://3-12-7-249.sslip.io/v1 \
  --dart-define=SHARE_ORIGIN=https://notify-web.zabaletac0395.workers.dev
```

- `API_URL` y `SHARE_ORIGIN` quedan **fijadas dentro del APK**: todos los usuarios usarán ese servidor y los
  enlaces públicos abrirán en esa web. Si cambian, hay que recompilar y repartir de nuevo.
- No definas `CF_ACCESS_ID` ni `CF_ACCESS_SECRET` en el release (plan §4.5).
- Salida: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (la gran mayoría de móviles actuales),
  `app-armeabi-v7a-release.apk` (teléfonos antiguos de 32 bits) y `app-x86_64-release.apk` (emuladores).

Verifica la firma (debe decir `Verifies` y `v2 scheme ... true`):

```bash
$ANDROID_HOME/build-tools/<versión>/apksigner verify --verbose build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Si falta `key.properties`, Gradle firma con la clave de **debug**: sirve para pruebas propias, pero no la repartas
(no se podrá actualizar con la firma definitiva).

## 3. Repartirlo

1. Pasa el `app-arm64-v8a-release.apk` por el canal que prefieras (enlace de descarga, mensajería, correo).
2. Cada usuario debe permitir «instalar apps de fuentes desconocidas» para el navegador o app desde la que lo abre.
3. Cada persona crea su propia cuenta; los datos están cifrados de extremo a extremo y no se comparten.
4. Para instalar tú en un dispositivo por cable: `adb install -r app-arm64-v8a-release.apk`.

## 4. Antes de repartir a mucha gente

- El **servidor** de `API_URL` debe estar encendido y accesible desde internet, con correo real configurado:
  el registro envía un código por correo. Sin eso, los usuarios nuevos no podrán registrarse.
- Pendiente de comprobar (ver `docs/estado-y-siguientes-pasos.md`): prueba contra QA con el release, biometría y
  recorrido con TalkBack en el ZTE.
- Para versiones nuevas: sube el número de versión en `app/pubspec.yaml` (`version: x.y.z+build`), recompila con el
  mismo `.jks` y reparte el APK; Android lo instala encima conservando los datos.
- La publicación en Play Store es la fase 13 (requiere dominio y cuenta de desarrollador).
