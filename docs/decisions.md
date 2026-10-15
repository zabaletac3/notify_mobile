# Decisiones

Anotación de cualquier decisión no prevista en el plan (§2) o de las alternativas de la §12 que
se hayan tenido que aplicar. Formato: fecha, fase, decisión, motivo, referencia.

## Fase 0

### 2026-10-10 · appflowy_editor no compila con Flutter 3.47.7

- **Riesgo §12 detectado:** «`appflowy_editor` no compila con el Flutter estable».
- **Síntoma:** al compilar la app de comprobación, el compilador de Dart falla con
  `The non-abstract class 'DeltaTextInputService' is missing implementations for these members:
  TextInputClient.onFocusReceived`. Flutter 3.47 añadió `TextInputClient.onFocusReceived`; el
  mixin `DeltaTextInputClient` de Flutter hace `implements TextInputClient` (no `extends`), así
  que la clase de AppFlowy queda obligada a implementarlo aunque el original tenga valor por
  defecto.
- **Alternativa aplicada (§12):** copiar el paquete a
  `packages/third_party/appflowy_editor` y corregirlo allí. Commit del parche documentado en
  `packages/third_party/appflowy_editor/PATCHES.md`. El códec de Markdown del proyecto no depende
  de AppFlowy, por lo que el parche queda contenido.

### 2026-10-10 · compileSdk de plugins transitivos de appflowy_editor

- **Síntoma:** Gradle falla en `:keyboard_height_plugin:checkDebugAarMetadata` («currently
  compiled against android-31», pero una dependencia androidx exige ≥ 34).
- **Decisión:** en `android/build.gradle.kts` de la app se fuerza `compileSdk = 36` a los
  subproyectos (plugins) con un valor antiguo. No cambia el `compileSdk` propio de la app (que
  sigue siendo el de Flutter estable, D17). Es el ajuste estándar para plugins desactualizados.

## Fase 2

### 2026-10-10 · Base visual reextraída de Penpot (resuelto; D16, manda Penpot)

- **Antes:** durante la fase 2 la pestaña de Penpot del MCP se congeló y los valores salieron de
  `notify_web`; eso **no valía como cierre**. Reanudado el MCP, se reextrajo todo de Penpot.
  Medidas en [`docs/design/penpot-measurements.md`](design/penpot-measurements.md); crudo en
  [`docs/design/penpot-extract.json`](design/penpot-extract.json).
- **Colores:** los 34 tokens de color coinciden **exactamente** con los que había. **Iconos:** Lucide
  con trazo **1,75** (confirmado). Sin cambios en eso.

#### Penpot frente a lo que había (tomado de la web)

| Qué | Antes (web) | Penpot (ahora) |
| --- | --- | --- |
| Título de pantalla | 28/700, int. 34/28 | **24/700**, int. 1.2, `letterSpacing` -0.4 |
| Encabezado | 18/600, int. 24/18 | **18/600**, int. 1.2 |
| Cuerpo | 15/400, int. 22/15 | **15/400**, int. 1.2 |
| Etiqueta | 13/500, int. 18/13 | **13/500**, int. 1.2 |
| Pie/caption | 12/400, int. 16/12 | **12/400**, int. 1.2 |
| Título de nota | (no había rol) | **14/600** (`AxoType.noteTitle`) |
| Radio tarjeta/buscador | (no había) | **28** (`AxoRadii.card`) |
| Casilla OTP | 48×60 | **53×60**, hueco 8 |
| Elemento de menú | 38 alto, relleno 9/12 | **48 alto**, relleno 16, icono 20, label 15/500 |
| Toast (ancho) | 380 | **388** |
| Tarjeta de nota | preview `text.secondary` | preview **`text.tertiary`**; título 14/600; pin `tag.amber` |
| Hoja inferior | asa 32×4 | asa **36×4**; título 17/600 |
| Diálogo | ancho 420/480 | **348** |
| Radios botones | 12 (md) / 14 (lg) | primario/Google **14**; diálogo **12** |
| Colores usados no-token | — | `#b7791f` (resplandor decorativo), `#4285f4` (logo Google) |

Sin diferencias en: los 34 colores de token, el trazo de iconos, y radios que ya coincidían (12 inputs,
20 diálogo, 24 hoja, 10 tarjeta de nota, casilla 20, interruptor 44×26). Los tamaños de botón 46/54 y la
altura de input 52 también coincidían.

> Los **PNG de los 41 tableros** están en [`docs/design/boards/`](design/boards/README.md). El
> `export_shape` del MCP devuelve la imagen al chat (no escribe a disco), así que se generaron pidiendo
> a Penpot el SVG de cada tablero (`generateMarkup`) desde el propio plugin, enviándolo a un servidor
> local y convirtiéndolo a PNG en la máquina.

### 2026-10-10 · Dependencias nuevas de la fase 2 fuera de la §9

- **`flutter_svg`** (`^2.2.0`): renderizar los iconos **Lucide** empaquetados como SVG con trazo 1,75
  (los SVG están en `app/assets/icons/`, con `stroke-width` 1,75). En la web se usa Lucide con trazo 1,75.
- **`intl`** (`^0.20.3`): lo trae `flutter_localizations` y lo usa la localización `es` (ARB).
- `flutter_riverpod` y `go_router` están en la §9 (D9), no requieren nota.

## Fase 3

### 2026-10-10 · Forma de la API de `axonote_crypto` no fijada por el plan

El plan (§10, Fase 3) da la lista de funciones y errores, pero no su firma exacta en Dart. Tres
decisiones de forma, ninguna cambia el formato de bytes (§3) ni los vectores:

- **Argon2id inyectado como parámetro, no como estado global mutable.** La web usa un setter de
  módulo (`setArgon2Impl`) porque JS no tiene un equivalente cómodo a pasar una dependencia por
  todas las funciones. En Dart, `deriveFromPassword` y las funciones de `account_keys.dart` que
  derivan contraseña reciben `Argon2idDeriver` como argumento explícito. Motivo: nada de estado
  global en un paquete puro, y las pruebas pueden usar la implementación real
  (`SodiumArgon2id`) sin tocar un singleton compartido entre archivos de prueba.
- **Los códecs de nota, carpeta y enlace no dependen de un tipo `Vault`.** En la web,
  `note-codec.ts`/`share-codec.ts` reciben un `Vault` que reparte y cachea las claves de cada
  elemento. Ese reparto y esa caché son estado de sesión (dominio/app, no criptografía pura), y
  `axonote_crypto` no depende de `axonote_domain` (regla de la §4.2). Por eso los códecs de este
  paquete son funciones sin estado que ya reciben la `SecretKeyBytes` del elemento
  (`sealNotePayload`/`openNotePayload`, etc.); el equivalente al `Vault` (repartir y cachear esa
  clave a partir de la maestra) se escribe en una fase posterior, fuera de este paquete.
- **`KeyBundle` y `KdfParams` se definen de nuevo dentro de `axonote_crypto`.** Son copias locales
  de los tipos que en la web viven en `domain/crypto.ts`; aquí no pueden importarse de
  `axonote_domain` por la misma regla de dependencias. Mismos campos y mismo nombre.
## Fase 4

### 2026-10-10 · Los errores de aplicación viven en `axonote_domain`

- **Motivo:** el plan §4.3 sitúa `AppError` (sealed) y `AppFailure` en el dominio y la §4.2 da a
  `axonote_api` como única dependencia interna `axonote_domain`. Como el paquete estaba vacío, en
  esta fase se implementaron ahí `AppError` (mismos `kind` que `src/lib/domain/errors.ts`) y
  `AppFailure`. `AppFailure.toString()` solo imprime el `kind`: un registro accidental de la excepción
  no puede filtrar campos ni cuerpos.

### 2026-10-10 · Un cuerpo que no encaja es un fallo `server`, no un `kind` nuevo

- **Motivo:** D13 pide `fromJson` estricto, pero `errors.ts` no tiene un `kind` de formato y la §2 no
  se cambia. Un cuerpo válido a nivel HTTP que no cumple el contrato es un problema del servidor, así
  que el cliente lo convierte en `AppFailure(ServerError())` (sin estado). La excepción de formato
  (`JsonFormatException`) solo lleva la ruta del campo, nunca el valor.

### 2026-10-10 · Paridad exacta con `toFailure`

- **Motivo:** se replica `toFailure` de `http-client.ts` **literal**, incluso donde la web descarta
  códigos: su lista `FORBIDDEN_CODES` solo conserva `email-not-verified`, `google-disabled`,
  `google-email-unverified` y `account-deleted`, así que `limit-reached` y `google-not-linked`
  salen con `code = null`. Se deja un test que fija esa paridad. Si en otra fase hace falta
  distinguir `quota-exceeded`/`limit-reached`, se cambia en la web y aquí a la vez.

### 2026-10-10 · `baseUrl` incluye `/v1`

- **Decisión:** `HttpClientOptions.baseUrl` es el `API_URL` de la §4.5 (p. ej.
  `http://localhost:8080/v1`) sin barra final; las rutas del contrato (`/auth/login`…) se añaden tal
  cual. Se normaliza una barra final sobrante.

### 2026-10-10 · Cabeceras de Cloudflare Access

- **Decisión:** `CF-Access-Client-Id` y `CF-Access-Client-Secret` se añaden a cada petición **solo si**
  están definidas (vacío = no se envían), como pide la §4.5 para los tokens de servicio de QA.

### 2026-10-10 · Renovación: misma política que la web ante fallos transitorios

- **Decisión:** el refresh es de vuelo único y persiste el token nuevo antes de reintentar. Si el
  refresh devuelve `network`, `server` o `rate-limited`, se propaga ese fallo **sin borrar** los
  tokens (la sesión puede seguir viva); con cualquier otro fallo se borran y las peticiones pendientes
  fallan con `session-expired`. `device-revoked` se propaga como fallo propio y limpia la sesión.
  Es lo que hace `http-client.ts`; la interpretación de «si el refresh falla, todas fallan con sesión
  expirada» cubre el caso habitual (token de renovación inválido).

### 2026-10-10 · Dependencias de desarrollo fuera de la §9

- **`test`** y **`yaml`**: solo `dev_dependencies` de `axonote_api` (pruebas y lectura del
  `openapi.yaml` en la prueba de contrato). No son dependencias de ejecución, así que no alteran la
  §9. `dio` sí está en la §9 (D13).

### 2026-10-10 · Pruebas de integración y código de verificación

- **Decisión:** las pruebas de integración se etiquetan `integration` y se saltan por defecto
  (`dart_test.yaml`), de modo que la CI no las ejecuta. El código de verificación se lee de la salida
  del backend (`MAIL_PROVIDER=log` lo imprime en texto legible), cuya ruta llega en
  `AXONOTE_MAIL_LOG`; la URL de la API, en `AXONOTE_API_URL`. El runbook está en el encabezado de
  `packages/axonote_api/test/integration/auth_sync_integration_test.dart`.

### 2026-10-10 · Formato: se sigue la lista de la CI, sin tocar `third_party`

- **Motivo:** `dart format .` reformatearía el paquete vendorizado `packages/third_party/appflowy_editor`
  (la fase 0 lo copió sin pasar el formateador), y no se puede tocar. La puerta de formato se aplica,
  como en la CI, a los directorios propios (`app/lib`, `app/test`, `tool` y `packages/*/lib` y, aquí,
  también `packages/axonote_api/test`). `flutter analyze` sí analiza todo el workspace.

### 2026-10-10 · El vuelo único de la renovación es por instancia

- **Decisión:** el `HttpClient` serializa la renovación dentro de la propia instancia. La app debe
  crear **un solo `HttpClient` por cuenta** y compartirlo entre todos los clientes de recurso.
- **Motivo:** dos instancias mantendrían cada una su `_refreshing`; ambas podrían gastar a la vez el
  mismo token de renovación (que es de un solo uso) y el servidor cerraría la sesión por reutilización.
  En la web lo resuelve el cerrojo entre pestañas (`navigator.locks`); aquí, al ser un solo proceso,
  basta con no duplicar la instancia.

### 2026-10-10 · Cuerpo no interpretable y cancelación al vencer el tiempo máximo

- **Cuerpo:** el cliente lee el cuerpo en crudo (`ResponseType.plain`) y lo interpreta él mismo. Un 2xx
  cuyo cuerpo no es JSON (p. ej. el HTML de Cloudflare Access), está vacío o no encaja con el DTO (falla
  el `decode` por defecto o cualquier cast) es un `AppFailure(ServerError())`, nunca un `TypeError`
  suelto ni un `network`. Con **estado de error**, manda el estado HTTP (como la web): un cuerpo no JSON
  con 500 es `server` y con 429 es `rate-limited`.
- **Cancelación:** al vencer el tiempo máximo se cancela el `CancelToken` de dio, no solo se abandona la
  `Future`, para liberar la conexión. Cubierto con un test que comprueba que dio cancela.



## Fase 5

### 2026-10-10 · `storeMasterKey` gana un `prompt` opcional (desvío de la firma literal del plan)

- **Lo que dice el plan (§5.2):** `storeMasterKey(userId, bytes, requireAuth)`, sin texto de
  cuadro; solo `loadMasterKey(userId, prompt)` lo lleva.
