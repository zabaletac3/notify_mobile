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
