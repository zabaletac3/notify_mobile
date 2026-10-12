# Fase 8 · Prueba manual (cuenta: móvil ↔ web)

Cubre el «Hecho cuando» de la fase 8: **una cuenta creada en el móvil abre en la web y al revés,
con y sin verificación en dos pasos**. Requiere una persona; no se automatiza.

## Preparación (una vez)

1. **Backend local** (no se modifica). En `notify_backend`:
   - `make up-podman` (PostgreSQL), `make migrate` y `make run` con `MAIL_PROVIDER=log`.
   - Redirige la salida del proceso a un fichero; ese fichero es el «log de correo» donde aparece
     el código de verificación. Exporta `AXONOTE_MAIL_LOG=<ruta>`.
2. **Web** contra el mismo backend: en `notify_web`, `pnpm dev:http` (o `PUBLIC_BACKEND=http` +
   `PUBLIC_API_URL=http://localhost:8080/v1`). Ábrela en el navegador.
3. **Móvil** por USB con el backend en el PC:
   - `adb reverse tcp:8080 tcp:8080`.
   - Instala el APK de debug:
     `cd app && flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`.
   - La app usa `API_URL=http://localhost:8080/v1` (por defecto). Si hiciera falta otro origen,
     compila con `--dart-define=API_URL=...`.

## A · Cuenta creada en el móvil, abierta en la web (sin 2FA)

1. En el móvil: **Bienvenida → Crear cuenta**; rellena nombre, correo, contraseña
   (≥ 8 caracteres), acepta los términos y pulsa **Crear cuenta**.
2. Lee el código de 6 dígitos en `AXONOTE_MAIL_LOG` (aparece «Para: <correo> … código de
   verificación es NNNNNN»); escríbelo en la verificación y pulsa **Verificar**.
3. Aparece la **clave de recuperación** (solo una vez). Pulsa **Copiar clave**, márcala como
   guardada y **Continuar**. Llegas a la pantalla de notas.
4. En la web: **Inicia sesión** con el mismo correo y contraseña. Debe entrar y mostrar la cuenta
   (la clave se desenvuelve en el cliente). ✅ La cuenta del móvil abre en la web.

## B · Cuenta creada en la web, abierta en el móvil (sin 2FA)

1. En la web: crea una cuenta nueva (registro + código + clave de recuperación).
2. En el móvil: **Bienvenida → Ya tengo una cuenta**; introduce ese correo y contraseña; **Iniciar
   sesión**. Debe desbloquear y mostrar las notas. ✅ La cuenta de la web abre en el móvil.

## C · Con verificación en dos pasos (2FA)

1. En la web, activa 2FA en **Ajustes → Verificación en dos pasos** (gera el secreto TOTP y los
   códigos de respaldo).
2. En el móvil, cierra sesión (en la pantalla de notas provisional, **Cerrar sesión**; en la lista
   real, desde Ajustes) y vuelve a **Iniciar sesión** con el mismo correo y contraseña.
3. El móvil debe pedir el **segundo factor**: escribe el código TOTP de 6 dígitos (o un código de
   respaldo `XXXXX-XXXXX`). Debe entrar. ✅
4. Repite probando con un **código de respaldo**.

## D · Bloqueo y desbloqueo

1. En la pantalla de notas, **Bloquear**. Vuelve la pantalla de desbloqueo.
2. Desbloquea con la contraseña. Con `biometricLock` activo, si la clave ya estaba recordada, no
   debe volver a pedir biometría/credencial de forma redundante (decisión de la fase 8).
3. **Cerrar sesión** debe llevar a la bienvenida.

## E · Prueba de integración automatizada (opcional)

Con el backend y `AXONOTE_MAIL_LOG` listos:

```
cd app
flutter test integration_test/auth_flow_integration_test.dart --tags integration
```

Hace registro → verificación → clave de recuperación → cerrar sesión → login → bloqueo →
desbloqueo contra el backend local (no toca el backend).

## Qué mirar si algo falla

- El código no aparece: revisa que `MAIL_PROVIDER=log` y el fichero apuntado por `AXONOTE_MAIL_LOG`.
- `network`: `adb reverse` no está activo o el backend no escucha en 8080.
- La web y el móvil deben apuntar al **mismo** backend; si no, las cuentas no coinciden.