- **Por qué no basta tal cual:** en Android, una clave de Keystore con `setUserAuthenticationRequired(true)`
  exige autenticación para **cualquier** uso del `Cipher`, también para cifrar (no solo para
  descifrar). Guardar la clave maestra con `requireAuth: true` —activar el desbloqueo
  biométrico— necesita entonces un `BiometricPrompt` igual que cargarla, con su propio texto
  (patrón estándar de Android: "confirma tu huella para activar el desbloqueo biométrico").
- **Decisión:** `storeMasterKey` acepta un `prompt` opcional (con un valor por defecto si no se
  pasa) y solo lo usa cuando `requireAuth: true`; con `requireAuth: false` cifra sin pedir nada,
  como antes. No cambia el formato guardado ni el resto de la firma.

### 2026-10-10 · `axonote_platform` añade `setSecure` y `copySensitive` más allá de la lista del §5.2

El §5.2 lista `storeMasterKey`, `loadMasterKey`, `deleteMasterKey` y `authAvailability`, pero el
§5.4 («Endurecimiento de plataforma») solo se puede cumplir con código nativo:
`FLAG_SECURE` (`setSecure`) y marcar el portapapeles como sensible (`copySensitive`,
`ClipDescription.EXTRA_IS_SENSITIVE`, API ≥ 33). Como A8 dice que todo el código nativo propio
vive en este único módulo, ambos métodos se añadieron aquí en vez de crear un segundo canal.

### 2026-10-10 · Dependencia nativa nueva: `androidx.biometric:biometric:1.1.0`

No está en la tabla de dependencias del §9 (esa tabla es de paquetes Dart/`pub`). Es la única
forma de usar `BiometricPrompt` con `CryptoObject` y `Authenticators.BIOMETRIC_STRONG |
DEVICE_CREDENTIAL` sin escribir el diálogo de biometría a mano. Versión 1.1.0 (estable, no una
`alpha`): ya incluye el soporte de `DEVICE_CREDENTIAL` que pide el plan para API ≥ 30.

### 2026-10-10 · `MainActivity` pasa de `FlutterActivity` a `FlutterFragmentActivity`

`BiometricPrompt` exige una `FragmentActivity` (la `Activity` por defecto de Flutter no lo es).
Es el cambio estándar que documentan los plugins de biometría de Flutter para este caso exacto.
No afecta a nada de lo que ya había en `MainActivity` (seguía vacía).

### 2026-10-10 · `createAccountKeys` gana un parámetro `deriveRecovery` solo para pruebas

- **Pendiente de la fase 3:** `account_keys.dart:132` (el `catch` que borra `masterKey` si algo
  falla después de generarla) no tenía ninguna prueba que lo ejecutara de verdad: `Argon2id` es lo
  único inyectable en `createAccountKeys` y su única llamada ocurre *antes* de generar la clave
  maestra, así que forzarle un fallo nunca llega a ese `catch`.
- **Decisión:** `createAccountKeys` acepta `deriveRecovery` (por defecto, la función real
  `deriveFromRecoveryKey`), que se llama justo después de generar la clave maestra. Una prueba
  puede pasar una versión que falle a propósito para ejercitar el `catch` sin tocar
  `deriveFromRecoveryKey` real (que nunca falla con bytes válidos) ni debilitar nada. Ver
  `packages/axonote_crypto/test/account_keys_test.dart`.

### 2026-10-10 · Dónde vive el `Vault` (equivalente a `data/crypto/vault.ts`)

La fase 3 ya había anotado que el reparto y caché de claves de elemento «se escribe en una fase
posterior, fuera de» `axonote_crypto`, por la regla de dependencias del §4.2 (`axonote_crypto` no
puede depender de `axonote_domain` ni de `flutter`). Esta fase lo escribe en
`app/lib/data/crypto/vault.dart`: mismo comportamiento que la referencia web, mismo AAD, con
`SecretKeyBytes` en vez de `CryptoKey`. `Vault.localDbKey()` añade la derivación de A1/A2
(`axonote_crypto.deriveLocalDbKey`, función pública nueva en ese paquete) para que, con el cofre
bloqueado, nadie pueda obtener la clave de la base (lanza `VaultLockedError`).

### 2026-10-10 · `VaultLockedError` es local a `app/lib/data/crypto/vault.dart`, no un `AppError`

El §4.3 del plan describe un `AppError` `sealed` compartido (mismos `kind` que
`src/lib/domain/errors.ts`), pero ese tipo todavía no existe en `axonote_domain` (ninguna fase
anterior lo ha necesitado). Crear ahora esa jerarquía completa de errores de dominio para un solo
caso de uso se salía del alcance de esta fase. `Vault` lanza su propia excepción local
(`VaultLockedError`); cuando `axonote_domain` tenga `AppError`/`fail.locked()` (previsiblemente
fase 6 u 8, que sí reparten entidades por repositorios), ese código deberá traducir
`VaultLockedError` al `kind` que corresponda.

### 2026-10-10 · `FLAG_SECURE` por defecto no se activa todavía de forma global

El §5.4 dice que, según el ajuste de privacidad (activado por defecto), se oculta la vista previa
en recientes «en el resto» de pantallas, y que en pantallas concretas (clave de recuperación,
códigos de respaldo, secreto TOTP, desbloqueo) va **siempre**. Ninguna de esas pantallas existe
todavía (llegan en las fases 8, 9 y 10) y el ajuste de privacidad en sí es de la fase 11
(«Ajustes»). Esta fase deja listo y probado el mecanismo (`AxonotePlatform.setSecure`), pero no
lo activa por defecto en `main.dart`: hacerlo ahora, sin una pantalla de ajustes que lo pueda
desactivar, bloquearía capturas de pantalla en todo el dispositivo (incluidas las que necesiten
las fases siguientes para documentar su trabajo) sin forma de revertirlo. Queda anotado aquí para
que las fases 8-11 lo activen donde corresponda.

### 2026-10-10 · El tiempo de bloqueo no sobrevive a que el sistema mate el proceso

El plan (§5.3, última viñeta) pide medir el tiempo de bloqueo "con la hora de la última actividad
guardada si el sistema mató el proceso". `VaultLockController._lastActiveAt` solo vive en memoria
mientras el proceso sigue vivo: no se persiste en `flutter_secure_storage` ni se lee al arrancar.
Falta además decidir, en el arranque, **con qué cuenta** intentar `unlockWithStoredKey` (lo sabe
`AccountSecureStore.readUserId()`, ya escrito, pero nadie lo llama todavía): ese cableado de
arranque en frío depende de la navegación real de inicio de sesión, que es de la fase 8. Queda
pendiente para cuando se escriba el arranque completo de la app.

### 2026-10-10 · Revisión de código: correcciones a `MasterKeyStore`, al gestor de bloqueo y al
almacén seguro

Una revisión de la fase (leyendo el código, sin ejecutar nada) encontró un fallo real y uno de
política; se corrigen aquí.

**A. `storeMasterKey` no era atómico (fallo real).** Antes, `prepareEncryptCipher` borraba la
clave de Keystore anterior y generaba la nueva **antes** de autenticar: si la persona cancelaba el
cuadro de biometría (o `persistEncrypted` fallaba por cualquier motivo), quedaba el texto cifrado
viejo en `prefs` apuntando a una clave de Keystore que ya no existía — `hasStoredKey` seguía dando
`true`, pero `loadMasterKey` acababa en un `AEADBadTagException` envuelto en `platform_failure`
para siempre, en vez de `no_stored_key`. **Se eligió guardar bajo un alias "candidato" (doble
búfer `a`/`b` por cuenta) y conservar la versión anterior intacta** si algo falla antes de
`persistEncrypted`: no se perdía nada que ya funcionara. Las escrituras de `prefs` que fijan o
borran el estado activo usan `commit()`, no `apply()` (no pueden quedar a medias). Prueba
instrumentada añadida: "cancelar al re-guardar conserva la clave anterior intacta" (paso a paso 4
de `docs/guides/fase5-pruebas-manuales.md`).

**B. La regla de recordar vivía en quien llamaba, no en el controlador (fallo de política).**
`VaultLockController.unlock` aceptaba un `remember: bool` y, si era `true`, guardaba siempre con
`requireAuth: settings.biometricLock` — con `biometricLock: false` guardaba **sin** autenticación
aunque `lockOnExit` o `lockTimeout` estuvieran activos, así que `unlockWithStoredKey` la devolvía
tras un bloqueo sin pedir nada: el bloqueo no protegía nada en ese caso. La regla del plan §5.3
ahora vive en el controlador (`_rememberPolicy`, privada): `biometricLock: true` → `requireAuth:
true`; `biometricLock: false` y además `lockOnExit: false` y `lockTimeout: never` → `requireAuth:
false`; cualquier otro caso → no se guarda nada. `unlock` cambia `remember: bool` por
`rememberOnThisDevice: bool` (`true` por defecto), que solo puede **restringir** (nunca forzar a
guardar si la regla diría que no). `updateSettings` pasa a ser `async` y reaplica la regla con el
cofre ya desbloqueado: si falla a medio camino (p. ej. se cancela la biometría al confirmar el
`requireAuth` nuevo), borra explícitamente lo guardado (coherencia: nada, nunca lo viejo con una
regla ya abandonada) y relanza el error.

**C. `loadMasterKey` no distinguía "irrecuperable" de "fallo genérico".** Si `keyStore.getKey`
devolvía `null` o lanzaba `UnrecoverableKeyException`/`InvalidKeyException` (algunos fabricantes
señalan así la invalidación), o si `decrypt` daba `AEADBadTagException`, antes se perdía todo como
`platform_failure`, en vez de tratarse igual que una biometría nueva (`key_invalidated`: borrar y
pedir la contraseña, el criterio correcto porque esos datos ya son irrecuperables). Ahora
`MasterKeyStore` lanza una única `MasterKeyInvalidatedException` en los tres casos (más el ya
existente `KeyPermanentlyInvalidatedException`) y la capa del plugin borra y devuelve
`key_invalidated` siempre igual.

**D. API 26-29 sin biometría registrada daba `platform_failure` en vez de `auth_not_enrolled`.**
`generateKey` con `requireAuth` en un dispositivo sin biometría ni credencial configurada lanza
`InvalidAlgorithmParameterException`; el reintento sin StrongBox atrapaba **cualquier** excepción
y la disfrazaba. Ahora el reintento sin StrongBox solo se dispara ante
`StrongBoxUnavailableException`; `InvalidAlgorithmParameterException` (con o sin StrongBox) se
convierte en `AuthNotEnrolledException`, mapeada a `auth_not_enrolled`. **No se pudo probar en el
ZTE** (Android 13 / API 33): este camino solo existe en API 26-29, que el dispositivo de
referencia no cubre. Queda verificado por lectura de la documentación de Android, no por una
prueba instrumentada real; si alguna fase posterior tiene acceso a un dispositivo API 26-29, vale
la pena confirmarlo allí.

**E. Higiene de la clave en Kotlin.** `storeMasterKey` ahora pone a cero (`fill(0)`) el `ByteArray`
recibido en todos los caminos (éxito, cancelación, cualquier excepción). Se documentó en
`axonote_platform.dart` que esa copia es la nativa (el método channel ya copia al cruzar): el
`Uint8List` original del lado Dart no se ve afectado, y sigue siendo responsabilidad de quien lo
posee (el `SecretKeyBytes` del `Vault`, que se borra al bloquear). Los bytes que devuelve
`loadMasterKey` **no** se ponen a cero en Kotlin (tienen que llegar intactos a Dart, que los
envuelve de inmediato en un `SecretKeyBytes`). `MethodChannelAxonotePlatform` ya no conservaba
ninguna referencia a los bytes más allá de la llamada ni los incluía en ningún error (solo revisado
y confirmado, sin cambios).

**F. `signOut` dependía de `_vault?.userId`.** Tras un arranque en frío con la app bloqueada
(`_vault == null`, nunca se llegó a desbloquear en este proceso), no habría borrado la clave
guardada de esa cuenta. `signOut` pasa a exigir `required String userId` explícito.

**G. `Vault.newItemKey`/`itemKey`/`rotateItemKey` documentados: la clave devuelta es la misma
instancia de la caché.** Quien la recibe no debe llamar a `dispose()` sobre ella (lo hace `lock()`
al bloquear). Prueba añadida que comprueba, con `identical()`, que `newItemKey().key` y la
instancia que luego devuelve `itemKey()` son el mismo objeto.

**H. `AndroidOptions(encryptedSharedPreferences: true)` no existe en `flutter_secure_storage`
11.2.0.** Comprobado leyendo el código fuente publicado del paquete (no estaba en el `pub-cache`
local: nunca se corrió `pub get` en ningún worktree con esta dependencia). Ese parámetro se quitó
en la v11: desde entonces el paquete siempre cifra con una clave de Keystore, con o sin ese
nombre. Se usa `AndroidOptions()` (valores por defecto), que ya cumple lo que pedía el plan
(Keystore, sin autenticación) sin ningún parámetro extra.

### 2026-10-11 · Registrar una huella nueva NO invalida la clave maestra (enmienda al plan §5.2)

