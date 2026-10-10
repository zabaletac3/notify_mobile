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


