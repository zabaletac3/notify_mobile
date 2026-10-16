# Traspaso · Fase 11 (resto de la paridad)

Rama `fase-11-paridad` (PR #9). Fecha: 2026-10-15. Los commits, el push y el PR los hace el dueño.

## Estado por subfase

| Subfase | Contenido | Estado |
| --- | --- | --- |
| **11.1** | **Maqueta de Ajustes + navegación** | **Hecha y aprobada** (con 3 correcciones aplicadas) |
| **11.2** | **Cuenta (nombre, correo, contraseña, borrar cuenta, dispositivos, uso)** | **Hecha y aprobada** |
| **11.2b** | **Ajustes de Generales, Privacidad y Sincronización (reales)** | **Hecha y aprobada** |
| **11.3** | **Verificación en dos pasos y rotación de clave de recuperación** | **Hecha** |
| **11.4** | **Enlaces públicos y «Compartir» (editor y lista)** | **Hecha** |
| **11.5** | **Importar/exportar Markdown** | **Hecha** |
| **11.6** | **Acerca de (legales) y notas de la versión** | **Hecha** |
| **11.7** | **Pendientes de la fase 10 y repaso de la fase 9 (Movil v2)** | **Hecha** |

## 11.1 · Maqueta de Ajustes (hecho)

Siguiendo la estrategia obligatoria (primero maqueta, después servicios), se implementaron las
pantallas de Ajustes con **datos de muestra** y **sin servicios**:

- **Componentes nuevos** (`app/lib/ui/components/`): `top_bar.dart` (`AxoTopBar` con «atrás» y
  tooltip) y `settings_group.dart` (`AxoSettingsGroup` + `AxoSettingRow`).
- **Tokens** (`app/lib/ui/tokens.dart`): `settingsRowLabel` 15/500, `settingsRowDescription` 13/400,
  `settingsRowValue` 14/500, `settingsRowAction` 14/600; medidas `settingsRow` 52,
  `settingsRowSwitch` 54, `settingsRowCompact` 46, `settingsRowTall` 66, `settingsAvatar` 56,
  `settingsLogo` 72, `settingsProgress` 8. Ningún color/medida fijo en los widgets.
- **Pantallas** (`app/lib/features/settings/`): `settings_menu_screen`, `general_screen`,
  `account_screen`, `sync_screen`, `privacy_screen`, `storage_screen`, `delete_account_screen`,
  `about_screen`, más `settings_widgets.dart` (armazón + hoja de elección). Estado de muestra en
  `state/settings_mock.dart`.
- **Rutas** (`app/lib/router/app_router.dart`): `/settings/menu` y las siete subpantallas sustituyen
  a los `PlaceholderScreen`; `/settings/two-factor` queda para 11.3. Navegación con `push` y
  `goBack`/`PopScope` (helper `app/lib/router/navigation.dart`).

Interactividad de la maqueta: los interruptores y las opciones (Tema, Tamaño del texto, Orden,
Tiempo de bloqueo) cambian estado en memoria; «Cerrar sesión» usa el cierre de sesión real (fase 8);
los diálogos de cuenta (nombre, correo, contraseña) son interfaz sin servicio; el resto de acciones
muestran un aviso «Disponible en la fase 11.x».

### Puertas (2026-10-15)

| Puerta | Resultado |
| --- | --- |
| `dart format --output=none --set-exit-if-changed` (rutas de CI) | **OK** · 254 archivos, 0 cambiados |
| `flutter analyze` | **OK** · `No issues found!` |
| `cd app && flutter test` | **OK** · **329 pruebas, 0 fallos** |
| `flutter test` por paquete | **OK** · api 72 · crypto 133 · domain 66 · markdown 320 · platform 26 · sync 10 |
| `dart run tool/check_imports.dart` | **OK** · arquitectura correcta |
| `NOTIFY_WEB=… bash tool/check_contract.sh` | **OK** · contrato correcto |
| `flutter build apk --debug --dart-define=API_URL=…` | **OK** · instalado en el ZTE |

Goldens y comparación: `test/features/settings/settings_golden_test.dart` (16 goldens) y
`test/features/settings/settings_compare_test.dart` (geométrica, ±4 px por banda). Informe:
`docs/design/fase11-comparacion.md`. Navegación: `test/features/settings/settings_navigation_test.dart`.

## Diferencias y decisiones de la 11.1

- **`/settings/menu` no tiene tablero**: se sigue el menú de secciones de `notify_web` (anotado).
- **«Eliminar cuenta»**: el tablero pide escribir «ELIMINAR»; la app pide la **contraseña**
  (`POST /me/delete` exige `authKey`). La maquetación es la del tablero salvo el texto de la
  confirmación. Anotado en `docs/design/fase11-comparacion.md`.
- **«Exportar como PDF»** aparece en el tablero y en la web; el plan §1 solo nombra exportar
  Markdown. Se deja la fila en la maqueta; se decidirá en 11.5.
- El nombre de marca sigue «AxoNote» aunque el tablero diga «Apunte» (decisión ya tomada).

## 11.2 · Cuenta (hecho)

Servicios sobre la UI aprobada (sin cambiar su aspecto), con el mismo patrón que la fase 8.

- **Dominio** (`packages/axonote_domain`): `account.dart` (`Device`, `DevicePlatform`,
  `StorageUsage`); `AuthRepository` gana `updateProfile`, `requestEmailChange`,
  `confirmEmailChange`, `changePassword` y `deleteAccount`; nuevas interfaces `DeviceRepository` y
  `StorageRepository`.
- **Datos** (`app/lib/data/auth/`): `ApiAuthRepository` usa `AccountApi`; nuevos
  `ApiDeviceRepository` y `ApiStorageRepository`; proveedores en `bootstrap/providers.dart`.
  (Se añadió `hide DevicePlatform` en `axonote_api` para resolver el choque con el enum del
  dominio.)
- **Estado**: `AuthController` gana los métodos de cuenta (derivan `authKey`/`keK` con
  `axonote_crypto`, `changePasswordKeys` re-cifra la clave maestra sin re-cifrar notas) y
  `AuthState.pendingEmailChange` para el segundo paso del correo. Nuevos `DevicesController`
  (`devicesProvider`) y `StorageController` (`storageUsageProvider`).
- **UI**: «Mi cuenta» muestra la sesión y sus diálogos (nombre, correo en dos pasos, contraseña)
  llaman a los servicios; «Eliminar cuenta» pide la contraseña y cierra la sesión; «Sincronización»
  lista dispositivos reales y su estado viene del motor (fase 7); «Almacenamiento» usa el uso real.
- **Sin cambio de aspecto**: los goldens de 11.1 siguen (se regeneró el de «Almacenamiento» por el
  ancho real de la barra, 180/1024 en vez del 0,18 de muestra). Goldens nuevos de los tres diálogos.

### Puertas (11.2)

| Puerta | Resultado |
| --- | --- |
| `dart format` (CI) | **OK** · 261 archivos, 0 cambiados |
| `flutter analyze` | **OK** |
| `cd app && flutter test` | **OK** · **350 pruebas, 0 fallos** |
| Paquetes | api 72 · crypto 133 · domain 66 · markdown 320 · platform 26 · sync 10 |
| `check_imports.dart` / `check_contract.sh` | **OK** |
| APK debug + `adb install -r` | **OK** |

## Pendiente / siguiente

- **Fase 11 cerrada** (11.1–11.7) con todas las puertas en verde y el APK instalado en el ZTE.
- Los commits, el push y el PR los hace el dueño.

## 11.4 · Enlaces públicos y «Compartir» (hecho)

- **Dominio/datos**: `ShareRepository` (`axonote_domain/.../share_repository.dart`) con las
  entidades `ShareLink`, `SharedNote`, `ShareInput`, `PublicNote`, `SharedNoteContent`;
  `ApiShareRepository` sobre `ShareApi` (rutas `/notes/{id}/share`).
- **Cifrado** (`app/lib/data/crypto/share_codec.dart`): la clave del enlace se envuelve con
  `Vault.requireKey()` (decisión en `docs/decisions.md`); la copia pública cifra `{title, content}`.
- **Estado** (`features/share/state/share_controller.dart`): crear/cargar/revocar/abrir y
  **republicar** (actualiza la copia al guardar la nota; §8.3, plan §385).
- **UI** (`features/share/ui/share_sheet.dart`): hoja «Compartir nota» (tablero) con URL, Copiar,
  interruptor de enlace y filas de exportar; se abre desde el botón del editor y desde «Compartir»
  del menú contextual de la lista (fila añadida). `SHARE_ORIGIN` por `--dart-define`.

## 11.5 · Importar/exportar Markdown (hecho)

- **Dependencias**: `file_picker ^13.1.0` y `archive ^4.4.0`. **No chocaron** con `win32`/`dbus`
  (que siguen en 6.4.0/0.8.0, sin cambios); no hizo falta canal de plataforma.
- **Dominio** (`axonote_domain/markdown_import.dart`): `parseMarkdownNote` (reglas de
  `markdown-import.ts`), `exportNoteMarkdown`; probado con los casos de la web.
- **Datos** (`app/lib/data/markdown_files.dart`): selector del sistema para importar
  (.md/.markdown/.txt, ≤ 2 MB) y para guardar `.md` y `.zip`; `buildNotesZip`.
- **Estado/UI**: `ImportExportController`; «Almacenamiento y exportación» exporta todo (zip),
  importa y vacía la papelera; «Exportar como Markdown» de la hoja «Compartir» (editor y lista).

## 11.6 · Acerca de y textos legales (hecho)

- **Dominio** (`axonote_domain/lib/src/legal/`): `terms`, `privacy` (portados de la web),
  `changelog`, `responsible`; sellados los bloques de contenido.
- **Pantallas** (`features/legal/ui/`): `/terms`, `/privacy` (genérica + aviso de borrador),
  `/changelog` y `/support`; «Licencias de código abierto» usa `showLicensePage` de Flutter.
- **«Acerca de»**: versión leída del paquete (`package_info_plus`) y filas que abren cada enlace.

## 11.7 · Pendientes de la fase 10 y repaso de la fase 9 (hecho)

- **Editor real**: solo lectura si la nota está en conflicto; abre la hoja de conflicto de la nota
  abierta (una vez) y muestra «Sincronizando…» cuando el motor sincroniza. El menú «Más» abre el
  menú contextual de la nota.
- **Pruebas de la pantalla real del editor** (`test/features/editor/editor_screen_test.dart`):
  carga (título y cuerpo), guarda el título, recarga al cambiar por fuera y «Compartir» abre la hoja.
- **Repaso de la fase 9 contra «Movil v2»**: tokens/estilo coinciden (muestreo de fondos en los PNG
  de Pencil); sin correcciones. Detalle en `docs/design/fase11-comparacion.md`.

### Puertas (11.4–11.7, 2026-10-15)

| Puerta | Resultado |
| --- | --- |
| `dart format` (rutas de CI) | **OK** · 292 archivos, 0 cambiados |
| `flutter analyze` | **OK** · `No issues found!` |
| `cd app && flutter test` | **OK** · **383 pruebas, 0 fallos** |
| Paquetes | api 72 · crypto 133 · domain 79 · markdown 320 · platform 26 · sync 10 |
| `check_imports.dart` / `check_contract.sh` | **OK** |
| APK debug + `adb install -r` | **OK** |

## 11.2b · Ajustes de Generales, Privacidad y Sincronización (hecho)

Conectados con servicios reales y persistencia por cuenta, reutilizando lo existente y sin cambiar
el aspecto aprobado (salvo «Cifrar notas», ver abajo).

- **Preferencias locales** (`AppSettings`: tema, tamaño, orden, «abrir con nota nueva» y «mostrar
  vista previa»): se guardan en el almacén seguro por cuenta (`AccountSecureStore`, clave
  `appSettings.<userId>`, igual que la web con su `LocalSettingsRepository`). Las carga el arranque
  en frío (`SettingsController.load`, llamado desde `main.dart` con `bootstrap`).
- **Tema**: se aplica a toda la app (`MaterialApp.themeMode` desde `settingsProvider`) y persiste.
  **Tamaño de letra**: se aplica con `MediaQuery.textScaler` (0,9 / 1,0 / 1,15; `medium` = 1,0, así
  los goldens no cambian). **Orden por defecto**: lo usa la lista (`NotesViewController`).
- **Bloqueo** (huella, bloquear al salir, tiempo): reutiliza `VaultLockController` y
  `VaultPrefsRepository`; al cambiar se persiste (`writeLockSettings`) y se aplica
  (`updateSettings`).
- **Sincronización** (automática, solo con Wi-Fi): reutiliza `SyncSettings` (base local); el motor
  (`sync_triggers`) ya los respeta. «Sincronizar ahora» fuerza una.
- **Contadores reales**: «Verificación en dos pasos» desde `GET /mfa` (`AuthRepository.mfaStatus`);
  «Sesiones activas» desde `/devices`.
- **«Cifrar notas en este dispositivo»**: informativo (la base va cifrada siempre, §6); se quita el
  interruptor (era falso) y se deja una fila de descripción. La golden de Privacidad se regeneró por
  ese cambio.
- **Efectos reales nuevos**: «Mostrar vista previa en la lista» oculta la vista previa de la tarjeta;
  «Abrir con una nota nueva» abre una nota al mostrar la lista (una vez).

### Puertas (11.2b)

| Puerta | Resultado |
| --- | --- |
| `dart format` (CI) | **OK** · 267 archivos, 0 cambiados |
| `flutter analyze` | **OK** |
| `cd app && flutter test` | **OK** · **354 pruebas, 0 fallos** |
| Paquetes | api 72 · crypto 133 · domain 66 · markdown 320 · platform 26 · sync 10 |
| `check_imports` / `check_contract` | **OK** |
| APK debug + `adb install -r` | **OK** |

## 11.3 · Verificación en dos pasos y clave de recuperación (hecho)

- **Pantalla `/settings/two-factor`** (`TwoFactorSettingsScreen`, sin tablero): estado real
  (`GET /mfa`), y las operaciones de la web.
  - **Activar**: contraseña → `setup` → muestra **QR** (paquete `qr`, pintado sin `qr_flutter`) y el
    secreto en base32 → código → `enable` → muestra los 10 **códigos de respaldo** (una sola vez).
  - **Desactivar** y **Regenerar códigos**: contraseña + código. Se pide la contraseña y un código
    (operaciones sensibles) y se confirman en diálogo.
- **Rotación de clave de recuperación**: fila «Clave de recuperación · Crear nueva» en Privacidad;
  pide la contraseña, `axonote_crypto.rotateRecoveryKeys` recalcula el material y `PUT /keys/recovery`
  lo sube; se muestra la clave nueva (una sola vez, con copiar).
- **Dependencia**: `qr: ^3.0.2` declarada en `app/pubspec.yaml` (ya estaba en el lock).
- **Desviación anotada**: el tablero de Privacidad no trae «Clave de recuperación» (el plan/web sí),
  así que el grupo «Datos»/«Cuenta» queda fuera de la puerta de bandas de esa pantalla
  (`docs/design/fase11-comparacion.md`).
- **Pruebas**: goldens de la pantalla (desactivada, claro/oscuro) y de Privacidad regenerados; 5
  unitarias nuevas (`mfaSetup`, `mfaEnable`, `mfaDisable`, `mfaRegenerateCodes`, `rotateRecoveryKey`).
  Los flujos con contraseña/código solo se prueban con fakes; **nunca** contra el backend real.

| Puerta | Resultado |
| --- | --- |
| `dart format` (CI) | **OK** · 268 archivos, 0 cambiados |
| `flutter analyze` | **OK** |
| `cd app && flutter test` | **OK** · **361 pruebas, 0 fallos** |
| Paquetes | api 72 · crypto 133 · domain 66 · markdown 320 · platform 26 · sync 10 |
| `check_imports` / `check_contract` | **OK** |
| APK debug + `adb install -r` | **OK** |