- **Comprobación manual que lo encontró:** 2026-10-10, **TECNO CM6** (Android 16, API 36), guía
  `docs/guides/fase5-pruebas-manuales.md` paso a paso 3. Tras guardar la clave con `requireAuth:
  true` y registrar una huella nueva en Ajustes del sistema, `loadMasterKey` siguió devolviendo
  los bytes guardados en vez de lanzar `KeyInvalidated`: la clave de Keystore no se invalidó.
- **Causa técnica:** `MasterKeyStore.generateKey` pide, con `requireAuth` y API ≥ 30,
  `AUTH_BIOMETRIC_STRONG or AUTH_DEVICE_CREDENTIAL` a la vez (`setUserAuthenticationParameters`).
  Android ata esas claves combinadas al **SID raíz de la credencial del dispositivo**, no solo al
  SID biométrico; `setInvalidatedByBiometricEnrollment(true)` únicamente invalida claves
  **exclusivamente biométricas**, así que no tiene efecto aquí. El plan §5.2 pedía ambas cosas —
  biometría o credencial, y además invalidación por huella nueva — y son incompatibles con la API
  de Android tal y como existe: no hay forma de pedir "biometría o PIN" en una clave y que además
  una huella nueva (sin tocar el PIN) la invalide.
- **Decisión (opción A, de las alternativas que se valoraron):** se mantiene «biometría o
  credencial del dispositivo» tal cual, y se acepta que una huella nueva **no** invalida la clave
  guardada. Razones: (1) para registrar una huella hay que conocer antes el PIN/patrón/contraseña
  del dispositivo, y ese PIN ya abre la clave igual (combinado), así que la huella nueva no abre
  ninguna puerta que el PIN no abriera ya; (2) así sigue funcionando en teléfonos sin sensor de
  huella (el ZTE de referencia, que solo tiene PIN/patrón).
- **Qué SÍ sigue invalidando la clave (camino `key_invalidated` intacto, sin cambios de código):**
  quitar o cambiar el bloqueo de pantalla seguro del dispositivo (desactivar el PIN/patrón, o
  cambiarlo por «ninguno») invalida **todas** las claves de Keystore ligadas a autenticación, con o
  sin biometría — eso Android lo hace incondicionalmente, ligado al SID raíz. También sigue
  invalidando `KeyPermanentlyInvalidatedException` por cualquier otra causa que la lance, y los
  casos ya cubiertos en la revisión de código anterior (entrada de Keystore irrecuperable, texto
  cifrado que no corresponde a la clave). En todos esos casos se borra y se pide la contraseña,
  sin cambios.
- **Diferencia conocida entre niveles de API (sin cambiar nada, solo para que no se pierda):** en
  API 26-29 (`MasterKeyStore.kt`, rama `setUserAuthenticationValidityDurationSeconds(-1)`) la clave
  no pide `setUserAuthenticationParameters` con autenticadores combinados, así que sigue siendo
  **puramente biométrica**; ahí `setInvalidatedByBiometricEnrollment(true)` sí surte efecto y una
  huella nueva sí invalida la clave. No hay contradicción con el cuadro de biometría: en esa misma
  rama, `BiometricGate.authenticate` (`allowDeviceCredential = SDK_INT >= R`) tampoco ofrece la
  credencial del dispositivo como alternativa, solo biometría — cuadro y clave piden lo mismo. No
  se pudo verificar en un dispositivo real API 26-29 (ni el TECNO CM6 ni el ZTE llegan a esa
  franja); queda como lectura de la documentación de Android, igual que el hallazgo D de la
  revisión de código anterior.
- **`docs/plan.md` §5.2 y el «Hecho cuando» de la Fase 5** se corrigen como enmienda, con remisión
  a esta decisión.

**Pendiente para la fase 8** (aceptado como fuera de alcance de esta fase; que no se pierda):

- El arranque en frío: decidir con qué cuenta intentar `unlockWithStoredKey` (ya existe
  `AccountSecureStore.readUserId()`), y persistir `lastActiveAt` para que el tiempo de bloqueo
  sobreviva a que el sistema mate el proceso (ver la decisión de más arriba).
- Activar `AxonotePlatform.setSecure` por defecto (ajuste de privacidad) y en las pantallas
  concretas que el plan marca como "siempre" (clave de recuperación, códigos de respaldo, secreto
  TOTP, desbloqueo) — mecanismo ya listo y probado, solo falta activarlo donde corresponda.
- `unlock` con `biometricLock: true` muestra el cuadro de biometría en cada desbloqueo por
  contraseña, porque siempre vuelve a guardar la clave maestra con `_applyRememberPolicy` tras
  obtenerla (el plan no distingue este caso). La fase 8, que es quien construye la pantalla de
  desbloqueo por contraseña, debe decidir si conviene omitir el re-guardado cuando ya hay una
  clave guardada para esa cuenta con la misma política (mismo `requireAuth`): ahorraría ese cuadro
  de biometría redundante, a costa de tener que comparar el estado guardado antes de decidir. No
  se cambia en esta fase.
- Verificar en el ZTE (sin sensor de huella) el desbloqueo con PIN/patrón del dispositivo: la
  decisión de 2026-10-11 de más arriba depende de que la credencial del dispositivo funcione como
  alternativa real en un teléfono sin biometría, y esa fase es quien construye la pantalla donde se
  podría comprobar de punta a punta.


## Fase 6

### 2026-10-11 · drift sin generación de código (SQL explícito), no `build_runner`

- **Decisión:** `AppDatabase` extiende `GeneratedDatabase` (drift) con `allTables` vacío y todo el
  esquema en SQL explícito (`app/lib/data/local/schema.dart`, `schemaV1`), en vez de tablas
  generadas por `drift_dev`.
- **Motivo:** la §6 exige un esquema exacto (columnas, FTS5 de contenido externo con disparadores,
  índices) y migraciones versionadas explícitas. El SQL directo lo fija al detalle, evita la
  dependencia `build_runner`/`drift_dev` y el archivo generado en el repo, y mantiene `drift`
  dentro de `app/lib/data` (lo verifica `tool/check_imports.dart`). Las consultas reactivas se
  hacen con `customSelect` + `tableUpdates`.

### 2026-10-11 · La base local guarda el contenido en claro (dentro de la base cifrada)

- **Decisión (aplica D3):** las columnas `notes(title, content, preview, tags_json)` y
  `folders(name)` van en claro; la base entera está cifrada por SQLite3MultipleCiphers. La clave
  del elemento (`wrapped_key`, A5) se guarda para reutilizarla; no se guarda el `payload` cifrado
  salvo en las filas ilegibles (`raw_payload`, A6). Al subir (fase 7), el `payload` se cifra desde
  la fila actual.
- **Consecuencia frente a la web:** `LocalCodec` no cachea descifrados (no hacen falta) y el
  `SyncStore` descifra un cambio remoto antes de escribir la fila. El códec sí sabe cifrar desde la
  fila (`sealNoteForUpload`/`sealFolderForUpload`) y devolver el `raw_payload` de las ilegibles.

### 2026-10-11 · Columna de etiquetas de FTS y `foldText`

- La FTS5 es de **contenido externo** sobre `notes`; sus columnas se llaman como las de `notes`,
  así que la de etiquetas es `tags_json` (la §6 dice `tags`, es la misma columna). El tokenizador
  `unicode61 remove_diacritics 2` cubre la insensibilidad a tildes (A7).
- `foldText` del dominio se implementa con una tabla de diacríticos latinos: `axonote_domain` es
  Dart puro **sin dependencias** (no puede usar `unorm_dart` ni `\p{Diacritic}`, que Dart no
  soporta). La búsqueda real de la app usa FTS5, no `foldText`.

### 2026-10-11 · Índice añadido para la lista ordenada por `updated_at` (desvío de la §6)

- **Motivo:** con 10 000 notas, la lista de la página inicial (200) superaba los 50 ms del
  presupuesto (§11) porque el índice de la §6 `notes(deleted_at, pinned, updated_at)` no sirve para
  `WHERE deleted_at IS NULL ORDER BY updated_at DESC` (tiene `pinned` en medio). Se añadió
  `CREATE INDEX notes_deleted_updated ON notes(deleted_at, updated_at)` en la versión 1.
- **Medición:** en el ZTE, la página inicial de 10 000 notas pasó de 74 ms a 4 ms. Ver
  `docs/benchmarks.md`. La lista completa (sin límite) tarda ~270 ms y se mide pero no se afirma.

### 2026-10-11 · La lista inicial es una página (`NoteQuery.limit`/`offset`)

- **Decisión:** `NoteQuery` gana `limit`/`offset`; el filtro, el orden y la página se resuelven en
  SQL y la lista devuelve **resúmenes sin `content`** (la §4.4 pide consultas ligeras). `get(id)`
  sigue devolviendo la nota completa. La interfaz (fase 9) pedirá la primera página y cargará más
  al desplazar; la prueba de rendimiento mide esa primera página.
- **Consecuencia:** quien lea `content` de un resultado de `list()` obtendrá `''`; para editar hay
  que usar `get`.

### 2026-10-11 · Tipos del protocolo de sincronización duplicados en el dominio

- `axonote_domain` define los tipos cifrados (`EncryptedNote`, `OutboxEntry`, `AppliedChange`,
  `RemoteChange`, `ConflictReport`, `SyncEntity`, `SyncOp`) que necesita la interfaz `SyncStore`.
  `axonote_api` ya tenía sus DTO (`EncryptedNoteDto`, `SyncEntity`…) de la fase 4, que **no se
  tocan**; la fase 7 (motor) mapeará DTO ↔ dominio. Es una duplicación deliberada para respetar
  las reglas de dependencia (§4.2: `axonote_domain` no puede depender de `axonote_api`).

### 2026-10-11 · Herramientas de prueba y formato

- **`app/test_driver/integration_test.dart`**: necesario para correr la prueba de rendimiento en
  **perfil** (`flutter drive --profile`), que es la condición del presupuesto §11. Los directorios
  `app/integration_test` y `app/test_driver` se añaden a la lista de formato de la CI (`.github/
  workflows/ci.yml`), que antes no los revisaba.
- **`app/test/flutter_test_config.dart`**: silencia el aviso de drift por abrir varias bases en
  memoria a la vez en las pruebas (no es un problema real).
- **Divergencia aceptada (A3):** con la app bloqueada no hay base abierta ni sincronización; no se
  porta la prueba de la web que sincroniza bloqueada (allí guarda cifrado y aquí no).

### 2026-10-11 · Revisión de la fase 6

- **Cifrado verificado al abrir (fail-closed).** `AppDatabase.openEncrypted` comprueba en el
  `setup` que `PRAGMA cipher` devuelva un nombre no vacío; si no, lanza y **no abre** la base. Sin
  esa comprobación, un build que enlazara un `sqlite3` sin cifrado ignoraría `PRAGMA key` en
  silencio y la base quedaría en claro. Además, `LocalDatabase.open` hace una lectura de prueba
  (`SELECT count(*) FROM sqlite_master`) para que una clave incorrecta falle **al abrir** con un
  `AppFailure(decrypt)` tipado, no en la primera consulta de un repositorio.
- **La clave de la base se borra en cuanto la base está abierta** (`key.dispose()` en el `finally`
  de `LocalDatabase.open`, también en el camino de error). La representación que usa el `PRAGMA`
  es una **cadena hexadecimal** que no se puede poner a cero en Dart (los `String` son inmutables)
  y que viaja a la clausura `setup` del isolate de drift (que no comparte memoria con el isolate
  principal). Queda como limitación aceptada; el `SecretKeyBytes` sí se borra.
- **`deviceName` en `LocalDeps`.** El nombre para mostrar en los conflictos es el **nombre** del
  dispositivo, no su identificador (`deviceId`), como en la web (`device.name`). `LocalDatabase.open`
  lo acepta; si no se pasa, se usa el `deviceId`.
- **`applyResult` descifra los cambios remotos antes de la transacción.** Con páginas de 500
  elementos, descifrar dentro de la transacción mantenía el bloqueo de escritura durante todo el
  descifrado. Ahora se descifran las filas remotas antes de abrir la transacción (seguimos dentro
  del Mutex, así que nada local cambia entre medias) y la transacción solo lee y escribe. Si el
  cofre se bloquea a mitad del descifrado, no se aplica nada.
- **WAL siempre** (`PRAGMA journal_mode = WAL` en `beforeOpen`, también al crear la base). Antes solo
  se activaba al reabrir; en memoria es inocuo (responde `memory`).
- **Fila ilegible sin `raw_payload`.** `sealNoteForUpload`/`sealFolderForUpload` lanzaban un payload
  vacío (`rawPayload ?? ''`), lo que pisaría el dato en el servidor. Ahora es un `StateError`.
- **Prueba de rendimiento con la base cifrada real** (archivo en el directorio de la app, clave del
  Vault), en frío y en caliente, junto con una prueba de cifrado **en dispositivo** (ZTE). Ver
  `docs/benchmarks.md`.

## Fase 7

### 2026-10-11 · El `SyncStore` de la fase 6 basta sin ampliarlo

