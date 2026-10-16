# Fase 12 · Prueba contra QA (guion manual)

Plan §12.6. Esta prueba se hace **desde el APK de release en el ZTE** contra la API de QA, con una
**cuenta de prueba** (nunca la cuenta real). Requiere lo que solo tiene el dueño:

- La URL de la API de QA y el origen de la web para `SHARE_ORIGIN`.
- El token de servicio de Cloudflare Access (`CF_ACCESS_ID` / `CF_ACCESS_SECRET`), que **solo va en
  builds de desarrollo** (plan §4.5): en release está prohibido y el build falla si está definido.

> **Nunca** escribas el token, la contraseña ni el correo de la cuenta de prueba en ningún archivo
> versionado, log o captura. Si el token no está disponible, este guion queda para ejecutarlo luego.

## Preparación

1. Compilar e instalar el release (ver `docs/guides/fase12-firma-release.md`):

   ```bash
   cd app
   flutter build apk --release --split-per-abi --obfuscate \
     --split-debug-info=build/symbols \
     --dart-define=API_URL=https://<api-de-qa>/v1 \
     --dart-define=SHARE_ORIGIN=https://<web-de-qa>
   adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
   ```

2. Preparar una cuenta de prueba nueva en QA (correo accesible por el dueño).

## Guion paso a paso

Anotar OK/fallo y (si aplica) la captura o el mensaje, **sin datos personales**.

1. **Registro**: crear cuenta con la contraseña de prueba. Comprobar el medidor de contraseña y que
   los errores de validación se muestran.
2. **Verificación**: introducir el código de 6 dígitos del correo. Reintentos y reenvío.
3. **Clave de recuperación**: mostrarla una vez, copiarla y confirmarla.
4. **Crear una nota** con formato variado (títulos, listas de tareas, código, cita).
5. **Sincronización**: esperar a que sincronice (`Sincronizando…` → `Sincronizado`); abrir la nota en
   la **web** con la misma cuenta y comprobar que el contenido coincide byte a byte.
6. **Bloqueo y desbloqueo**: bloquear manualmente y desbloquear con huella y con contraseña.
7. **Compartir**: crear un enlace público, abrirlo en el navegador (debe verse la copia), editar la
   nota y comprobar que la copia pública se actualiza; revocar el enlace y confirmar que deja de
   abrirse.
8. **Importar/exportar**: exportar Markdown (una nota y todo en `.zip`); importar un `.md` de
   prueba y comprobar que aparece en la lista.
9. **Cambio de contraseña**: cambiarla desde Ajustes › Mi cuenta; comprobar que la sesión se cierra
   en el otro cliente y que el inicio de sesión con la contraseña nueva funciona.
10. **Cierre**: cerrar sesión; comprobar que la base local se borra (A1) y que se puede volver a
    entrar.

## Extremo a extremo automático contra el backend local

Ya existe: `app/integration_test/auth_flow_integration_test.dart` cubre **registro → verificación →
clave → cerrar sesión → inicio de sesión → bloqueo → desbloqueo** con el cliente HTTP real y Argon2id
ligero. Instrucciones de ejecución en la cabecera del archivo (requiere el backend local con
`MAIL_PROVIDER=log` y las variables `AXONOTE_API_URL` y `AXONOTE_MAIL_LOG`). No toca `notify_backend`.

## Estado

- **Pendiente**: ejecución contra QA en el ZTE. Falta el token de servicio y las URLs de QA, que los
  aporta el dueño en el momento. La prueba extremo a extremo contra el backend local está lista para
  ejecutarse cuando el backend esté levantado.
