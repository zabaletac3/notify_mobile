# Guía paso a paso · Prueba manual de la Fase 7 (sincronización cruzada)

«Hecho cuando» de la fase 7 (plan §10): *con la web y el móvil sobre la misma cuenta en el
backend local, crear, editar, mover a la papelera, borrar y generar un conflicto en ambos
sentidos, sin pérdida de datos.*

Como la fase 8 (cuenta) todavía no existe, el móvil no tiene pantallas: nada de esto se puede
tocar con el dedo todavía. Esta guía lo comprueba con lo que sí existe hoy:

- La parte **automática** ya cerrada: los 19 escenarios de `contract/vectors/sync-behavior.json`
  (`app/test/sync/sync_behavior_vectors_test.dart`) **son** el comportamiento real de
  `LocalSyncRepository` de la web, grabado y reproducido sobre el motor real del móvil
  (`SyncEngine`) y un `SyncStore` real. Si esos 19 escenarios pasan, el protocolo y las reglas de
  conflicto, lápidas, paginación y cola ya son compatibles byte a byte con la web — eso es la
  mitad lógica del «Hecho cuando».
- Lo que esos vectores **no** prueban: que el *dispositivo de verdad*, hablando HTTP de verdad con
  el backend local, lee y escribe lo que escribe o lee un *navegador de verdad* sobre la misma
  cuenta. Eso es lo que cubre esta guía, con `app/integration_test/sync_cross_client_test.dart`
  (sin interfaz: conduce `axonote_api` + `axonote_crypto` + `LocalDatabase` + `SyncEngine`
  directamente) y acciones manuales en un navegador.

## Antes de empezar

1. En `notify_backend`: `make up-podman` (o `make up`) y `make run`. Deja esa terminal visible: el
   código de verificación del correo se imprime ahí (`MAIL_PROVIDER=log`).
2. En `notify_web`: `pnpm dev:http` (o el backend ya corriendo + `pnpm dev` con
   `PUBLIC_BACKEND=http`), apuntando al mismo backend local. Abre esa web en el navegador.
3. Conecta el móvil por USB con la depuración activada y, desde `notify_mobile-fase-7/app`:

   ```
   flutter pub get
   adb devices                      # copia la serie en $SERIE
   adb reverse tcp:8080 tcp:8080    # el móvil ve localhost:8080 como el backend local (D8)
   ```

## Paso 1 · Crear la cuenta y la primera nota en el móvil

```
flutter test integration_test/sync_cross_client_test.dart -d $SERIE \
  --plain-name "paso 1"
```

1. La terminal imprimirá la cuenta (`axonote-fase7@example.com` / la contraseña fija del
   archivo) y, si hizo falta registrar, un aviso para leer el código de verificación en la
   terminal del backend.
2. **Si pide verificar:** copia el código de 6 cifras que aparece en la terminal de
   `notify_backend` (busca el correo de `axonote-fase7@example.com`) y verifica la cuenta con una
   petición directa (por ejemplo con `httpie`/`curl`):

   ```
   http POST localhost:8080/v1/auth/verify-email email=axonote-fase7@example.com code=123456
   ```

   Vuelve a correr el comando del paso 1: esta vez entra por el camino de inicio de sesión y crea
   la nota.
3. Al terminar en verde, la terminal imprime el id de la nota creada («Nota desde el móvil»).
4. **En el navegador:** inicia sesión en la web con `axonote-fase7@example.com` y la contraseña
   del archivo (`clave-de-prueba-fase7-AxoNote`). Confirma que **ves la nota que creó el móvil**,
   con su texto exacto.

## Paso 2 · Un cambio en cada sentido y un conflicto en los dos sentidos

**En el navegador**, antes de correr nada:

1. Crea una nota nueva cualquiera (para comprobar que el móvil la baja).
2. Edita el **título o el texto** de «Nota desde el móvil» (para que, al sincronizar el móvil con
   un cambio local sin haber bajado antes este, salte un conflicto).

**En el móvil:**