- **Lo que anticipaba el plan:** el ALCANCE de la fase decía que, si `SyncStore` no bastaba para
  leer «la fila actual a cifrar», había que ampliarlo.
- **Por qué no hizo falta:** esa lectura la hace `ItemCodec` (interfaz nueva del motor), no
  `SyncStore`. `ItemCodec.sealNote(id)`/`sealFolder(id)` solo reciben el `Id`; quien los implementa
  (`LocalItemCodec`, en `app/lib/data`) es quien lee la fila de drift y le pide a `LocalCodec` que
  la cifre. El motor nunca ve la fila, así que `SyncStore` no necesita un método para dársela.
  `applyResult` ya recibía exactamente los campos que necesita (`sent`, `applied`, `conflicts`,
  `remoteChanges`, `cursor`, `now`); no se le añadió nada.

### 2026-10-11 · `OutboxEntry` es el tipo de «cambio a enviar»; no hay un `SyncChange` nuevo

- **Decisión:** `SyncRequest.changes` (en `axonote_sync`) es `List<OutboxEntry>`. El motor toma lo
  que da `SyncStore.pending()` y, para cada `upsert`, construye una copia con `noteData`/
  `folderData` ya rellenos (los demás campos — `seq`, `version`, `changedAt` — no salen a la red,
  pero reutilizar el tipo evita duplicar uno nuevo solo para esto).
- **Motivo:** `axonote_domain` (fase 6) ya define `OutboxEntry` con `noteData`/`folderData`
  opcionales pensados exactamente para esto (A4: la cola guarda referencias; el cifrado se añade
  al enviar). Duplicar un `SyncChange` habría sido la misma forma con otro nombre.

### 2026-10-11 · El motor hace un solo intento; los reintentos son política de `app`, no del motor

- **Lo que dice el plan §7:** «reintentos con espera exponencial (2 s → 60 s) ante `network` y
  `server`; `rate-limited` respeta `retryAfterSec`».
- **Dónde se puso:** en `app/lib/features/sync/state` (que todavía no implementa el backoff en sí:
  solo expone `lastError`/`phase` para que quien reintente decida), no en `SyncEngine.syncNow()`.
- **Motivo:** la referencia web (`LocalSyncRepository.syncNow()` y `SyncState.syncNow()`) tampoco
  reintenta sola: un intento, y si falla, se registra el error y se calla. Un reintento con espera
  *dentro* de `syncNow()` habría dejado la llamada colgada minutos si la red no vuelve, sin forma
  de cancelarla desde fuera; y el ALCANCE de la fase pide explícitamente que el motor no use
  `Timer` ni `DateTime.now()` directos, lo que ya apunta a que esa política (que necesita
  temporizadores) vive fuera. `SyncController` (el envoltorio de app sobre `SyncEngine`, con el
  mismo papel que `SyncState` en la web) traduce cada `AppError` en `phase`/`lastError`:
  `session-expired`/`device-revoked` no quedan como aviso persistente (disparan
  `onSessionExpired`/`onDeviceRevoked`, que la fase 8 debe conectar a cerrar sesión y a borrar la
  copia local); `locked` tampoco (A3: se descarta en silencio); el resto sí.
- **El backoff en sí, implementado (revisión de código, ver más abajo):** `SyncTriggers` mira
  `SyncController.state.lastError` tras cada intento y aplica la política completa — espera
  exponencial 2 s → 60 s ante `network`/`server`, supresión hasta `retryAfterSec` ante
  `rate-limited`, sin bucle propio ante `forbidden` — con `TimerFactory`, igual que el resto de
  temporizadores de la app.

### 2026-10-11 · Isolate de trabajo para el descifrado por lotes de la primera descarga

- **Lo que pide el plan §4.4:** «descifrado por lotes (primera sincronización, páginas de 500): en
  un isolate de trabajo de larga vida, por páginas, con inserción por lotes en una transacción por
  página».
- **Primer intento: confiar en que no hacía falta (revisado y descartado).** La primera versión de
  esta fase razonó que `cryptography_flutter` (D12) ya saca el AES-GCM del isolate de Dart, así que
  lo que queda en el isolate principal sería barato (JSON y relleno). Esa premisa era **falsa**:
  revisando `packages/axonote_crypto/pubspec.yaml`, el paquete solo depende de
  `package:cryptography` — `cryptography_flutter` nunca llegó a integrarse en ninguna fase — así
  que el AES-GCM es software puro y corre, de verdad, en el isolate que lo llama. Medido en el ZTE
  `LZ0V50COPBC002769` con `sync_first_download_performance_test.dart` (2 000 notas, páginas de
  500): tiempo total bien (5,1 s / 4,7 s, presupuesto §11 de 15 s), pero bloqueo máximo del isolate
  principal de **561 ms / 548 ms** por página — muy por encima del umbral de 100 ms de la prueba.
  Por el criterio de cierre ya documentado aquí mismo, la fase no podía cerrarse así.
- **Dónde estaba el bloqueo de verdad (no se dio por supuesto, se razonó antes de montar nada):**
  por elemento, cada página hace dos operaciones AES-GCM software (desenvolver la clave del
  elemento con la maestra, y abrir su payload) más JSON/relleno y construir la fila — todo código
  Dart síncrono. El paso de mensajes entre isolates de 500 filas no es el problema (es barato,
  bytes y estructuras simples); es el propio descifrado repetido 500 veces lo que bloquea.
- **Implementado:** `app/lib/data/local/remote_decrypt_worker.dart` (`decryptRemoteChangesInWorker`)
  descifra con `Isolate.run` — sin `BackgroundIsolateBinaryMessenger` ni nada específico de
  Flutter: el AES-GCM software de `package:cryptography` no usa canales de plataforma, así que un
  isolate de Dart corriente basta. Solo cruzan la frontera el `userId` y una **copia** de los
  bytes de la clave maestra (`Uint8List.fromList(vault.requireKey().bytes)`, nunca el `Vault` ni
  su caché de claves de elemento); el isolate reconstruye su propia `SecretKeyBytes`, descifra
  cada `EncryptedNote`/`EncryptedFolder` (misma lógica que `LocalCodec.openNote`/`openFolder` +
  `noteRow`/`folderRow` para el caso remoto, comprobado igual en
  `remote_decrypt_worker_test.dart`), y la pone a cero (`SecretKeyBytes.dispose()`) antes de
  devolver el resultado; quien llama (`LocalSyncStore.applyResult`) pone a cero su propia copia en
  un `finally` en cuanto la llamada vuelve. El resultado (`RemoteDecryptBatch`: mapas de
  `NoteRow`/`FolderRow` ya en claro, por id) vuelve al isolate principal y `applyResult` sigue
  aplicándolo en una sola transacción, exactamente igual que antes.
- **Solo para páginas grandes (`remoteDecryptIsolateThreshold = 50`), documentado aquí:** levantar
  un isolate cuesta (arrancar su VM, copiar los datos); por debajo del umbral —una sincronización
  incremental normal, unos pocos cambios— ese coste supera lo que ahorraría, así que
  `applyResult` sigue descifrando en línea con `LocalCodec` como antes. Por encima (típicamente
  solo la primera descarga de la cuenta), pasa por el isolate. El umbral vive en
  `remote_decrypt_worker.dart`, no en `LocalSyncStore`, para que quien lo cambie vea junto el
  motivo.
- **`SyncEngine.onProgress` (`SyncProgress`), sin cambios respecto al primer intento:** se sigue
  llamando tras aplicar cada página con el número de página, si el cursor era `null` al empezar y
  el total de `remoteChanges` aplicados hasta ahora, para que la interfaz pueda mostrar
  «descargando… (1500)» en vez de parecer colgada (la fase 8/9, que construye la pantalla, es
  quien debe pintarlo).
- **Medido, no solo supuesto:** `sync_first_download_performance_test.dart` sigue siendo la misma
  prueba (2 000 notas remotas cifradas de verdad, páginas de 500, en la base cifrada real del ZTE,
  `flutter drive --profile`), con el mismo umbral de 100 ms **sin subir**: ahora ejercita el
  isolate de trabajo de verdad (páginas de 500 > 50), así que si vuelve a fallar significa que el
  isolate no basta y hay que repartir también la construcción de filas o trocear el paso de
  mensajes — no hay una alternativa menor que probar antes. Pendiente: no se ha vuelto a ejecutar
  tras este cambio (anotar los números nuevos en `docs/benchmarks.md` al correrla).

### 2026-10-11 · Ajustes `autoSync`/`wifiOnly` en la tabla `meta`, sin pantalla todavía

- **Decisión:** `SyncSettings` (`autoSync: true`, `wifiOnly: false` por defecto, igual que
  `DEFAULT_SETTINGS` de la web) se lee y escribe con `SyncStore.readMeta`/`writeMeta` (la tabla
  `meta` ya estaba pensada para «ajustes en caché», plan §6). No hay pantalla de ajustes todavía
  (llega en la fase 11): cuando la haya, solo tiene que llamar a `writeSyncSettings` desde su
  interruptor; no hace falta otro almacén ni migrar nada.

### 2026-10-11 · `ConnectivityProbe`: envoltorio propio de `connectivity_plus`

- **Decisión:** `SyncTriggers` no depende de `package:connectivity_plus` directamente, sino de una
  interfaz propia (`ConnectivityProbe`, dos métodos: `onChanged` y `check()`) que
  `PluginConnectivityProbe` implementa sobre `Connectivity()`.
- **Motivo:** así se puede probar `SyncTriggers` con una versión falsa de verdad (un
  `StreamController` normal), sin necesitar el binario de pruebas de plugins de Flutter ni montar
  un canal de método falso solo para esto.
- **Pendiente de verificar cuando se instale el paquete:** la forma exacta de la API de
  `connectivity_plus` 7.3.2 (`Connectivity().onConnectivityChanged` como
  `Stream<List<ConnectivityResult>>` y `checkConnectivity()` como
  `Future<List<ConnectivityResult>>`, con soporte de varias conexiones a la vez) se tomó de la
  documentación pública del paquete, no se pudo comprobar contra el código fuente instalado (no se
  ha corrido `flutter pub get` en este worktree). Si la forma real difiere, solo hay que ajustar
  `PluginConnectivityProbe`; `ConnectivityProbe` y `SyncTriggers` no cambian.

### 2026-10-11 · `SyncController` con `attach`/`detach`, igual que `VaultLockController`

- **Decisión:** `SyncController` (el `Notifier` que expone `SyncUiState` a la interfaz) no crea su
  propio `SyncEngine`: empieza vacío (`SyncUiState.empty`) y espera a que alguien le entregue uno
  ya montado con `attach(engine)`; `detach()` lo suelta y vacía el estado.
- **Motivo:** el `SyncEngine` necesita un `SyncStore`/`SyncTransport`/`ItemCodec` reales, que solo
  existen tras abrir la base local de una cuenta (con sesión y clave maestra) — y eso todavía no
  existe como flujo completo (llega en la fase 8, que construye el arranque y el inicio de
  sesión). Es exactamente el mismo problema que ya resolvió `VaultLockController` en la fase 5
  (empieza sin `Vault` y lo recibe en `unlock()`), así que se repite el mismo patrón en vez de
  inventar uno nuevo. Igual que allí, **queda pendiente para la fase 8**: llamar a
  `SyncController.attach(...)` y a `SyncTriggers.start(...)` justo después de desbloquear (abrir la
  base, montar el `SyncEngine` con `RemoteSyncTransport`/`LocalItemCodec`/`LocalSyncStore`), y a
  `SyncController.detach()`/`SyncTriggers.stop()` al bloquear y al cerrar sesión.

### 2026-10-11 · Arnés de los vectores de comportamiento: misma `masterKey`, sin un segundo dispositivo real

- **Contexto:** `sync-behavior.json` describe sus 19 escenarios en **campos lógicos** (sin bytes
  cifrados, ver `contract/vectors/README.md`) y con dos dispositivos (`a`, el observado, y `b`).
  Reproducirlo tal cual habría significado montar un servidor simulado en Dart.
- **Decisión:** el arnés (`app/test/sync`) solo monta el dispositivo `a` de verdad
  (`LocalDatabase.memory`). Los pasos de `b` se ignoran (nunca tocaron el estado de `a`: solo
  existían para que el generador produjera las respuestas que ya vienen grabadas en
  `exchanges[]`). Cuando una respuesta trae una nota o carpeta remota, `ShadowSealer` la cifra de
  verdad con la **misma `masterKey`** que tiene `a` (generada una vez por escenario y pasada a los
  dos), usando `LocalCodec` con un `Vault` propio: como el AAD de `axonote_crypto` solo depende de
  `userId` (fijo, `u_test`, igual que `LocalHarness`), entidad e id —nunca del dispositivo que
  cifró—, lo que cifra `ShadowSealer` lo puede descifrar el `Vault` real de `a` sin diferencia.
- **Dato que lo hace posible:** se comprobó sobre los 19 escenarios que **todo** conflicto de una
  respuesta trae su `remoteChanges` acompañante con el mismo id en la misma respuesta (aunque
  `conflicts[].remote` del vector solo guarde título y texto): de ahí se completan
  `folderId`/`revision`/`deletedAt` para construir el `EncryptedNote` entero que pide
  `ConflictReport.remote`. `createdAt`/`updatedAt` de lo remoto se fijan a un instante constante
  (`shadowFixedInstant`): ningún escenario los compara.
