# Fase 12 · Revisión de seguridad (app móvil)

Rama `fase-12-endurecimiento`. Recorre la lista de la §5.4 del plan y el checklist de
`notify_backend/docs/security.md` que aplica al cliente. Cada punto lleva evidencia
(archivo/línea o prueba) o el hallazgo. Fecha: 2026-10-16.

## Hallazgos y correcciones aplicadas

### 1. El APK de release no declaraba `INTERNET` (corregido)

`aapt2 dump permissions` sobre el release anterior no mostraba `android.permission.INTERNET`: el
manifiesto de `main` no lo declaraba y Flutter solo lo aporta en `debug`/`profile` (para el
tooling). Sin el permiso, el release **no puede** hablar con la API (login, sincronización, cuenta).
Se añade `INTERNET` al manifiesto principal (`app/android/app/src/main/AndroidManifest.xml:6`), así
que ahora aparece en los tres builds. Verificado con `aapt2 dump permissions` tras recompilar.

### 2. No había configuración de red para el backend local (corregido)

La §4.5 exige «HTTP en claro solo en el manifiesto de debug y solo para `localhost`». Se añade
`app/android/app/src/debug/res/xml/network_security_config.xml` (permite texto en claro solo a
`localhost`, `127.0.0.1` y `10.0.2.2`; el resto, HTTPS) y se referencia desde el manifiesto de
debug. En release no hay config: el valor por defecto de Android con `targetSdk ≥ 28` bloquea el
texto en claro, así que **el release va solo por HTTPS**.

## Checklist §5.4 · estado y evidencia

| Control | Estado | Evidencia |
| --- | --- | --- |
| `allowBackup="false"` + extracción de datos que excluye todo | OK | `AndroidManifest.xml:6-8`; `res/xml/data_extraction_rules.xml` (excluye `root` en `cloud-backup` y `device-transfer`, también para API 31+) |
| `FLAG_SECURE` en clave de recuperación, códigos de respaldo, secreto TOTP y desbloqueo | OK | `SecureScreen` envuelve esas pantallas (`recovery_key_screen.dart:46`, `unlock_screen.dart:60`, 2FA); `AxonotePlatform.setSecure` (`AxonotePlatformPlugin.kt:234-250`) |
| `FLAG_SECURE` en el resto y vista previa en recientes | OK (más estricto) | La raíz de la app lo activa siempre (`main.dart:135`, `restoreOnDispose: false`) y lo repone al volver a primer plano (`secure_screen.dart:43-45`). No hay interruptor para desactivarlo: se decide dejarlo siempre activo (más protegido que el «activado por defecto» de la §5.4) |
| Capturas de pantalla bloqueadas | OK | `FLAG_SECURE` (oculta la vista previa en recientes y bloquea capturas) |
| Almacenamiento seguro de tokens y `KeyBundle` | OK | `flutter_secure_storage` por cuenta (`data/secure/account_secure_store.dart`); la clave maestra va en el módulo nativo, cifrada con Keystore (`MasterKeyStore.kt`), no en `flutter_secure_storage` (A9) |
| Borrado de material al cerrar sesión / `device-revoked` | OK | `auth_controller.dart:88` (device-revoked), `:901-902` (`_vault.signOut` + `_cleaner.wipe`), `local_data_cleaner.dart`, `LocalDatabase.wipe` (A1). Prueba: `app/test/features/auth/auth_controller_test.dart` |
| Bloqueo por tiempo y al salir | OK | `VaultLockController` + `VaultPrefsRepository` (`features/vault/state/vault_lock.dart`); ajustes en `devices`/`Privacidad`. Pruebas: `app/test/features/vault/vault_lock_test.dart` |
| Tráfico solo HTTPS; claro solo en debug | OK | Release sin `networkSecurityConfig` (bloqueo por defecto); debug con la config local (arriba) |
| `network_security_config` | OK | `app/android/app/src/debug/res/xml/network_security_config.xml` |
| Pinning de certificado | Fuera de v1 | Plan §1 «Fuera»: no hay dominio definitivo → TLS estándar. Documentado |
| Logs sin secretos | OK | `grep` de `print`/`debugPrint`/`developer.log` en `app/lib`: **ninguno**; lint `avoid_print`. En el módulo nativo no hay `Log.`/`println`. No se registran contraseñas, claves, tokens ni texto de notas |
| Portapapeles (enlaces y códigos de respaldo) | OK | Clave de recuperación y códigos de respaldo con `copySensitive` → `EXTRA_IS_SENSITIVE` (Android 13+), `AxonotePlatformPlugin.kt:252-266`; el enlace público se copia con `Clipboard.setData` porque es público por diseño (`share_sheet.dart:84`) |
| Deep links y `exported` | OK | No hay App Links (plan §1 «Fuera»). El único componente exportado es `MainActivity` (lanzador): `AndroidManifest.xml:15`. No hay `intent-filter` de enlaces |
| Permisos mínimos | OK | Revisados con `aapt2`: `INTERNET`, `ACCESS_NETWORK_STATE` (connectivity_plus), `USE_BIOMETRIC`/`USE_FINGERPRINT` (androidx.biometric). Sin ubicación, cámara, contactos ni almacenamiento externo |
| Ofuscación en release | OK | R8 con `isMinifyEnabled`/`isShrinkResources` (`build.gradle.kts`); la ofuscación de nombres de Dart la añade el comando con `--obfuscate --split-debug-info` (guía de firma) |
| Rotación de clave y cambio de contraseña sin material viejo | OK | `axonote_crypto.rotateRecoveryKeys`/`changePasswordKeys` recalculan el material sin re-cifrar notas (documentado en `docs/decisions.md`); `PUT /keys/recovery` sustituye la clave antigua. El cambio de contraseña desde otro dispositivo invalida esta sesión (se trata como `session-expired`, §5.4) |
| Base local cifrada | OK | SQLite3MultipleCiphers (D10); clave derivada de la maestra (A2). Pruebas en dispositivo: `integration_test/local_encryption_device_test.dart` (sin clave o con otra, no abre; el archivo no contiene texto en claro) |

## Modelo de confianza (resumen)

- El servidor solo ve texto cifrado de extremo a extremo; el cliente cifra/descifra con claves
  derivadas por Argon2id (libsodium) y AES-256-GCM (`cryptography`). Ver `docs/plan.md` §3 y §5.
- La base local está cifrada entera; con el cofre bloqueado no hay base abierta ni sincronización
  (A3).
- Los tokens de sesión permiten saber si hay sesión sin desbloquear; por eso van en
  `flutter_secure_storage` sin autenticación (A9).

## Pendiente / fuera de alcance

- **Prueba contra QA con el token de servicio**: ver `docs/guides/fase12-prueba-qa.md` (sin el token
  no se puede ejecutar aquí).
- **Pinning**: fuera de v1 (plan §1).
- **App Links**: fuera de v1 (plan §1).
- **ZAP/nuclei contra la API**: se ejecutan sobre el backend, no desde la app; ver
  `notify_backend/docs/security.md`.