```
flutter test integration_test/sync_cross_client_test.dart -d $SERIE \
  --plain-name "paso 2"
```

1. Sincroniza, comprueba que bajó la nota nueva de la web y edita «Nota desde el móvil» **sin
   volver a sincronizar antes** (el cambio de la web de arriba sigue sin bajar en este
   dispositivo).
2. Sincroniza otra vez: debe aparecer un conflicto. La terminal imprime las dos versiones (la de
   este móvil y la de la web).
3. Lo resuelve con `both` (quedan las dos: la de la web sustituye a la original y la del móvil
   pasa a una copia nueva, «… (conflicto)») y sincroniza una última vez.
4. **En el navegador:** recarga la lista de notas. Debes ver **ambas** versiones: la nota original
   (ahora con el texto que tenía en la web) y la copia «… (conflicto)» con el texto que tenía el
   móvil. Edita cualquiera de las dos y confirma que el cambio llega también al móvil si vuelves a
   sincronizar (puedes repetir el paso 2 u otra sincronización suelta para comprobarlo).

Si la terminal dice que no apareció ningún conflicto, es que faltó el paso 2.2 de arriba (editar
la nota en la web **antes** de correr el comando): repite desde ahí.

## Paso 3 · Papelera y borrado en los dos sentidos

```
flutter test integration_test/sync_cross_client_test.dart -d $SERIE \
  --plain-name "paso 3"
```

1. El móvil mueve una nota activa a la papelera y sincroniza. La terminal dice cuál.
2. **En el navegador:** confirma que esa nota aparece en la papelera (no en la lista activa). Desde
   la web, **borra definitivamente otra nota distinta** (una que no sea la que acaba de mover el
   móvil).
3. Vuelve a correr el mismo comando del paso 3 (segunda vez): la segunda sincronización del propio
   paso ya baja ese borrado; confirma en la terminal (sin fallos) y, si quieres verlo explícito,
   añade una comprobación rápida con `adb logcat` o repite el paso con una nota conocida.
4. **En el navegador:** confirma que la papelera del móvil (compruébalo reabriendo la cuenta o
   mirando la base con las herramientas de depuración) coincide con la de la web.

## Qué queda para después de la fase 8

Esta guía demuestra el protocolo y el motor reales, pero sin ninguna pantalla:

- No hay lista de notas, editor, papelera ni diálogo de conflicto táctiles: todo lo de arriba se
  conduce por código. La fase 9 (notas) y la fase 10 (editor) son quienes dan vueltas a esto con
  interfaz de verdad.
- El diálogo de conflicto con sus tres botones (`local`/`remote`/`both`) no existe: aquí se
  resuelve llamando a `SyncEngine.resolveConflict` directamente. La fase 9 lo cablea a un botón.
- Los disparadores (D7: al desbloquear, 3 s tras un cambio, cada 60 s, al recuperar la red) están
  escritos y probados (`app/test/features/sync/state/sync_triggers_test.dart`) pero **nadie los
  arranca todavía**: `SyncController.attach`/`SyncTriggers.start` los tiene que llamar la fase 8,
  justo después de desbloquear (ver `docs/decisions.md`, «Fase 7»). Esta guía sincroniza siempre a
  mano (`engine.syncNow()`), nunca por los disparadores.
- El progreso de la primera descarga (`SyncEngine.onProgress`) no tiene ninguna barra que lo
  muestre: esta cuenta de prueba tiene muy pocas notas para que se note.

## Si algo no sale como se describe

Si un paso no se comporta como dice esta guía (p. ej. no aparece el conflicto esperado, o la web
no ve una nota que el móvil dice haber subido), repasa primero el paso anterior (¿se sincronizó de
verdad? ¿la terminal terminó en verde?). Si el comportamiento sigue sin encajar con lo que
describen los 19 escenarios de `sync-behavior.json` o con el plan §7, anótalo en
`docs/decisions.md` bajo «Fase 7» con lo que pasó de verdad, y si bloquea cerrar la fase, en
`docs/blockers.md` (ver §12 y §0 del plan).