- **`sync.json`** (el vector con bytes cifrados de verdad y una `masterKey` fija) se prueba aparte,
  en `sync_vector_test.dart`: la forma exacta de la petición que manda `RemoteSyncTransport` contra
  el vector real, y que sus `wrappedKey`/`payload` se descifran con esa `masterKey`.

### 2026-10-11 · CI: `packages/axonote_sync/test` se añade a la lista de formato

- `packages/axonote_sync/test` no existía antes de esta fase. Se añadió a la lista de `dart format`
  de `.github/workflows/ci.yml` (regla general, plan §2 ALCANCE). **Nota al margen, no de esta
  fase:** `packages/axonote_api/test` no está en esa lista a pesar de que la decisión de la fase 4
  («Formato: se sigue la lista de la CI, sin tocar `third_party`») dice que sí debería estarlo;
  parece una discrepancia de una fase anterior. No se corrige aquí para no ensanchar el cambio de
  esta fase sin que opencode pueda confirmar primero que `dart format` no tiene nada pendiente que
  reportar en ese directorio (si lo tuviera, añadirlo ahora generaría un commit de formato ajeno a
  la fase 7).

### 2026-10-11 · Revisión de código: reintentos, errores sin capturar y señal de cambio local

Una revisión de la fase (leyendo el código, sin ejecutar nada) encontró varios huecos reales;
se corrigen aquí.

**A. `SyncController.syncNow` solo capturaba `AppFailure`.** Cualquier otra excepción (p. ej. el
`StateError` que lanza `LocalCodec.sealNoteForUpload`/`sealFolderForUpload` ante una fila ilegible
sin `raw_payload`, o cualquier fallo de la base) se escapaba sin capturar: la fase se quedaba en
`syncing` para siempre y la excepción llegaba sin manejar al `unawaited` de los disparadores.
Ahora `syncNow` captura cualquier fallo y lo convierte en un `UnknownError` genérico si no es
`AppFailure` — sin volcar nunca el mensaje de la excepción (podría llevar datos de la persona) — y
protege también el `snapshot()` posterior con el mismo criterio, para no quedarse colgado si leer
el almacén fallara justo después de sincronizar.

**B. `locked` no estaba tratado (A3).** Si el cofre se bloquea a mitad de una sincronización (el
motor sigue leyendo/escribiendo la base mientras el bloqueo borra la clave maestra de memoria),
`AppFailure(LockedError())` se mostraba como aviso persistente igual que cualquier otro fallo. Se
descarta en silencio, como `session-expired`/`device-revoked` (sin disparar ningún aviso: a
diferencia de esos dos, bloquear no necesita que nadie reaccione — ya lo hizo quien bloqueó).

**C. El disparador por cambio local escuchaba `NoteRepository`/`FolderRepository.watch()`.**
Esos métodos están pensados para listas en pantalla: en cada cambio vuelven a consultar y
materializar la lista entera (sin límite; con 10 000 notas, ~270 ms medidos en la fase 6) solo
para descartarla y usarla de señal, emiten una vez al suscribirse (sincronización duplicada a los
3 s de desbloquear) y se disparan también cuando `applyResult` escribe una nota o carpeta
descargada (una sincronización de más tras cada descarga remota). Se sustituye por
`SyncStore.localChanges` (interfaz nueva, ver más arriba): un `Stream<void>` sobre las
actualizaciones de la tabla `outbox` (`LocalSyncStore`, sobre `db.tableUpdates()`), que no emite
nada al suscribirse y no se dispara por descargas que no tocan la cola. De paso se encontró que
`SyncDao.insertOutbox`/`updateOutbox`/`deleteOutbox` nunca llamaban a `notifyUpdates('outbox')`
(a diferencia de `notes`/`folders`/`conflicts`, que sí lo hacían): sin eso, ninguna señal sobre
`outbox` habría funcionado nunca; se corrigió como parte de este mismo cambio. Además, el rebote
ahora comprueba `pendingCount()` antes de sincronizar: como `localChanges` también avisa cuando
`applyResult` vacía una entrada ya confirmada, sin esa comprobación cada sincronización con algo
que subir se seguiría de otra 3 s después, sin nada que hacer.

**D. Reintentos del plan §7, antes inexistentes.** Ver la entrada de más arriba («El motor hace
un solo intento…»): `SyncTriggers` ya aplica la espera exponencial, la supresión por
`rate-limited` y la ausencia de bucle propio ante `forbidden`, con pruebas para cada caso usando
el `TimerFactory` falso.

**E. Fechas que bajan sin milisegundos o con microsegundos.** `remote_sync_transport_test.dart`
añade los dos casos límite: una fecha remota sin fracción de segundo (`…T10:00:00Z`) se normaliza
a milisegundos (`…T10:00:00.000Z`, mismo instante); una con microsegundos
(`…T10:00:00.123456Z`) se trunca a milisegundos (`…T10:00:00.123Z`, `isoFromDateTime` solo lee
`DateTime.millisecond`, nunca `.microsecond`). **Por qué es seguro, no solo supuesto:**
`createdAt`/`updatedAt`/`deletedAt` de una nota o carpeta los fija siempre un **cliente** (web o
móvil, nunca el servidor, que solo los guarda y los devuelve tal cual — ver plan §6 y
`notify_web`: ambos clientes usan `Date.prototype.toISOString()`/`isoFromDateTime`, que siempre
escriben exactamente 3 dígitos de milisegundos). Ninguno de los dos casos debería darse nunca en
la práctica; si alguna vez se diera, además, la base local solo puede guardar texto con
milisegundos (plan §6, `IsoDate`), así que una fracción de microsegundo no se podría conservar de
todos modos aunque se intentara — truncarla al bajar no pierde nada que el móvil pudiera guardar.

### 2026-10-11 · Tercera revisión de código: ids de los vectores, errores de compilación, snapshot en attach e isolate

Una tercera ronda, tras pasar por primera vez las puertas de calidad reales (`flutter analyze`,
`flutter test`, `flutter drive --profile` en el ZTE), encontró lo siguiente.

**F. Los 17 escenarios de `sync-behavior.json` que crean algo fallaban por el id.** El vector se
generó «con reloj e ids fijos» (`sync-behavior-vectors.ts` parchea `crypto.getRandomValues` con
una secuencia determinista): sus pasos `createNote`/`createFolder` llevan el id exacto que debe
salir, y la prueba comparaba el estado entero, así que el id real y aleatorio del móvil nunca
coincidía. **Se descartó reproducir el generador aleatorio determinista** (acoplaría la prueba a
los detalles de implementación de ese parche, en TypeScript, y a cuántas llamadas a
`crypto.getRandomValues` hace cada paso previo de los 19 escenarios en orden): en vez de eso,
`LocalDeps` gana un campo `newId` inyectable (por defecto el real, `domain.newId`), que
`LocalDatabase.open`/`.memory` reciben y pasan; los cuatro sitios que generaban un id localmente
(crear nota, duplicarla, crear carpeta, la copia «(conflicto)» de `resolveConflict('both')`) lo
usan en vez de la función global. `sync_behavior_vectors_test.dart` programa, antes de cada paso,
el id que hace falta: el de `createNote`/`createFolder` viene en el propio paso; el de la copia
de `both` —que no viene en ningún paso— se obtiene comparando los ids de nota del estado anterior
con los del `expected` del paso (el único nuevo es el de la copia), ya que ese estado esperado es
justo lo que el vector grabó. Tras arreglar el id, los 19 escenarios pasaron tal cual: no apareció
ninguna diferencia real tapada detrás del id, como se temía al proponer la corrección.

**G. `flutter analyze`, 34 avisos reales.** 8 errores de compilación en
`sync_cross_client_test.dart`: usaba `AccountApi` donde hace falta `KeysApi` para `/keys`, y los
DTO de `axonote_api` (`KdfParamsDto`/`KeyBundleDto`) donde `axonote_crypto` —que no depende de
`axonote_api`, plan §4.2— espera sus propios tipos (`KdfParams`/`KeyBundle`); se añaden
`_kdfParams`/`_keyBundle` para convertir entre ambos en esa única prueba manual que cruza los dos
paquetes. El resto (26 avisos/infos) no cambiaba comportamiento: `.cast<Map>()` sin argumentos
(`strict_raw_type`) pasa a `.cast<Map<String, Object?>>()`; `RemoteSyncTransport`/
`ScriptedSyncTransport` simulaban un campo privado con otro nombre
(`required String deviceId}) : _deviceId = deviceId`, `prefer_initializing_formals`) sin nada que
encapsular, así que los campos pasan a ser públicos y el constructor los asigna con `this.<campo>`
directamente; dos `if (… == null)\n  return;` de dos líneas ganan llaves
(`curly_braces_in_flow_control_structures`); `dio` pasa a ser `dev_dependency` directa de `app`
(antes solo transitiva vía `axonote_api`, `depend_on_referenced_packages`: `fake_dio.dart` lo usa
a propósito, como ya hacía `packages/axonote_api/test/support/fake_dio.dart`); y `const` donde
faltaba (`prefer_const_constructors`) en construcciones cuyos argumentos ya eran todos constantes.

**H. `SyncController.refresh()` sin proteger.** `attach()` la llama con `unawaited`: si
`engine.snapshot()` fallaba (como en la prueba que simula un almacén que lanza al leer
`conflicts()`), la excepción no tenía quién la capturara y se convertía en un error de zona
huérfano en vez de quedar en el estado, aunque `syncNow()` ya protegía su propio `snapshot()`
posterior con el mismo criterio. Se corrige igual: la fase pasa a `error`, nunca se propaga.

**I. Primera descarga: isolate de trabajo, implementado tras medir el bloqueo real.** Ver la
entrada de más arriba («Isolate de trabajo para el descifrado por lotes…»): la premisa original
(que `cryptography_flutter` ya evitaba el bloqueo) era falsa; medido en el ZTE, el bloqueo máximo
por página llegaba a ~560 ms. `remote_decrypt_worker.dart` lo resuelve con `Isolate.run`, solo para
páginas de más de 50 elementos.

**Costura con la fase 8:** `app/lib/app/sync_session.dart` (`SyncSession.open`/`close`) reúne en
un solo sitio todo lo que la fase 8 tendrá que llamar desde `VaultLifecycle.onUnlocked`/
`onSignedOut`, con `onSessionExpired`/`onDeviceRevoked` ya conectados a los que le pase quien
llame. No implementa nada de la fase 8 (ni `HttpClient` por cuenta, ni `deviceModel()`, ni el bus
de eventos de sesión): solo deja el punto de unión listo y probado (`sync_session_test.dart`).

### 2026-10-11 · Isolate de trabajo: el bloqueo bajó a 20-21 ms, pero el tiempo total casi se triplicó

Segunda medición en el ZTE tras montar el isolate (ver la entrada de más arriba): bloqueo máximo
del isolate principal 20-21 ms (bien por debajo del umbral de 100 ms — el isolate cumple su
objetivo), pero el tiempo total pasó de 5,1 s / 4,7 s a **13,5 s / 13,4 s**, cerca del presupuesto
de 15 s. Se revisó el código (sin ejecutar nada) buscando trabajo real de más, con esta lista:

- **¿`Isolate.run` arranca un isolate nuevo por página?** Sí: `decryptRemoteChangesInWorker`
  (`remote_decrypt_worker.dart`) hace un `Isolate.run` por llamada, y `LocalSyncStore.applyResult`
  la llama una vez por página — con 2 000 notas en páginas de 500, son **4 arranques y 4 cierres**
  de isolate por sincronización, donde antes no había ninguno. Real, pero su coste típico (arrancar
  la VM del isolate, cargar sus bibliotecas) se mide normalmente en decenas de ms, no en segundos:
  4 arranques no deberían explicar por sí solos la mayor parte de un salto de ~8,4 s.
- **¿Se copian los 500 elementos y las 500 filas dos veces?** Sí, eso es inherente a usar un
  isolate aparte: el lote de `RemoteChange`/`EncryptedNote` cruza hacia el isolate y el lote de
  `NoteRow`/`FolderRow` ya descifradas cruza de vuelta, ambos copiados (el paso de mensajes entre
  isolates no comparte memoria). Para notas de ~1-2 KB, esto es trabajo real pero barato
  (serializar algunos cientos de objetos pequeños), no la explicación principal esperada.
- **¿El isolate reinicializa algo caro en cada página (p. ej. `package:cryptography`)?** No se
  encontró nada: la inicialización de `AesGcm.with256bits(...)` (`axonote_crypto/src/sealed.dart`)
  es la construcción de un objeto Dart normal, sin trabajo pesado documentado; el coste de que
  cada página vuelva a cargar las bibliotecas del isolate ya queda contado en el punto del arranque
  de arriba, no es un coste aparte.
- **¿La prueba cifra las 2 000 notas remotas dentro del tiempo medido?** No: `_sealRemoteNotes`
  corre antes de crear el `Stopwatch`, que arranca justo antes de `engine.syncNow()`. El total
  medido es solo el ciclo de sincronización.
