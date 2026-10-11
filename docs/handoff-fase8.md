# Traspaso · Fase 8 (cuenta)

Rama `fase-8-cuenta` en `notify_mobile-fase-8`. No hay push ni PR.

## Hecho

- **Dominio** (`packages/axonote_domain`): validaciones portadas de `validation.ts` + `auth.dart`
  (tipos), `result.dart` (`Ok`/`Err`), interfaces `AuthRepository`, `VaultPrefsRepository`,
  `VaultActivityStore`, `LocalDataCleaner`.
- **Datos** (`app/lib/data`): `ApiAuthRepository`, `AccountTokenStore`, `SecureVaultPrefs`,
  `SessionEventBus`, `FileSystemDataCleaner`, `IsolateArgon2id`; `AccountSecureStore` con
  `expiresAt`, `lastActiveAt`, `clearTokens`.
- **Estado** (`features/auth/state`): `AuthController` (Riverpod) + `AuthState` + `VaultLifecycle`
  (onUnlocked/onSignedOut para la fase 7). Arranque en frío y regla de auto-desbloqueo.
- **Plataforma** (`axonote_platform`): `deviceModel()` y `hasStoredMasterKey()` (Kotlin + Dart +
  fake).
- **UI** (`features/auth/ui`): welcome, onboarding, register, verify, recovery-key, login,
  two-factor, forgot-password, forgot-password-sent, unlock, session-expired (diálogo), server-error.
  Router con guardas reales; sin botones de demostración.
- **Componentes**: `AxoOtpInput`, `AxoPasswordStrength`, `AxoToast`; `AxoDialog` con `icon`;
  `AxoOtpField` activo con `bgEditor` + borde `accent`; icono Lucide `mail`.
- **Penpot**: todos los tableros de la fase 8 leídos por el MCP (ver
  `docs/design/penpot-progress.md`).
- **Pruebas**: dominio 66, app 147 (incluye 22 goldens de pantalla + componentes), plataforma 26.
  Integración `app/integration_test/auth_flow_integration_test.dart` (tag `integration`, skip por
  defecto).
- **Docs**: `docs/decisions.md` «Fase 8», `docs/guides/fase8-prueba-manual.md`.

## Puertas (todas en verde)

`flutter pub get`; `dart format --set-exit-if-changed` (0 cambios); `flutter analyze` (sin avisos);
`flutter test` (app 147); tests de `axonote_api` (72), `axonote_crypto` (133), `axonote_domain` (66),
`axonote_platform` (26); `dart tool/check_imports.dart`; `bash tool/check_contract.sh`;
`flutter build apk --debug`. APK instalado en el ZTE (LZ0V50COPBC002769) y app abierta.

## Pendiente / riesgos

- Prueba de integración **no ejecutada** (requiere backend local + `AXONOTE_MAIL_LOG`); runbook en
  el encabezado del fichero y en la guía manual.
- «Hecho cuando» (móvil↔web, con y sin 2FA) necesita a una persona: guía en
  `docs/guides/fase8-prueba-manual.md`.
- Sin golden de «clave de recuperación» (su contenido es aleatorio; se omitió para que el golden sea
  estable).
- Diferencias de diseño anotadas en el informe (marca AxoNote vs Apunte; Google fuera por D5;
  Registro con tarjeta del tablero claro).
- Las pantallas «Clave de recuperación», «Segundo factor» y «Desbloqueo» **no tienen tablero** en
  Penpot; se compusieron con tokens y componentes base (como dice `docs/screens.md`).
