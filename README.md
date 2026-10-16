# AxoNote móvil

App Android (Flutter) de AxoNote, con paridad funcional con la web. Lee y escribe el mismo
formato cifrado y el mismo protocolo de sincronización.

- Plan de ejecución y decisiones: [`docs/plan.md`](docs/plan.md) (plan 0007).
- Traspaso de la fase 12: [`docs/handoff-fase12.md`](docs/handoff-fase12.md).
- Panel y bloqueos: [`docs/blockers.md`](docs/blockers.md).
- Mediciones: [`docs/benchmarks.md`](docs/benchmarks.md).
- Accesibilidad: [`docs/design/fase12-accesibilidad.md`](docs/design/fase12-accesibilidad.md).
- Seguridad: [`docs/security-review.md`](docs/security-review.md).

## Requisitos

- **Flutter** estable (probado con **3.47.7**, Dart 3.13.5). El workspace fija Flutter en
  `pubspec.lock`.
- **JDK 17** para Gradle (Temurin 17 probado). `flutter config --jdk-dir=$JAVA_HOME`.
- **SDK de Android** (command-line tools) con `platform-tools`, `platforms;android-36`,
  `build-tools;36.0.0`.
- **Un dispositivo Android** (mínimo API 26; referencia: ZTE 8050, Android 13) por USB con la
  depuración activada, o un emulador.

Instalación del toolchain (ejemplo, Linux):

```bash
# Flutter estable
git clone --depth 1 -b stable https://github.com/flutter/flutter.git ~/development/flutter
export PATH="$HOME/development/flutter/bin:$PATH"
# JDK 17 y SDK de Android (variables de entorno)
export JAVA_HOME="$HOME/development/jdk17"
export ANDROID_HOME="$HOME/Android/Sdk"
flutter doctor
```

## Ejecución

La configuración por entorno va por `--dart-define` (plan §4.5):

| Variable | Desarrollo | QA / producción |
| --- | --- | --- |
| `API_URL` | `http://localhost:8080/v1` (con `adb reverse tcp:8080 tcp:8080`) | URL de QA / producción (HTTPS) |
| `SHARE_ORIGIN` | origen de la web desplegada | ídem |
| `CF_ACCESS_ID`, `CF_ACCESS_SECRET` | vacío | **prohibido en release** (el build falla si están definidos) |

```bash
flutter pub get
adb reverse tcp:8080 tcp:8080        # backend local (notify_backend)
flutter run -d <deviceId> \
  --dart-define=API_URL=http://localhost:8080/v1 \
  --dart-define=SHARE_ORIGIN=https://app.example
```

El HTTP en claro solo se permite en builds de **debug** y solo hacia el backend local
(`app/android/app/src/debug/res/xml/network_security_config.xml`); el release va solo por HTTPS.

## Pruebas y puertas de calidad

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test                          # app
for p in packages/axonote_*; do [ -d "$p/test" ] && (cd "$p" && flutter test); done
dart run tool/check_imports.dart      # reglas de dependencia (§4.2)
NOTIFY_WEB=/ruta/a/notify_web bash tool/check_contract.sh   # contrato (§D14)
flutter build apk --debug
```

Pruebas **en dispositivo** (Android real, no en el analizador): `app/integration_test/`
(rendimiento, cifrado local, plataforma, extremo a extremo contra el backend local). Detalle de los
comandos en la cabecera de cada archivo.

Cobertura por capa (mínimos de la §11): `flutter test --coverage` y `lcov`. Estado en la fase 12:
crypto/markdown/sync 98/99/100 %, domain/api 93/100 %, `app/lib/data` 87 %, estado 81 %.

## Medidas

Los presupuestos de la §11 (arranque, desbloqueo, KDF, nota de 10/100 KB, búsqueda, desplazamiento,
primera sincronización, memoria, tamaño del APK) se miden en el ZTE y se anotan en
[`docs/benchmarks.md`](docs/benchmarks.md) (fase 12: medido vs límite).

## Compilación de release y firma

El release se firma con un almacén **local, fuera del repo** (`~/.axonote/…jks`); las contraseñas
las pone el dueño en `app/android/key.properties` (ignorado por git). Guía completa:
[`docs/guides/fase12-firma-release.md`](docs/guides/fase12-firma-release.md).

```bash
cd app
flutter build apk --release --split-per-abi --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=API_URL=https://<api>/v1 --dart-define=SHARE_ORIGIN=https://<web>
```

Sin `key.properties` (CI, desarrollo) el release se firma con la clave de debug, de modo que las
puertas de la CI siguen pasando sin secretos.

## Estructura

```
pubspec.yaml        workspace (hooks: sqlite3 con SQLite3MultipleCiphers)
contract/           copia verificada de notify_web (openapi.yaml, vectors/)
tool/               scripts de contrato, imports y comprobaciones
docs/               plan, decisiones, pantallas, benchmarks, bloqueos, seguridad
packages/           paquetes Dart puros: domain, crypto, markdown, api, sync, platform
app/                aplicación Flutter (datos locales, estado, interfaz)
```