- **Lo que sí explicaría el resto:** mover el descifrado a otro isolate cambia el **tipo** de
  coste, no solo lo mueve — el isolate principal ahora tiene que esperar a que el sistema
  planifique y ejecute el isolate de trabajo (un cambio de contexto real, no solo CPU), lo que
  convierte bloqueo síncrono en latencia de ida y vuelta: menos bloqueo, pero no necesariamente
  menos tiempo total. Esto es coherente con lo medido (bloqueo mucho mejor, total peor), pero por
  sí solo tampoco parece suficiente para 8,4 s en un dispositivo en condiciones normales.
- **La pista más fuerte, ajena a este cambio:** en la misma sesión, la prueba de la fase 6 (sembrar
  2 000 notas, sin isolates ni red, código que esta fase no tocó) también salió ~3,7× más lenta
  (6,3 s frente a 1,7 s). Un código que no cambió no se vuelve 3,7× más lento solo; apunta a que el
  propio teléfono estaba en un estado distinto durante esta sesión de medición (temperatura,
  ahorro de batería, otra app en segundo plano) más que a esta fase.
- **Por qué no se implementó el isolate de trabajo persistente (la alternativa que se barajó):**
  haría falta que `LocalSyncStore.applyResult` supiera que una página es la última para cerrarlo
  "al terminar" como pide un buen ciclo de vida, y hoy no lo sabe: `applyResult` no recibe
  `hasMore`, y `SyncStore` (interfaz pura de `axonote_domain`) no tiene ningún punto de
  "empieza"/"termina la sincronización". Añadirlo exigiría ampliar esa interfaz (afecta a
  `FakeSyncStore`, a los 19 escenarios de `sync-behavior.json` y a cualquier otro implementador
  futuro) para un ahorro que, por el análisis de arriba, probablemente no sea el grueso de los
  8,4 s. No se hizo este cambio más grande a ciegas.
- **Pendiente:** remedir con el teléfono en reposo (sin cargar, enfriado, sin otras apps) antes de
  decidir si hace falta el isolate persistente. Si el total vuelve a estar cerca de los 5 s
  originales, confirma que era el estado del teléfono. Si sigue por encima de ~10 s con el
  teléfono en reposo, sí merece la pena el isolate de trabajo persistente de arriba (y entonces
  haría falta ampliar `SyncStore` con el lifecycle que le falta).

## Fase 8

### 2026-10-11 · Arquitectura de la cuenta (interfaces en el dominio, implementación en `data`)

- **Decisión:** las interfaces nuevas viven en `axonote_domain` (`AuthRepository`,
  `VaultPrefsRepository`, `VaultActivityStore`, `LocalDataCleaner`) y un `Result<T>` (`Ok`/`Err`,
  §4.3); sus implementaciones HTTP/seguras, en `app/lib/data/auth`. El estado
  (`features/auth/state/AuthController`, Riverpod) solo conoce esas interfaces y `axonote_crypto`
  (para derivar claves), igual que el `auth.svelte.ts` de la web.
- **Motivo:** §4.2 (la `ui` solo habla con `state`; `state` solo con interfaces de dominio) y no
  meter `dio`/`drift` fuera de `app/lib/data`.

### 2026-10-11 · Forma de `KeyBundle`/`KdfParams` en el dominio

- El contrato los da como DTO (`axonote_api`); `axonote_domain` no puede importar
  `axonote_crypto` ni `axonote_api`. Se definen copias del dominio (`KdfParams`, `KeyBundle`,
  `LoginResult`, `MfaChallenge`…) y `app/lib/data` mapea DTO ↔ dominio. El estado convierte
  dominio ↔ `axonote_crypto` con funciones locales. **Aviso de nombres:** el `LoginSession` del
  dominio chocaba con el `LoginSession` de `axonote_api` dentro de `auth_api.dart`; se renombró a
  `LoginSucceeded`/`LoginMfaRequired` (el conflicto rompía la compilación del paquete de API).

### 2026-10-11 · Google fuera de v1 (D5) y sin tablero de cuenta con Google

- Los tableros «Registro» e «Inicio de sesión» de Penpot incluyen «Continuar con Google»; D5 lo
  deja fuera de v1. Se omite el botón **y** su divisor «o». El tablero «Registro (oscuro)» ya viene
  sin Google y sin tarjeta; el claro sí usa tarjeta. Se sigue el **tablero claro** para Registro e
  Inicio de sesión (tarjeta 372×533, radio 28) por coherencia y porque es el principal; el oscuro
  se usa solo para verificar el set oscuro. Diferencia anotada en el informe.

### 2026-10-11 · Marca: «AxoNote» (no «Apunte»)

- Los tableros usan «Apunte» (nombre del archivo). El producto es **AxoNote** (`com.axonote.app`);
  se muestra «AxoNote» en la bienvenida y en los textos. La forma (logotipo «A», color `accent`) es
  la del diseño.

### 2026-10-11 · `deviceModel()` en `axonote_platform` (A8)

- Para el nombre del dispositivo del login (modelo + `android`), se añadió `deviceModel()` (Kotlin
  `Build.MANUFACTURER`/`Build.MODEL`) al único módulo nativo propio (A8), en vez de traer
  `device_info_plus`. `hasStoredMasterKey({userId, requireAuth})` se añadió igualmente (ver más
  abajo).

### 2026-10-11 · Argon2id en isolate (`IsolateArgon2id`)

- §4.4: la derivación va en un isolate de trabajo (`app/lib/data/crypto/argon2id_isolate.dart`); la
  librería `sodium` se carga una vez dentro y las peticiones se atienden en serie. La interfaz
  muestra progreso (`AuthState.deriving`). En el arranque (`main.dart`) se arranca el isolate; si
  falla, se usa `SodiumArgon2id` directo como último recurso.

### 2026-10-11 · Arranque en frío y tiempo de bloqueo persistente (pendiente de la Fase 5)

- `AuthController.bootstrap()` decide **con qué cuenta** intentar `unlockWithStoredKey`
  (`VaultPrefsRepository.cachedSession()` = `AccountSecureStore.readUserId()`) y **si el tiempo de
  bloqueo ya venció**, leyendo la última actividad guardada
  (`VaultActivityStore` = `AccountSecureStore.readLastActiveAt`). Se persiste en
  `VaultLockController` (actividad, segundo plano, bloqueo y cierre de sesión). Reglas de
  auto-desbloqueo: `lockOnExit` o `immediately` → no; `never` → sí; con tiempo → comparar con la
  última actividad. Sin red, `currentSession()` falla con `network` y se continúa en local
  (desbloqueo sin red). `session-expired` → `expired`; `device-revoked` → cierre y borrado (A1).

### 2026-10-11 · `unlock` ya **no** re-guarda si la clave está con la misma política (pendiente Fase 5)

- **Decisión:** `VaultLockController._applyRememberPolicy` consulta
  `AxonotePlatform.hasStoredMasterKey(userId, requireAuth)` y **omite** el re-guardado cuando ya hay
  una clave guardada con la misma política. Así, desbloquear con contraseña con `biometricLock:
  true` **no** vuelve a mostrar el cuadro de biometría/credencial si la clave ya estaba recordada.
  Ante error de la consulta, se comporta como antes (guarda). Cubierto por las pruebas de la fase 5
  (siguen en verde) y por la nueva consulta nativa.

### 2026-10-11 · `FLAG_SECURE` por defecto y en las pantallas «siempre» (pendiente Fase 5)

- La raíz de la app envuelve el router en `SecureScreen(restoreOnDispose: false)`: `FLAG_SECURE`
  **activado por defecto** (privacidad). Además, las pantallas de **clave de recuperación** y
  **desbloqueo** lo fuerzan mientras están montadas. (Códigos de respaldo y secreto TOTP son de la
  fase 11.) El ajuste que lo podrá desactivar llega en la fase 11.

### 2026-10-11 · Punto de extensión con la Fase 7 (`onUnlocked`/`onSignedOut`)

- `features/auth/state/vault_lifecycle.dart` define `VaultLifecycle` (callbacks `onUnlocked(userId,
  Vault)` y `onSignedOut(userId)`) y el proveedor `vaultLifecycleProvider` (no-op por defecto). El
  `AuthController` los llama al desbloquear y al cerrar sesión / `device-revoked`. **La fase 7 no se
  implementa aquí**: la fase 7 sobrescribirá el proveedor para abrir `LocalDatabase.open` y disparar
  la sincronización. A1: cerrar sesión y `device-revoked` borran lo local
  (`VaultLockController.signOut` + `LocalDatabase.wipe` vía `LocalDataCleaner` + `AccountSecureStore`).

### 2026-10-11 · Registro: se usa la tarjeta del tablero claro (no el full-screen del oscuro)

- El tablero «Registro» (claro) usa una tarjeta (radio 28) y el «Registro (oscuro)» es full-screen.
  Se implementa la **tarjeta del claro** para Registro y para Inicio de sesión (coherencia entre
  ambas pantallas de autenticación y porque el claro es el principal); el oscuro verifica el set
  oscuro. En ambos se omite Google (D5). Diferencia anotada en el informe.

### 2026-10-11 · Toast como componente (tablero «Toasts»)

- Se creó `app/lib/ui/components/toast.dart` (`AxoToast` + `showAxoToast`): 388 de ancho, radio 12,
  `bgEditor`, punto de color + mensaje 14/500 + acción 14/600. Se usa para confirmar la copia de la
  clave de recuperación y el reenvío del código.

### 2026-10-11 · Lectura de Penpot de la Fase 8 (leída tablero a tablero)

- Todos los tableros de la fase 8 se leyeron por el MCP (ver `docs/design/penpot-progress.md`), con
  varias paradas por la regla de conexión (dos timeouts seguidos → parar). Cada pantalla indica en
  el informe el tablero que la respalda.

### 2026-10-11 · Revisión de fidelidad de la Fase 8 (tokens y pantallas)

Tras comparar los goldens con los tableros, se corrigió pantalla por pantalla leyendo cada tablero
por el MCP (detalle en `docs/design/penpot-progress.md`).

- **Tokens nuevos** en `app/lib/ui/tokens.dart`:
  - `AxoGlow.accent/plum/amber` (`#2a5db0` 20 %, `#7b4b8a` 14 %, `#b7791f` 12 %): los tres
    resplandores del fondo de Registro e Inicio de sesión (medidos).
  - `AxoShadows.card` (`#1f1a14` al 10 %, blur 64, y 24, spread −8): sombra de la tarjeta.
  - Roles tipográficos medidos: `button` (16/600), `bodyReading` (16/400), `bodySmall` (14/400);
    `title` pasa a `letterSpacing` 0 (el tablero lo mide 0; se corregía a −0.56 por la ficha
    antigua). No se sustituyó ningún rol existente.
- **Fondos por tablero:** Bienvenida, Onboarding, Verificación y Recuperar usan `bgEditor`
  (`#fffdf8`); Registro (claro) e Inicio de sesión usan `bgApp` (`#f6f2ea`) con resplandores y
  tarjeta `bgEditor`. **Registro (oscuro)** es a pantalla completa con `bgEditor` oscuro, sin
  tarjeta ni resplandores (tablero «8 · Modo oscuro — Registro (oscuro)»); la pantalla de registro
  ramifica por tema (claro = tarjeta, oscuro = pantalla completa).
- **Etiquetas de campo** en `textPrimary` (el tablero mide `#1f1d1a`), no `textSecondary`; casilla
  sin marcar con borde `textTertiary` (`#675f55`).
- **Medidor de contraseña:** una sola barra continua (pista `borderDefault`, progreso `accent`,
  alto 4, radio 2), no cuatro segmentos.
- **Logo:** 96 radio 24 (bienvenida), 48 radio 14 (tarjeta).
- **Goldens:** el arnés emula el chasis del tablero (`MediaQuery` con barra de estado 39 y de gestos
  26) para comparar como el diseño.
- **Pendiente de relectura:** «Error de servidor» (dos timeouts seguidos → parada; se dejó como
  estaba) y `Registro (oscuro)` (leído en la primera pasada, no re-leído en esta).

## Fase 9 · Notas (2026-10-14)

### 2026-10-14 · El diseño pasa a Pencil (`axonote.pen`) y se lee tablero a tablero

- La fuente de verdad del diseño deja de ser Penpot y pasa a ser el documento de **Pencil**
  «axonote» (`~/.pencil/documents/31878e13-9a73-448f-891e-9066150ee94e/axonote.pen`), sección
  **Móvil** (tableros `Android — …` de 412×915). Se leyeron los 18 tableros de la fase con el MCP
  `pencil` (`Get` con visitante + `TakeScreenshot`); el detalle de medidas está en
  `docs/design/pencil-measurements.md`.
- El documento usa el nombre viejo «Apunte»; en la app se escribe **AxoNote**.
- Los iconos del documento son de Lucide, pero el set vendorizado en `assets/icons/` es un
  subconjunto anterior y **no tiene** algunos que el diseño usa: `compose`, `more`, `share`,
  `notes`, `close`, `sidebar`. Se mapean a los existentes (`pencil`, `ellipsis`, `share-2`,
  `file-text`, `x`, `menu`), sin dibujar SVG nuevos a mano. Diferencia anotada en el informe.

