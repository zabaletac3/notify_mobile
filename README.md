# AxoNote móvil

App Android (Flutter) de AxoNote, con paridad funcional con la web. Lee y escribe el mismo
formato cifrado y el mismo protocolo de sincronización.

- Plan de ejecución y decisiones: [`docs/plan.md`](docs/plan.md) (plan 0007).
- Estado de avance y bloqueos: [`docs/blockers.md`](docs/blockers.md).
- Mediciones: [`docs/benchmarks.md`](docs/benchmarks.md).

## Requisitos de desarrollo

- Flutter estable (probado con 3.47.x).
- SDK de Android (command-line tools) con `platform-tools`, `platforms;android-36`,
  `build-tools;36.0.0`.
- JDK 17 para Gradle (`flutter config --jdk-dir=...`).
- Un dispositivo Android por USB (`adb devices`) o un emulador.

## Arranque

```bash
flutter pub get
flutter run                      # con el teléfono por USB
flutter build apk --debug        # solo compilar
```

## Estructura

```
pubspec.yaml        workspace
contract/           copia verificada de notify_web (openapi.yaml, vectors/)
tool/               scripts de contrato, imports y comprobaciones
docs/               plan, decisiones, pantallas, benchmarks, bloqueos
packages/           paquetes Dart puros: domain, crypto, markdown, api, sync, platform
app/                aplicación Flutter (datos locales, estado, interfaz)
```