### 2026-10-14 · Tokens nuevos de la fase 9 (medidos, con su tablero)

- En `app/lib/ui/tokens.dart`: `AxoType.search` (16/400), `chip` (14/500), `chipActive` (14/600),
  `navItem` (14/500), `groupHeader` (13/600), `option` (15/500), `sectionLabel` (11/600), `meta11`
  (11/500), `meta12med` (12/500), `buttonSm` (15/600); `AxoRadii.chip` (10, chip y tarjeta de
  nota) y `AxoRadii.fab` (18); `AxoSizes.searchBar` (48), `chip` (33), `groupHeader` (38),
  `sidebarItem` (34), `drawer` (304), `noteSkeleton` (92), `illustration` (80), `optionRow` (48).
  No se sustituyó ningún token existente.

### 2026-10-14 · Componentes: cambios y altas

- **`AxoNoteCard`** pasa a la tarjeta del diseño nuevo: 80 de alto, radio 10, relleno [12,14], hueco
  4 y **sin relleno de fondo** (fila plana sobre `bgApp`; antes tenía `bgEditor`). Tres filas:
  pin + título 14/600, fecha 12/500 + vista previa 12/400, y carpeta 11/500. Acepta `highlight`
  (resalta coincidencias de la búsqueda con `bgSelected`, color no medido en el tablero),
  `folderLabel` y `unreadable`.
- **`AxoBottomSheet`** usa `bgEditor` (el tablero «Menú contextual de nota» lo mide `#fffdf8`); el
  contenedor de acciones va dentro con `bgApp` (`AxoSheetActions`).
- **`AxoDialog`** se rellena a 24 (antes 28) y su ilustración es 56 en `statusDangerBg` con icono
  `statusDanger` (peligro) o 64 en `bgSelected` con icono `accent`.
- **`AxoBanner`** gana la variante `note` (relleno `bgSelected`, texto `textPrimary`, sin icono),
  la del aviso de la papelera.
- **Nuevos componentes** en `app/lib/ui/components/`: `folder_chip`, `note_group_header`,
  `search_field`, `fab`, `skeleton`, `empty_state`, `offline_banner`, `option_row`, `radio`,
  `drawer`.
- **Goldens** nuevos de las 14 pantallas de la fase en claro y oscuro
  (`app/test/features/notes/goldens/`, `notes_screens_golden_test.dart`).

### 2026-10-14 · `Note.preview` en el dominio

- `list()` devuelve resúmenes **sin** `content` (§4.4), así que la tarjeta no podía pintar la vista
  previa. Se añade `Note.preview` (opcional, `''` por defecto) y se rellena desde la columna
  `preview` de la §6 (`rows.toNote()`, `local_note_repository._save`). Es solo de lectura para la
  interfaz; no viaja en el payload cifrado.

### 2026-10-14 · Se cierra la costura entre las fases 7 y 8 que quedó suelta

- Nadie abría la base local al desbloquear (la fase 7 dejó `SyncSession.open` listo y la fase 8 solo
  definió los ganchos). La fase 9, que necesita los repositorios, la cierra:
  `app/lib/app/local_session.dart` (`LocalSessionController`) abre `SyncSession` en `onUnlocked` y
  la cierra en `onSignedOut`/al bloquear, y `main.dart` sobrescribe `vaultLifecycleProvider`.
- **A3:** se añade `VaultLifecycle.onLocked` (síncrono) y `VaultLockController.lock()` lo llama, para
  que con el cofre bloqueado no quede la base abierta.
- **`deviceId`:** el plan lo situaba en la tabla `meta`, pero `LocalDatabase.open` lo necesita
  *antes* de abrir la base. Se genera una vez y se guarda en el almacén seguro
  (`AccountSecureStore.readOrCreateDeviceId`, clave `device.id`), expuesto por `deviceIdProvider`.

### 2026-10-14 · Lista por páginas y sin jank evitable

- La lista pide **páginas de 200** (`notesPageSize`) y se pinta con `ListView.builder` sobre filas ya
  aplanadas (`NoteListRow`), cargando la página siguiente al acercarse al final (§4.4).
- El agrupado se calcula una vez por cambio de datos en `notesRowsProvider` (no en cada
  reconstrucción). `noteCountsProvider` se apoya en `notesChangedProvider` (consulta fija barata) en
  vez de en la lista paginada: reagregar en cada página era trabajo inútil por página.
- Aun así, **el presupuesto de la §11 no se cumple** (p99 de cuadro 16,4–18,3 ms con 10 000 notas;
  el pendiente y las cifras están en `docs/benchmarks.md`).

### 2026-10-14 · Alcance de la fase 9 en el menú contextual y la sesión

- El menú contextual del diseño incluye **Compartir**, que es de la fase 11 (enlaces públicos): se
  omite aquí (una entrada menos que el tablero, anotado en el informe).
- Mientras no existan los ajustes (fase 11), «Bloquear» y «Cerrar sesión» viven en el menú del
  botón «más» de la lista (compuesto con componentes base, sin tablero propio), para no perder el
  ciclo de sesión de la fase 8. El menú de orden (Última edición · Fecha de creación · Título) no
  tiene tablero y se compone igual.

### 2026-10-14 · Gestos de la lista (deslizar): decisión propia, documentada

- El plan §10 pide «acciones por menú **y por gesto**», pero **ni el documento de Pencil ni
  `notify_web` los definen**: el documento no tiene nodos de nota/contexto con instrucciones ni
  ningún texto que mencione deslizar (comprobado nodo a nodo), y la tarjeta de la web solo responde
  a `click` (no hay `pointerdown`/`touchmove` de arrastre; el único `touchstart` es el contador de
  actividad para el bloqueo). Así que se decide aquí, siguiendo la convención de Android y el
  vocabulario del propio diseño:
  - **Lista (nota activa):** deslizar **a la derecha** fija/desfija (fondo `bgSelected`, icono
    `pin`; la tarjeta vuelve a su sitio) · deslizar **a la izquierda** la manda a la papelera (fondo
    `statusDanger`, icono `trash`) con el aviso «Deshacer» de la web.
  - **Papelera:** deslizar **a la derecha** restaura · deslizar **a la izquierda** elimina
    definitivamente, pero **con confirmación** (no se puede deshacer): la tarjeta vuelve a su sitio
    y se abre el diálogo.
- Es el mismo reparto que el menú contextual (que sí tiene tablero), para que gesto y menú no
  discrepen. Componente: `app/lib/ui/components/swipe_tile.dart` (`AxoSwipeTile` +
  `AxoSwipeAction`); pruebas en `app/test/features/notes/notes_swipe_test.dart`.
- **No hay golden** de los gestos: el tablero no muestra ningún estado deslizado (la instrucción
  era poner golden solo si el tablero lo muestra).

### 2026-10-14 · Papelera y avisos: textos y regla iguales a `notify_web`

- La **regla** y el **texto** de los días restantes ya coincidían y se dejan igual, con prueba que
  los fija: `daysUntilPurge(deletedAt, now, trashRetentionDays)` es el mismo cálculo que
  `src/lib/domain/note-groups.ts` (suelo, mínimo 0) y el texto es
  `` `Se elimina en ${formatCount(days, 'día', 'días')}` `` de
  `src/routes/(app)/notes/+page.svelte` (`Se elimina en 1 día`, `Se elimina en 29 días`).
  Pruebas: `packages/axonote_domain/test/note_query_test.dart` (29/16/9/0) y
  `app/test/features/notes/note_dates_test.dart` (texto) + el golden de la papelera.
- Se alinean además los textos de los avisos y diálogos con el código de la web (`note-dialogs.svelte`
  y `notes/+page.svelte`): «Nota movida a la papelera» (con **Deshacer**) en vez de «Nota enviada a
  la papelera», «Papelera vaciada», «Nota eliminada definitivamente», «Nota movida a {carpeta}» y
  «Se eliminarán definitivamente N notas. No podrás recuperarlas.» en el diálogo de vaciar, más los
  mensajes de error por acción («No se pudo mover la nota», …).
- **Crear una carpeta desde «Mover a carpeta» mueve la nota a la carpeta nueva**, como la web
  (`note-dialogs.svelte`: «Si se creó desde "Mover a carpeta", la nota se mueve a la carpeta
  nueva»).

### 2026-10-14 · Fase 10 · Códec Markdown propio (D2) en `packages/axonote_markdown`

- El códec es **propio** (decisión D2), Dart puro, sin Flutter. Reproduce byte a byte el Markdown
  de `notify_web` (TipTap 3 con `StarterKit` + `TaskList`): **320 pruebas** verifican los 82 casos
  de `contract/vectors/markdown.json` (conservación + serialización forzada de los soportados) y
  los 64 casos de `serialize` (documento → Markdown), más la propiedad de conservación por bloque
  (editar un bloque no toca los bytes de los demás) y el bloque opaco. Cobertura 99 %.
- **No se usa `package:markdown`** (aparecía en la §9 como analizador): su modelo de bloques y su
  normalización (líneas en blanco, entidades, escapes, listas) no reproducen el canónico de TipTap,
  y D2 ya pide un códec propio. La dependencia no se añadió. El analizador es una pasada propia
  sobre líneas, con un sub‑analizador en línea (marcas, código, enlaces, autolinks, entidades,
  escapes y saltos duros).
- **Divergencia de lectura conocida:** los títulos con subrayado (`Título` + `====`) y otras
  normalizaciones que solo afectan a Markdown «crudo» (no al canónico que escribe la web) **no se
  normalizan** al leer; solo importarían al importar `.md` (fase 11). No afecta a los criterios de
  la fase (los vectores usan el canónico). Anotado en el traspaso.
- **Bloque opaco (§8.2.5):** el analizador detecta tabla, HTML de bloque, nota al pie e imagen en
  línea como bloque `opaque`, que se conserva intacto y viaja como nodo propio de solo lectura.

### 2026-10-14 · Fase 10 · Editor: adaptador, format bar y dependencias

- El adaptador `axonote_markdown` ↔ `appflowy_editor` vive en `app/lib/features/editor/state/`
  (§8.2.6); el códec no importa AppFlowy. La interfaz (`ui/`) solo habla con `state/`.
- **Barra de formato** (tablero «Android — Editor»): estilo de párrafo, negrita, cursiva, lista y
  tareas, con las medidas del diseño (`FormatBar` `#EDE7DC` r24, botones 40×40 r8, activo
  `bgSelected`). El tablero muestra un **botón de imagen** que se **omite** (las imágenes son
  bloque opaco, fuera de alcance) y el **«deshacer» está en la barra superior**, como en el
  diseño (el plan §8.2.7 lo listaba en la barra de formato). El set de iconos vendorizado no trae
  `bold`/`italic`/`list`: se usan glifos «B»/«I» (lo que dibuja el diseño) y el icono más cercano
  para las listas.
- **Estados sin tablero propio:** «conflicto» reutiliza la hoja de la fase 9; «nota ilegible» abre
  el editor en **solo lectura** (aviso + `editableNotifier` en falso); «sincronizando» se cubre con
  el indicador de la fase 7. Se componen con componentes base, sin tablero nuevo.
- **Dependencias:** se añaden `appflowy_editor` (path a `packages/third_party`), `axonote_markdown`
  y `provider` (lo necesita el componente del bloque opaco). El paquete vendorizado suma dos
  parches (retirar `device_info_plus` y `file_picker`, que chocan con `win32` 6 y `dbus` 0.8; ver
  `PATCHES.md`). La §9 no listaba `provider`; se anota aquí.
- **Guardado y recarga:** el contenido se guarda **400 ms** después de la última edición (A10) y al
  ir a segundo plano; al llegar una revisión nueva por sincronización se **recarga** el editor solo
  si no hay cambios locales pendientes (§8.3). El **enlace público** es fase 11 (menú «Compartir»
  presente pero sin acción todavía).

### 2026-10-15 · Fase 9 · Menú lateral: apertura, estado activo y entrada «Ajustes»

- **Desviación deliberada del tablero:** se añade al pie del drawer móvil una fila **«Ajustes»**
  (icono `settings` del set vendorizado, `assets/icons/settings.svg`) que navega a `/settings/menu`.
  El tablero «Android — Menú lateral» no la trae, pero la barra lateral de la **web** sí tiene
  «Ajustes» al pie (`notify_web/src/routes/(app)/app-nav.svelte`), y se busca paridad funcional. El
  contenido de las pantallas de Ajustes es de la **fase 11**: la ruta existe hoy como
  `PlaceholderScreen` en `app/lib/router/app_router.dart` y así se deja.
- **El drawer no abría:** el botón de menú y el toque en el título llamaban a `Scaffold.of(context)`
  con el `context` del propio `NotesScreen` (por encima del `Scaffold` que su `build` devuelve), lo
  que lanzaba `Scaffold.of() called with a context that does not contain a Scaffold` y no hacía nada.
  Se resuelve con un `GlobalKey<ScaffoldState>` (`NotesScreen` pasa a `ConsumerStatefulWidget`); no
  se cambia el diseño de la barra superior.
- **Estado activo:** ahora cada entrada del drawer (`Todas las notas`, `Fijadas`, cada carpeta, cada
  etiqueta, `Papelera`) deriva su `selected` del filtro/ruta actuales, según la variante
  `State=Selected` del `SidebarItem` (`bgSelected` + `accent`, 14/600). Antes solo se marcaba
  «Todas las notas».
- **Pie fuera del scroll:** `Papelera` y «Nueva carpeta» pasan a un pie fijo del `AxoDrawer` (fuera
  del `ListView`), junto a la nueva fila `Ajustes`, de modo que ningún botón del pie puede quedar
  tapado por el desplazamiento, como en la web.
- **Carga:** mientras `counts` es `null` no se pinta «0»; el contador se reserva con un
  `AxoSkeleton`.
- **Pruebas:** `app/test/features/notes/notes_drawer_test.dart` (apertura, navegación de cada
  entrada, cierre, estado activo y contador en carga) y golden nuevo `notes-menu-lateral-{light,dark}`
  en `notes_screens_golden_test.dart`. Informe: `docs/review-sidebar.md`.

### 2026-10-15 · Arranque en frío: restaurar la sesión y la introducción solo la primera vez

- **Fallo:** la app mostraba siempre onboarding/bienvenida aunque hubiera cuenta iniciada.
  `SessionController.build()` devolvía `noSession` y el redirect mandaba `/` a `/onboarding`; además
  `AuthController.bootstrap`, cuando el servidor no confirmaba la sesión (sin red, `currentSession()`
  nulo o token caducado), dejaba el estado en `noSession` sin ofrecer el desbloqueo local aunque
  hubiera sesión guardada.
- **Decisión:** `SessionController` arranca en `AxoSession.restoring` (nuevo estado) y el router
  muestra `/splash` mientras se lee el almacén seguro; así no parpadea ninguna pantalla.
  `AuthController.bootstrap` resuelve el estado terminal en todos los caminos:
  `noSession` (sin sesión guardada, sesión caducada o `device-revoked`), `locked` (hay cuenta
  guardada pero el bloqueo exige desbloquear: se permite el **desbloqueo local sin red**, §5.3) o
  `unlocked` (clave recordada y bloqueo no vencido). Ante un error inesperado cae a `noSession`
  para no quedarse en el arranque.
- **Introducción solo la primera vez:** se guarda una marca global del dispositivo
  (`VaultPrefsRepository.readOnboardingSeen`/`writeOnboardingSeen`, clave `app.onboardingSeen` en el
  almacén seguro). Sin sesión y sin la marca → `/onboarding`; con la marca → `/welcome`. La
  introducción la marca al terminar o saltar (`OnboardingScreen._finish`).
- **Navegación:** el redirect decide por `restoring`/`noSession`+marca/`locked`/`unlocked`; no se
  registra ninguna clave ni token en ningún punto del arranque.
- **Pruebas:** `app/test/features/auth/startup_routing_test.dart` (sesión guardada → `/unlock`; sin
  red con sesión → `/unlock`; sin sesión primera vez → `/onboarding`; introducción vista →
  `/welcome`; tras desbloquear → `/notes`) y `app/test/router/router_test.dart` (arranque → splash).

### 2026-10-15 · Fase 11.1 · Maqueta de Ajustes y navegación

- **Primero maqueta, después servicios** (estrategia obligatoria de la fase 11): las pantallas de
  Ajustes se montan con datos de muestra en memoria (`features/settings/state/settings_mock.dart`) y
  sin servicios; los interruptores y las opciones cambian estado local, «Cerrar sesión» usa el
  cierre de sesión real y el resto de acciones avisan de su subfase. Las puertas y el patrón de la
  fase 10 se repiten: tokens, goldens claro/oscuro y comparación geométrica (±4 px por banda) contra
  los tableros de Pencil.
- **`/settings/menu` no tiene tablero** en «Movil v2»: se reproduce el menú de secciones de
  `notify_web/.../settings/menu` (ocho filas) y se anota en el informe.
- **«Eliminar cuenta»: el tablero pide escribir «ELIMINAR», pero la app pide la contraseña.** El
  contrato (`POST /me/delete`, `authKey`) y la §7 (operaciones sensibles piden contraseña) mandan
  sobre el tablero; la maquetación es la del tablero salvo el texto de la confirmación. Anotado en
  `docs/design/fase11-comparacion.md`.
- **Tokens**: se añaden las medidas de las filas de ajustes (52/54/46/66), el avatar (56), el
  logotipo (72) y la barra de uso (8). El interruptor tiene un tap target de 44 que **no** debe
  hinchar la fila: la fila fija su altura y el control se centra.
- **Navegación**: `goBack`/`canGoBack` y `PopScope` en el armazón de Ajustes; botón «atrás» con
  tooltip «Atrás» para las pruebas. Todo con `push`; nada de `go` que deje al usuario atrapado.

### 2026-10-15 · Fase 11.2 · Cuenta sobre la UI aprobada

- **Servicios sobre la maqueta, sin cambiar el aspecto.** El dominio gana `Device`/`DevicePlatform`/
  `StorageUsage` y los métodos de cuenta en `AuthRepository` (`updateProfile`, `requestEmailChange`,
  `confirmEmailChange`, `changePassword`, `deleteAccount`), más `DeviceRepository` y
  `StorageRepository`. La UI de 11.1 se conserva; solo se conecta a los servicios.
- **`DevicePlatform` duplicado:** el dominio define su enum y `axonote_api` ya tenía el suyo;
  `auth_api.dart` (que importa ambos) usa ahora `import '...axonote_domain.dart' hide
  DevicePlatform` para quedarse con el del DTO. Anotado aquí porque toca `axonote_api`.
- **Cambio de contraseña:** la clave maestra no cambia; `axonote_crypto.changePasswordKeys` la
  re-cifra con la contraseña nueva y sube `keysVersion` (las notas no se vuelven a cifrar). El
  controlador nunca registra la contraseña ni la clave.
- **Borrar cuenta** exige la contraseña (`POST /me/delete`, `authKey`); al terminar se cierra la
  sesión local y el router vuelve a la bienvenida. (El tablero pedía escribir «ELIMINAR»; manda el
  contrato.)
- **Golden de «Almacenamiento»:** se regeneró porque la barra usa el porcentaje real
  (180 MB / 1 GB = 0,1758) en vez del 0,18 de la muestra. El resto de goldens de 11.1 no cambian.

### 2026-10-15 · Fase 11.2b · Ajustes de Generales/Privacidad/Sincronización reales

- **Las preferencias de la app son locales por cuenta, no sincronizadas.** La web las guarda en
  `localStorage` (`LocalSettingsRepository`), no en `/settings`; el móvil hace lo mismo en el
  almacén seguro (`AccountSecureStore`, clave `appSettings.<userId>`), reutilizando
  `VaultPrefsRepository`. La carga ocurre en el arranque en frío.
- **Tema y tamaño de letra con efecto real.** `themeMode` sale de `settingsProvider`; el tamaño se
  aplica con `textScaler` (0,9 / 1,0 / 1,15). `medium` = 1,0 para no mover los goldens.
- **Bloqueo y sincronización: reutilizar, no duplicar.** El bloqueo usa `VaultLockController` +
  `VaultPrefsRepository`; la sincronización usa `SyncSettings` (tabla `meta` de la base local), que
  el motor ya respeta.
- **«Cifrar notas en este dispositivo» pasa a informativo.** La base local va cifrada siempre
  (§6, fases 5/6): no hay un interruptor que la active o desactive. Se quita el interruptor falso y
  se deja una fila de descripción; la golden de Privacidad se regenera por ese cambio (el resto no).
- **«Abrir con una nota nueva» y «Mostrar vista previa en la lista» se cablean** (antes eran
  interruptores de la maqueta) para no dejar interruptores falsos. «Solo con Wi-Fi» ya lo respeta
  el motor.
- **Contadores reales:** 2FA desde `GET /mfa` (`AuthRepository.mfaStatus`) y sesiones desde
  `/devices`.

### 2026-10-15 · Fase 11.3 · Verificación en dos pasos y rotación de clave

- **Pantalla propia para 2FA** (`/settings/two-factor`) porque el tablero móvil no la trae: activar
  (QR + secreto + código), desactivar y regenerar códigos, con contraseña + código en las sensibles.
- **QR sin `qr_flutter`**: se pinta la matriz del paquete `qr` (declarado en `app/pubspec.yaml`).
- **Rotación de clave de recuperación** reutiliza `axonote_crypto.rotateRecoveryKeys` y
  `PUT /keys/recovery`; se muestra una sola vez.
- **Desviación de diseño**: el tablero de Privacidad no incluye «Clave de recuperación»; la app la
  añade (lo pide el plan/web) y esa zona queda fuera de la puerta de bandas de Privacidad.




### 2026-10-15 · Fase 11.4 · Enlaces públicos y «Compartir»

- **La clave del enlace se envuelve con `Vault.requireKey()`.** El plan §5.1 solo prevé que la clave
  maestra salga de memoria para las claves de elemento; el enlace es el mismo caso: la web envuelve
  la clave del enlace con `vault.requireKey()` (`share-codec.ts`). Se reutiliza ese método (no se
  añade `Vault.wrapWithMaster`): la copia se cifra con una clave propia del enlace y esa clave se
  guarda envuelta con la maestra, ligada a `apunte/v1/sharekey/<userId>/<noteId>`.
- **`SHARE_ORIGIN` por `--dart-define`** (plan §4.5), por defecto `https://apunte.app` (el de la
  web de producción). La URL es `<origen>/n/<slug>#k=<clave>`; la clave va en el fragmento.
- **Sin `beforeCreate`**: la web sube la nota antes de crear el enlace; el móvil no lo necesita
  (el enlace es un recurso aparte y `createLink` no depende de que la nota esté sincronizada).
- **Republicar al guardar:** el guardado del editor (400 ms) actualiza la copia pública si la nota
  tiene enlace (§8.3, plan §385). Es best-effort: un fallo se reintenta con la siguiente edición.
- La hoja sigue el tablero «Android — Compartir nota»; se añade «Compartir» al menú contextual.

### 2026-10-15 · Fase 11.5 · Importar/exportar Markdown

- **Dependencias nuevas: `file_picker ^13.1.0` y `archive ^4.4.0`.** `file_picker` resuelve sin
  tocar `win32` (6.4.0) ni `dbus` (0.8.0), que ya venían transitivos: no hubo el choque que obligó a
  retirar `file_picker` del `appflowy_editor` vendorizado. Se usa la API estática de 13.x
  (`FilePicker.pickFiles` / `FilePicker.saveFile`, con `bytes`), así que no hace falta canal de
  plataforma propio.
- **Las reglas de importación son de dominio** (`axonote_domain/markdown_import.dart`, portadas de
  `markdown-import.ts`): título de la primera línea `# …` o del nombre del archivo, ≤ 200
  caracteres, ≤ 2 MB por archivo, BOM y CRLF normalizados.
- **Exportar todas** produce un `.zip` con un `.md` por nota (`# título\n\ncontenido\n`); exportar
  una nota produce su `.md`. En el zip, los caracteres inválidos de un nombre se cambian por `-` y
  los nombres repetidos se desambiguan (`Nota (2).md`).

### 2026-10-15 · Fase 11.6 · Acerca de y textos legales

- **Los textos legales son datos de dominio** (`axonote_domain/lib/src/legal/`): `LegalDocument`,
  `LegalSection` y bloques sellados (`LegalParagraph`, `LegalList`, `LegalCallout`), portados de
  `notify_web/src/lib/legal/{terms,privacy,changelog,meta}.ts`. La app los pinta en
  `/terms`, `/privacy` y `/changelog`.
- **Licencias de código abierto con la página de Flutter** (`showLicensePage`): las del móvil son
  las de sus paquetes Dart, no las JS de la web; no se porta `licenses.json`.
- **Versión leída del paquete con `package_info_plus`** (dependencia nueva, decisión anotada aquí
  por el plan §9). Si el plugin no responde (pruebas), se cae a la versión del `pubspec`.

### 2026-10-15 · Fase 11.7 · Pendientes de la fase 10 y repaso de la fase 9

- **Estados de conflicto y sincronización en el editor real.** `NoteEditorController` es de solo
  lectura si la nota está en conflicto; la pantalla del editor abre la hoja de conflicto (la misma
  de la fase 9) para la nota abierta y muestra la barra «Sincronizando…» cuando el motor sincroniza.
- **La barra «Sincronizando» pasa dentro del `Scaffold` del editor** (bajo la barra superior), en
  vez de por encima: se unifica con la maqueta y se regeneran sus dos goldens.
- **Repaso de la fase 9 contra «Movil v2».** Se comprobó que los fondos y los tokens clave de las
  pantallas de la fase 9 coinciden con los tableros (p. ej. `bgApp` claro `#F6F2EA` y oscuro
  `#1B1A18`, muestreados en los PNG de Pencil). No se encontraron diferencias de token/estilo que
  corregir. Detalle en `docs/design/fase11-comparacion.md`.
