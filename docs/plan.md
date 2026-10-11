# Plan 0007 · App móvil de AxoNote (Flutter, Android)

Estado: **aprobado, sin ejecutar**. Fecha: 2026-10-09.
Sustituye a `docs/handoff/movil.md` (queda como contexto histórico; donde difieran, manda este plan).
Contrato: `docs/api/openapi.yaml`. Protocolo: ADR 0004. Cifrado: ADR 0005. Acceso: ADR 0006.

---

## 0. Cómo se ejecuta este documento

Este plan lo ejecuta un agente de código, fase por fase. Las decisiones de la §2 están **cerradas**.

1. Una fase por rama (`fase-N-nombre`) y por sesión. No se empieza una fase sin cerrar la anterior.
2. Una fase está cerrada solo cuando se cumple **todo** su «Hecho cuando» y las puertas de calidad de la §11.
3. No se cambia una decisión de la §2. Si algo la hace imposible, se aplica la alternativa ya escrita en
   la §12. Si no hay alternativa escrita: parar, describir el bloqueo en `docs/blockers.md` y esperar.
4. Nunca se debilita una prueba ni un vector para que pase. Si un vector falla, el código está mal.
5. Nunca se registran (logs, excepciones, analítica, capturas) contraseñas, claves, tokens, códigos ni
   texto de notas. Tampoco en modo debug.
6. `notify_backend` no se toca. `notify_web` solo se toca en la fase 1.
7. La referencia de comportamiento es el código de `notify_web`. Ante una duda de comportamiento se lee
   el archivo TypeScript citado en cada fase; no se inventa.
8. Textos de interfaz en español, tomados de `notify_web/src/lib/core/messages.ts` cuando existan.
9. Commits pequeños, uno por tarea, mensaje en español en imperativo.

---

## 1. Objetivo y alcance

App Android nativa en Flutter con **paridad funcional con la web**, salvo lo listado como fuera de alcance.
Lee y escribe exactamente el mismo formato cifrado y el mismo protocolo de sincronización.

**Dentro (v1)**

- Cuenta: bienvenida, registro, código por correo, clave de recuperación, inicio de sesión, segundo paso
  (TOTP o código de respaldo), desbloqueo, «olvidé mi contraseña» (solo la solicitud).
- Notas: lista con grupos, carpetas, etiquetas, fijar, duplicar, mover, papelera (30 días), búsqueda local.
- Editor Markdown nativo con el mismo conjunto de formatos que la web.
- Sincronización con cola local, conflictos y lápidas.
- Enlaces públicos: crear, copiar, actualizar al editar, revocar.
- Ajustes: general, cuenta (nombre, correo, contraseña, clave de recuperación, borrar cuenta),
  privacidad y bloqueo, sincronización, almacenamiento (uso, importar y exportar Markdown),
  verificación en dos pasos (activar, desactivar, regenerar códigos), dispositivos, acerca de y legales.
- Tema claro y oscuro, tamaño de texto, accesibilidad con TalkBack.

**Fuera (v1)** — no se implementa ni se deja a medias

| Fuera | Motivo | Qué hace la app mientras tanto |
| --- | --- | --- |
| iOS | Decisión D1 | — |
| Acceso con Google y dispositivos de confianza | D5; ADR 0006 los deja fuera en apps nativas | El botón no aparece |
| Abrir en la app los enlaces del correo y los enlaces compartidos (App Links) | No hay dominio | Se abren en la web |
| Completar el restablecimiento de contraseña | Llega por enlace de correo | Se completa en la web |
| Sincronización en segundo plano | D7 | Sincroniza con la app abierta |
| Publicación en Play Store | No hay cuenta de desarrollador | Fase 13, opcional |
| Fijación de certificado (pinning) | No hay dominio definitivo | TLS estándar |

---

## 2. Decisiones cerradas

| # | Tema | Decisión |
| --- | --- | --- |
| D1 | Plataforma | Solo Android. `minSdk 26` (Android 8). |
| D2 | Editor | Nativo, con códec Markdown propio y conservación por bloque (§8). |
| D3 | Almacenamiento local | Base SQLite cifrada entera; dentro, contenido descifrado e índice FTS5 (§6). |
| D4 | Desbloqueo | Contraseña solo al iniciar sesión; después, clave maestra en Android Keystore abierta con biometría o credencial del teléfono (§5). |
| D5 | Google | Fuera de la v1. |
| D6 | Alcance | Paridad con la web menos lo de la tabla «Fuera». |
| D7 | Sincronización | Solo en primer plano: al desbloquear, 3 s después de un cambio, cada 60 s y al recuperar la red. |
| D8 | Entornos | Desarrollo contra el backend local por USB (`adb reverse`). QA con token de servicio de Cloudflare Access solo en builds de desarrollo. |
| D9 | Estado y navegación | Riverpod 3 (clases `Notifier`/`AsyncNotifier` escritas a mano, sin generador) y `go_router`. |
| D10 | Base de datos | `drift` sobre el paquete `sqlite3` con **SQLite3MultipleCiphers** (`hooks.user_defines.sqlite3.source: sqlite3mc`). |
| D11 | Argon2id | **libsodium** con el paquete `sodium` (`crypto_pwhash`, `argon2id13`), en un isolate. |
| D12 | AES-GCM y HKDF | Paquete `cryptography` (con `cryptography_flutter` para usar la implementación nativa). |
| D13 | Cliente HTTP | `dio`, escrito a mano. Modelos con clases `sealed` de Dart 3 y `fromJson` manual; sin `freezed`. |
| D14 | Contrato y vectores | Copiados al repo móvil con `tool/sync_contract.sh`; la CI falla si difieren de `notify_web`. |
| D15 | Vectores nuevos | Antes del móvil se añaden en `notify_web`: `markdown.json` y `sync-behavior.json` (fase 1). |
| D16 | Diseño | Penpot, archivo «Apunte – App de notas», por el MCP de Penpot. Material 3 solo como base técnica; el aspecto lo dictan los tokens y las pantallas del diseño. |
| D17 | Android mínimo | API 26. `targetSdk` y `compileSdk`: los que traiga Flutter estable. |
| D18 | Repositorio | `notify_mobile`, carpeta hermana de `notify_web` y `notify_backend`. Identificador provisional `com.axonote.app`. |

**Cambio respecto a lo conversado (D10 y D11).** Se verificó en pub.dev el 2026-10-09:
`sqlcipher_flutter_libs` está marcado como fin de vida y drift ≥ 2.32 cifra con SQLite3MultipleCiphers;
`dargon2_flutter` no se publica desde 2023. Por eso D10 usa `sqlite3mc` y D11 usa libsodium.
libsodium fija el paralelismo de Argon2id en 1, que es el valor actual del servidor. Regla: si el
servidor entrega `parallelism != 1` o `alg != 'argon2id'`, la app muestra «Actualiza AxoNote para
iniciar sesión» y no intenta derivar.

**Decisiones derivadas**

| # | Decisión |
| --- | --- |
| A1 | Un archivo de base por cuenta: `axonote_<userId>.db`. Cerrar sesión o recibir `device-revoked` lo borra junto con todas las claves locales. |
| A2 | La clave de la base se deriva de la clave maestra: `HKDF-SHA256(MK, sal = 32 ceros, info = "apunte/v1/local-db/<userId>", 32 B)`. Etiqueta solo local; nunca viaja. Sin clave maestra no se abre la base. |
| A3 | Con la app bloqueada no hay base abierta ni sincronización. (La web sincroniza bloqueada porque guarda cifrado; aquí no hace falta.) |
| A4 | La cola de cambios guarda **referencias** (entidad, id, operación, revisión base, versión), no datos. El cifrado del elemento se hace al enviar, desde la fila actual. |
| A5 | Cada fila guarda su `wrapped_key` para reutilizar la clave del elemento (igual que la web). |
| A6 | Una nota o carpeta que no se puede descifrar se guarda con `unreadable = 1` y su texto cifrado original en `raw_payload`; no se puede editar ni se vuelve a subir. |
| A7 | Búsqueda con FTS5 (`unicode61 remove_diacritics 2`, prefijos). Sin tolerancia a errores de tipeo: diferencia aceptada respecto a la web (MiniSearch difuso). |
| A8 | Todo el código nativo propio (Keystore, biometría, `FLAG_SECURE`) vive en un único módulo Kotlin del repo, `packages/axonote_platform`. No se usan `local_auth` ni plugins de ventana. |
| A9 | Los tokens de sesión y el `KeyBundle` en caché van en `flutter_secure_storage`; la clave maestra **no** (va en el módulo propio, ligada a autenticación). |
| A10 | Abrir una nota no la guarda. Solo se guarda si hubo una edición real, con espera de 400 ms (igual que la web). |

---

## 3. Contrato de compatibilidad (no negociable)

Fuente: `docs/api/vectors/README.md` y los JSON de esa carpeta. Un byte distinto deja notas ilegibles.

- **Contraseña → claves.** `NFKC` → UTF-8 → Argon2id (parámetros y sal del servidor, salida 32 B) →
  HKDF-SHA256 con sal de 32 ceros: `apunte/v1/auth` (32 B, base64url, es `authKey`) y `apunte/v1/kek`.
  Dart no trae NFKC: usar el paquete `unorm_dart`.
- **Clave de recuperación.** 32 B; HKDF `apunte/v1/recovery-auth` y `apunte/v1/recovery-kek`. Texto:
  52 caracteres Crockford base32 + 1 de control (`valor mod 37` sobre `0123456789ABCDEFGHJKMNPQRSTVWXYZ*~$=U`),
  grupos de 4 con `-`. Lectura tolerante: mayúsculas, sin espacios ni guiones, `O→0`, `I/L→1`.
  Referencia: `src/lib/core/crypto/recovery-key.ts` (aritmética de 260 bits: usar `BigInt`).
- **Texto cifrado** `a1.<iv>.<ct>`: AES-256-GCM, IV 12 B, `ct` con etiqueta de 16 B al final, base64url
  sin relleno. Validar con `^a1\.[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]+$` antes de abrir.
- **AAD** (UTF-8): `apunte/v1/mk/{userId}/password|recovery`, `apunte/v1/key/{userId}/{note|folder}/{id}`,
  `apunte/v1/data/{userId}/{note|folder}/{id}`, `apunte/v1/sharekey/{userId}/{noteId}`, `apunte/v1/share/{slug}`.
- **Contenido.** JSON con las claves en este orden: nota `{title, content, tags, pinned}`, carpeta `{name}`,
  enlace `{title, content}`. UTF-8, rellenado con `0x20` hasta el siguiente múltiplo de 256 (mínimo 256).
  Al leer: quitar espacios finales y validar tipos; si falla, es error de descifrado.
- **Identificadores.** UUID v7 generados en el cliente (`src/lib/domain/ids.ts`).
- **Enlace.** `slug` = 16 B aleatorios en base64url (22 caracteres). URL: `<SHARE_ORIGIN>/n/<slug>#k=<clave en base64url, 43 caracteres>`.
- **Sesión.** Sin la cabecera `X-AxoNote-Session`: el `refreshToken` viaja en el cuerpo. El móvil nunca envía esa cabecera.

---

## 4. Arquitectura

### 4.1 Estructura del repositorio (pub workspace)

```
notify_mobile/
  AGENTS.md  CLAUDE.md  README.md
  pubspec.yaml                  # workspace + hooks.user_defines.sqlite3.source: sqlite3mc
  contract/                     # copia verificada de notify_web: openapi.yaml y vectors/*.json
  tool/sync_contract.sh  tool/check_contract.sh
  docs/  plan.md  decisions.md  screens.md  blockers.md  benchmarks.md
  packages/
    axonote_domain/     # Dart puro: entidades, errores, validación, reglas (sin dependencias)
    axonote_crypto/     # Dart puro + sodium: formato a1, KDF, claves, relleno, clave de recuperación
    axonote_markdown/   # Dart puro: modelo de bloques, analizador, serializador
    axonote_api/        # dio: cliente, DTO, mapeo de errores, renovación de sesión
    axonote_sync/       # Dart puro: cola y motor de sincronización sobre interfaces
    axonote_platform/   # plugin Kotlin: Keystore, biometría, FLAG_SECURE
  app/                  # Flutter: datos locales (drift), estado, interfaz
    lib/
      bootstrap/        # raíz de composición, proveedores, configuración por entorno
      data/             # drift (tablas, DAO), repositorios, códec de notas, almacén seguro
      features/<nombre>/{state,ui}/
        auth  vault  notes  folders  search  editor  sync  share  settings  trash  storage
      ui/               # tema, tokens, componentes compartidos, iconos
      router/  l10n/
    test/  integration_test/
```

### 4.2 Reglas de dependencia (se verifican en CI)

```
app ──► axonote_sync ──► axonote_domain
 │  ──► axonote_api  ──► axonote_domain
 │  ──► axonote_crypto (no depende de domain)
 │  ──► axonote_markdown (no depende de nada)
 └──► axonote_platform
```

- Los paquetes puros no importan `package:flutter`.
- `features/*/ui` solo habla con `features/*/state`. El estado solo habla con interfaces de repositorio
  definidas en `axonote_domain`. Nadie fuera de `app/lib/data` importa `drift` ni `dio`.
- Una función no cruza capas: la interfaz no conoce filas de base, DTO ni bytes cifrados.
- Se verifica con un test de arquitectura (`tool/check_imports.dart`) que recorre los `import`.

### 4.3 Estado y errores

- Los repositorios devuelven la entidad o lanzan `AppFailure(AppError)`. `AppError` es una clase `sealed`
  con los mismos `kind` que `src/lib/domain/errors.ts`.
- Las acciones del estado **no lanzan**: devuelven `Result<T>` (`Ok`/`Err`). La interfaz decide por `kind`.
- Listas reactivas: consultas `watch()` de drift expuestas como `StreamProvider`. No hay copia en memoria
  de toda la colección.
- `session-expired` y `device-revoked` se publican en un único canal de eventos de sesión que escucha
  el estado de autenticación.

### 4.4 Concurrencia y rendimiento

- Argon2id: siempre en un isolate.
- Descifrado y cifrado por lotes (primera sincronización, páginas de 500): en un isolate de trabajo de
  larga vida, por páginas, con inserción por lotes en una transacción por página.
- Base de datos: `NativeDatabase.createInBackground` (isolate propio de drift).
- Análisis y serialización de Markdown de notas de más de 50 KB: en isolate.
- Listas: consultas ligeras (sin `content`), `ListView.builder` con alto fijo de tarjeta, columna `preview` precalculada.

### 4.5 Configuración por entorno (`--dart-define`)

| Variable | Desarrollo | QA | Producción |
| --- | --- | --- | --- |
| `API_URL` | `http://localhost:8080/v1` (con `adb reverse tcp:8080 tcp:8080`) | URL de QA | URL de producción |
| `SHARE_ORIGIN` | origen de la web desplegada | ídem QA | ídem producción |
| `CF_ACCESS_ID`, `CF_ACCESS_SECRET` | vacío | token de servicio | **prohibido**: el build de release falla si están definidas |

HTTP en claro solo en el manifiesto de debug y solo para `localhost`.

---

## 5. Seguridad local y ciclo de vida

### 5.1 Qué se guarda y dónde

| Dato | Dónde | Protección |
| --- | --- | --- |
| Clave maestra (32 B) | `axonote_platform`, cifrada con una clave AES-GCM de Android Keystore | Clave no exportable; con biometría activa exige autenticación para usarse |
| Tokens de acceso y renovación | `flutter_secure_storage` | Keystore, sin autenticación (hace falta para saber si hay sesión estando bloqueada) |
| `userId`, correo, `KeyBundle` (claves cifradas y parámetros del KDF) | `flutter_secure_storage` | Permite desbloquear con contraseña sin red |
| Notas, carpetas, cola, conflictos, cursor, ajustes | Base cifrada (A1, A2) | Clave derivada de la maestra |
| Preferencias de bloqueo del dispositivo | `flutter_secure_storage`, por cuenta | No se sincronizan (igual que la web) |

### 5.2 Módulo `axonote_platform` (Kotlin, canal de métodos)

- `storeMasterKey(userId, bytes, requireAuth)`, `loadMasterKey(userId, prompt)`, `deleteMasterKey(userId)`,
  `authAvailability()`, `setSecure(bool)`.
- Clave de Keystore AES-256-GCM por cuenta. Con `requireAuth`: `setUserAuthenticationRequired(true)`,
  `setInvalidatedByBiometricEnrollment(true)`, y `BiometricPrompt` con `CryptoObject`.
  - API ≥ 30: autenticadores `BIOMETRIC_STRONG | DEVICE_CREDENTIAL`. **Enmienda 2026-10-11 (ver
    docs/decisions.md):** con ambos autenticadores a la vez, Android ata la clave al SID raíz de
    la credencial del dispositivo, no solo al biométrico, así que una huella nueva **no** la
    invalida (`setInvalidatedByBiometricEnrollment` solo surte efecto en claves puramente
    biométricas); se acepta como decisión, no como fallo.
  - API 26–29: solo `BIOMETRIC_STRONG`. Sin biometría registrada, `authAvailability()` lo indica y la app
    desbloquea con contraseña. Al ser puramente biométrica en esta franja, aquí sí invalida una
    huella nueva.
- StrongBox si el dispositivo lo ofrece; si no, TEE.
- Si la clave quedó invalidada (se quitó el bloqueo de pantalla seguro del dispositivo, o —solo en
  API 26-29— se registró una huella nueva; enmienda 2026-10-11, ver docs/decisions.md) o falla: se
  borra y se pide la contraseña.

### 5.3 Estados del cofre

```
sin sesión ──login──► desbloqueado ◄──biometría o contraseña── bloqueado
                          │  └──── tiempo de bloqueo / bloquear al salir / manual ────► bloqueado
                          └── cerrar sesión / device-revoked ──► sin sesión (borra base y claves)
```

- **Bloquear** = borrar la clave maestra de memoria, cerrar la base, vaciar el estado en memoria y el
  historial del editor.
- **Desbloquear con biometría**: `loadMasterKey` → derivar clave de base → abrir.
- **Desbloquear con contraseña** (sin red): Argon2id con el `KeyBundle` en caché → abrir la maestra.
- Ajustes que gobiernan esto, con los mismos nombres y valores por defecto que `src/lib/domain/settings.ts`:
  `biometricLock`, `lockOnExit`, `lockTimeout` (`immediately|1m|5m|15m|never`).
  - `biometricLock = true`: la maestra se guarda con `requireAuth = true`.
  - `biometricLock = false`: al bloquear se pide la contraseña. Si además `lockOnExit = false` y
    `lockTimeout = never`, la maestra se guarda con `requireAuth = false` (equivale a la clave de
    dispositivo de la web).
- El tiempo de bloqueo se mide con reloj monótono mientras la app vive y con la hora de la última
  actividad guardada si el sistema mató el proceso.

### 5.4 Endurecimiento de plataforma

- `android:allowBackup="false"` y reglas de extracción de datos que excluyen todo.
- `FLAG_SECURE` siempre en: clave de recuperación, códigos de respaldo, secreto TOTP, desbloqueo.
  En el resto, según el ajuste de privacidad (activado por defecto): oculta la vista previa en recientes.
- El portapapeles marca como sensible lo copiado de pantallas de claves.
- Release con R8 y `--obfuscate --split-debug-info`.
- Cambiar la contraseña desde otro dispositivo invalida esta sesión: se trata como `session-expired`.

---

## 6. Base local (drift)

```
notes(id PK, folder_id NULL, title, content, preview, tags_json, pinned, created_at, updated_at,
      deleted_at NULL, revision, sync_status, last_edited_device_id, wrapped_key,
      unreadable DEFAULT 0, raw_payload NULL)
note_tags(note_id, tag, PK(note_id, tag))
folders(id PK, name, created_at, updated_at, revision, wrapped_key, unreadable DEFAULT 0, raw_payload NULL)
outbox(seq PK AUTOINCREMENT, entity, entity_id, op, base_revision, version, changed_at, UNIQUE(entity, entity_id))
conflicts(note_id PK, remote_json, remote_wrapped_key, remote_revision, remote_device_name, detected_at)
shares(note_id PK, slug, wrapped_share_key, created_at, updated_at)
meta(key PK, value)            -- cursor, lastSyncedAt, deviceId, ajustes en caché
notes_fts  -- FTS5 de contenido externo sobre notes(title, content, tags), con disparadores
```

- Índices: `notes(deleted_at, pinned, updated_at)`, `notes(folder_id, deleted_at)`, `note_tags(tag)`.
- Fechas como texto ISO 8601 UTC con milisegundos, idénticas a las del contrato (no se convierten a entero:
  deben volver al servidor igual que llegaron).
- `preview` y `note_tags` se calculan al escribir, con las reglas de `src/lib/domain/note-text.ts`.
- Migraciones de drift versionadas desde la 1, con prueba de migración por versión.
- Las reglas de negocio de notas y carpetas se portan de `src/lib/data/local/local-note-repository.ts`
  y `local-folder-repository.ts` (duplicar, papelera, borrar carpeta deja las notas sin carpeta, etc.).

---

## 7. Motor de sincronización (`axonote_sync`)

Dart puro sobre tres interfaces: `SyncStore` (transacciones sobre la base), `SyncTransport` (`POST /sync`)
y `ItemCodec` (cifrar y descifrar un elemento). Referencias: `src/lib/data/local/outbox.ts` y
`local-sync-repository.ts`. El comportamiento lo fijan los vectores `sync-behavior.json`.

**Cola (una entrada por entidad)**

- Sin entrada previa: `delete` con `baseRevision 0` no encola nada; el resto encola con `version 1`.
- Con entrada previa y `delete`: si su `baseRevision` es 0, se quita la entrada; si no, pasa a `delete`.
- Con entrada previa y `upsert`: sigue siendo una entrada, conserva el `baseRevision` más antiguo, `version + 1`.

**Ciclo `syncNow()`** (una sola ejecución a la vez; una segunda llamada espera a la primera)

1. Tomar la cola en orden de `seq`, sin las notas que están en `conflicts`.
2. Cifrar cada elemento desde su fila actual y enviar con el `cursor` guardado (`null` la primera vez).
3. Aplicar la respuesta en **una transacción**:
   - `applied`: fijar `revision`. Si la `version` de la entrada es la enviada, borrar la entrada y marcar
     `synced`; si cambió mientras se sincronizaba, dejarla con `baseRevision = revision` nueva y `pending`.
   - `conflicts`: guardar la versión remota (descifrada) y marcar la nota `conflict`.
   - `remoteChanges`: en notas, si hay conflicto abierto se actualiza su versión remota; si hay cambio
     local pendiente **no se pisa**; borrado remoto borra nota y conflicto; si no, se guarda como `synced`.
     En carpetas: un cambio pendiente local gana salvo que el remoto sea un borrado.
   - Guardar `cursor` y `lastSyncedAt`.
4. Mientras `hasMore` sea verdadero, repetir **sin cambios que subir**. Tope: 100 páginas.

**Resolver un conflicto**: `remote` (queda la versión del servidor, se descarta la entrada), `local` (la
nota toma la revisión remota y la entrada su `baseRevision`), `both` (lo local pasa a una nota nueva
«<título> (conflicto)», sin fijar, con id y clave nuevos; la original toma la versión remota).

**Disparadores** (D7): al desbloquear; 3 s después del último cambio local; cada 60 s; al recuperar la
red (`connectivity_plus`). Respetan `autoSync` y `wifiOnly`. Reintentos con espera exponencial (2 s → 60 s)
ante `network` y `server`; `rate-limited` respeta `retryAfterSec`.

**Errores**: `session-expired` → una renovación y un reintento; `device-revoked` → borrado local (A1) y
pantalla de inicio de sesión; `forbidden/quota-exceeded` y `limit-reached` → aviso persistente, la cola se conserva.

---

## 8. Editor Markdown nativo

### 8.1 Formato real

El campo `content` es lo que emite TipTap 3 en la web con `StarterKit` + `TaskList` + `TaskItem` anidado
(`src/lib/components/app/note-editor.svelte`). Conjunto que el móvil edita: párrafo, títulos 1–6,
negrita, cursiva, tachado, **subrayado** (`++texto++`, sintaxis propia de TipTap), código en línea,
enlace, lista con viñetas, lista numerada, lista de tareas (anidadas), cita, bloque de código, separador
y salto de línea duro. Todo lo demás es **bloque opaco**.

Hechos comprobados el 2026-10-10 ejecutando el serializador real (no son CommonMark estándar; el
analizador y el serializador del móvil deben reproducirlos, y la fase 1b los fija como vectores):

- **Las líneas en blanco de más son contenido.** Un párrafo vacío entre `a` y `b` se guarda como
  `a\n\n\n\nb`; dos seguidos, con `&nbsp;` en medio; uno al final, como `a\n\n`. El paquete `markdown`
  de Dart las descarta: el analizador propio debe contarlas y crear párrafos vacíos.
- **`<`, `>` y `&` siempre salen como entidades** (`&lt;`, `&gt;`, `&amp;`), en cualquier posición.
- **Escapes** con `\` de `* _ \` [ ] ~ \\` cuando son texto literal; `#`, `-` y `1.` al inicio de línea
  **no** se escapan (limitación de la web, ver §12).
- **Normalizaciones al leer:** `*`/`+` → `-`; `_x_` → `*x*`; `__x__` → `**x**`; título con subrayado →
  `#`; sangría de 4 espacios o tabulador → 2 espacios; `1)` → `1.`; `***`/`___` → `---`; CRLF → LF;
  salto final eliminado; URL suelta → `[url](url)`; salto duro con `\` → dos espacios.
- Una lista de tareas y una de viñetas contiguas se separan con una línea en blanco.
- **La web destruye lo que no entiende:** una tabla desaparece, una imagen queda en su texto alternativo,
  el HTML se convierte en texto con entidades y una nota al pie se deforma. El móvil lo conserva como
  bloque opaco, pero la web lo perderá al editar esa nota (ver §12).

### 8.2 Piezas

1. **Modelo de bloques** (`axonote_markdown`, independiente del editor): `Paragraph`, `Heading`,
   `BulletList`, `OrderedList`, `TaskList`, `Quote`, `CodeBlock`, `Divider`, `Opaque`. Cada bloque de
   primer nivel conserva `source` (su texto original exacto) y el separador que lo sigue.
2. **Analizador** sobre el paquete `markdown`, con posiciones de origen para recortar `source`.
3. **Serializador** escrito a mano que reproduce la salida de TipTap. Las reglas exactas (marcadores,
   sangría, líneas en blanco, escapes, numeración) **se toman de `markdown.json`**, no se suponen.
4. **Conservación por bloque.** Al cargar se calcula una huella estructural de cada bloque. Al guardar:
   bloque con la misma huella → se emite su `source` byte a byte; bloque cambiado, nuevo o movido →
   pasa por el serializador. Separadores originales entre bloques intactos; `\n\n` en los demás casos.
   Los párrafos vacíos son bloques (§8.1), no separadores.
5. **Bloque opaco**: lo que el analizador no reconoce (tablas, HTML, imágenes, notas al pie) se muestra
   como tarjeta de solo lectura con su texto y se emite siempre intacto.
6. **Adaptador al editor** (`app/lib/features/editor`): `appflowy_editor`. Convierte bloques ↔ nodos
   (en AppFlowy cada elemento de lista es un nodo hermano: el adaptador agrupa los consecutivos).
   El códec no importa `appflowy_editor`.
7. **Interfaz**: barra de formato sobre el teclado (estilo de párrafo, negrita, cursiva, lista, tareas,
   deshacer), título como campo aparte, etiquetas, marca de guardado y de sincronización.

### 8.3 Reglas

- Abrir no guarda (A10). Guardado con espera de 400 ms y al salir de la pantalla o ir a segundo plano.
- Nota `unreadable` o en conflicto: solo lectura.
- Si la nota tiene enlace público, guardar actualiza también la copia del enlace.
- Una nota que llega por sincronización mientras está abierta y sin cambios locales se recarga; con
  cambios locales, no se toca (lo resolverá el conflicto).

---

## 9. Dependencias

Versiones comprobadas en pub.dev el 2026-10-09. Se instalan las últimas estables compatibles y se fija
`pubspec.lock` en el repo. Flutter estable: 3.47.x (Dart 3.13).

| Paquete | Versión vista | Uso |
| --- | --- | --- |
| `flutter_riverpod` | 3.4.3 | Estado |
| `go_router` | 18.0.2 | Navegación |
| `drift` + `sqlite3` | 2.35.2 | Base local cifrada (sqlite3mc por hooks) |
| `sodium` | 4.0.x | Argon2id (`sodium_libs` está descontinuado: no usar) |
| `cryptography`, `cryptography_flutter` | 2.9.0 / 2.3.4 | AES-GCM, HKDF |
| `unorm_dart` | última | NFKC |
| `dio` | 5.11.1 | HTTP |
| `flutter_secure_storage` | 11.2.0 | Tokens y `KeyBundle` |
| `appflowy_editor` | 6.2.0 (dic 2025) | Editor |
| `markdown` | 7.3.1 | Análisis de Markdown |
| `connectivity_plus` | 7.3.2 | Red |
| `share_plus`, `file_picker` | 13.3.1 / 13.1.0 | Compartir enlace, exportar e importar |
| `qr_flutter` | 4.1.0 | QR del secreto TOTP |

No se añade ninguna dependencia fuera de esta tabla sin anotarla en `docs/decisions.md` con su motivo.

---

## 10. Fases

Esfuerzo en semanas de una persona; un agente lo recorre más rápido, el orden no cambia.

### Fase 0 · Entorno y comprobaciones (0,5 sem)

Requiere a la persona: instalar Flutter estable y el SDK de Android en la máquina (hoy no están: no hay
`flutter`, `dart` ni `adb`), activar la depuración USB en el ZTE (Android 13) y conectar Penpot al MCP.

1. Crear `notify_mobile/` (git, rama `main`), workspace, `AGENTS.md` y `CLAUDE.md` derivados de la §0,
   copiar este plan a `docs/plan.md`.
2. App vacía corriendo en el teléfono por USB.
3. **Comprobación de dependencias** (una app de prueba desechable que compila y ejecuta en el teléfono):
   - `sodium`: Argon2id con `kdf.json` (parámetros reales) da el `authKey` esperado. Medir el tiempo.
   - `drift` + `sqlite3mc`: `PRAGMA cipher` responde; `PRAGMA compile_options` incluye `ENABLE_FTS5`;
     abrir con clave, cerrar, reabrir con clave errónea falla.
   - `appflowy_editor` compila y edita con el Flutter estable actual.
   - `cryptography`: un caso de `sealed.json` abre.
4. Anotar resultados y tiempos en `docs/benchmarks.md`.

**Hecho cuando:** las cuatro comprobaciones pasan en el ZTE, o se aplicó la alternativa de la §12 y quedó
anotada en `docs/decisions.md`. Argon2id real ≤ 3 s en el ZTE.

### Fase 1 · Vectores nuevos en `notify_web` (1 sem)

1. Extraer la lista de extensiones del editor a `src/lib/core/editor/extensions.ts`; el componente y el
   generador usan la misma lista.
2. `docs/api/vectors/markdown.json`: casos `{name, input, canonical, supported}` con
   `canonical = serializar(analizar(input))` usando TipTap sin interfaz. Corpus mínimo: cada tipo de
   bloque y marca; anidación a 3 niveles; tareas marcadas y sin marcar; marcas combinadas; escapes
   (`*`, `_`, `#`, `[`, `\`, `<`, `` ` ``); saltos duros; enlaces con título; bloque de código con
   lenguaje y con comillas invertidas dentro; lista numerada que no empieza en 1; nota vacía; solo
   espacios; emoji y texto no latino; HTML en línea; tabla; imagen; y las notas de
   `src/lib/data/mock/fixtures/notes.ts`. Prueba web: `canonical` es idempotente.
3. `docs/api/vectors/sync-behavior.json`: escenarios `{name, initial, steps[], expected[]}` generados
   ejecutando `outbox.ts` + `LocalSyncRepository` + `MockSyncServer` con reloj e identificadores fijos.
   El estado se expresa en campos lógicos (id, revisión, estado, cola, conflictos, cursor), no en bytes
   cifrados. Cubrir: fusiones de la cola; crear+borrar; editar durante la sincronización; conflicto y sus
   tres resoluciones; cambio remoto con pendiente local; borrado remoto; carpeta «gana el último»;
   paginación con `hasMore`; lápidas; carpeta antes que nota.
4. `kdf.json`: añadir, si no existe, un caso con contraseña no ASCII que cambie bajo NFKC.
5. Actualizar `docs/api/vectors/README.md` y `pnpm vectors:generate`; las pruebas web verifican los nuevos.

**Hecho cuando:** `pnpm vectors:generate` es determinista, `pnpm test:unit --run` pasa y el PR está fusionado en `notify_web`.

### Fase 1b · Ampliación de vectores en `notify_web` (1 sem) — debe estar cerrada antes de la fase 7

La revisión de la fase 1 (2026-10-10) encontró que los vectores son correctos y deterministas pero no
bastan para lo que el móvil tiene que reproducir. Esta fase los completa. Solo toca `notify_web`.

1. **`markdown.json`, sentido documento → Markdown.** Hoy solo hay `analizar → serializar` sobre entradas
   mínimas; el móvil necesita saber qué emite TipTap para un documento **editado**. Añadir `serialize`:
   casos `{name, doc, markdown, reparses}` con `doc` en JSON de TipTap, `markdown = serializar(doc)` y
   `reparses = analizar(markdown)` equivale a `doc`. Cubrir como mínimo: párrafos vacíos (uno, dos,
   al final, al inicio); texto literal con cada carácter especial (`* _ \` [ ] ~ \\ < > &`) y al inicio de
   línea (`#`, `-`, `1.`, `>`, `[ ]`, `---`, tres comillas invertidas); espacios al inicio y al final;
   salto duro simple y doble; cada marca sola y todas las combinaciones de dos, en ambos órdenes;
   marca con espacio final (`hola ` en negrita); subrayado; código con comillas invertidas dentro;
   enlace con marcas y con título; elementos vacíos (viñeta, tarea, título, bloque de código);
   listas contiguas (viñetas+viñetas, viñetas+tareas, numerada+viñetas); elemento de lista con dos
   párrafos, con bloque de código y con cita; cita con lista y con varios párrafos; lista numerada
   dentro de viñetas y al revés; tareas a 3 niveles con estados mezclados; título con marcas;
   bloque de código con líneas en blanco y con salto final.
2. **`markdown.json`, más casos de lectura** en `cases`: los de la lista «Normalizaciones al leer» de la
   §8.1, autolinks, entidades (`&copy;`, `&nbsp;`), nota al pie, HTML de bloque, imagen en línea y una
   tabla seguida de texto. Un documento largo que combine todos los bloques.
3. **`sync-behavior.json` reproducible sin servidor.** Hoy los pasos solo dicen `{device, op}`: para
   reproducirlos en Dart habría que reescribir `MockSyncServer`. Cada paso `sync` del dispositivo `a`
   debe llevar `exchanges[]` con, por página, `request` (`cursor`, `changes[{entity, id, op, baseRevision}]`)
   y `response` (`cursor`, `hasMore`, `applied`, `conflicts`, `remoteChanges` en campos lógicos). El
   móvil usa un transporte guionizado: comprueba la petición y devuelve la respuesta grabada.
   `editDuringSync` indica en qué intercambio ocurre la edición.
4. **Escenarios que faltan:** editar y luego borrar una nota ya sincronizada (queda solo el borrado, con
   su revisión base); nota en conflicto que no bloquea el envío de otras; cambio remoto que actualiza un
   conflicto abierto; borrado remoto de una nota en conflicto; carpeta borrada en remoto con cambio
   local pendiente; borrar una carpeta con notas (pasan a «sin carpeta»); mover a la papelera y
   restaurar; resolver `local` y volver a editar antes de sincronizar.
5. Actualizar el README de vectores y las pruebas web (idempotencia donde `reparses` sea verdadero).

**Hecho cuando:** `pnpm vectors:generate` no cambia nada al repetirse, `pnpm test:unit --run` pasa, el PR
está fusionado y `tool/sync_contract.sh` actualizó `contract/` en `notify_mobile`.

### Fase 2 · Esqueleto (1 sem)

1. Paquetes vacíos con sus `pubspec`, `analysis_options.yaml` estricto (`strict-casts`, `strict-inference`,
   `strict-raw-types`, lints recomendados más `avoid_print`, `unawaited_futures`, `prefer_const_*`).
2. `tool/sync_contract.sh`, `tool/check_contract.sh`, `tool/check_imports.dart`.
3. Inventario de Penpot → `docs/screens.md`: cada tablero móvil con su ruta, su fase y sus estados
   (vacío, carga, error, sin conexión). Tokens de color, tipografía, radios y espaciado → `app/lib/ui/tokens.dart`
   (claro y oscuro). Referencia cruzada: `docs/design-tokens.md` y `docs/components.md`. Fuente Inter
   empaquetada; iconos Lucide con trazo 1,75.
4. Tema, componentes base (botón, campo, interruptor, casilla, OTP, tarjeta de nota, hoja inferior,
   elemento de menú, diálogo, aviso) con sus medidas del diseño y pruebas «golden» en claro y oscuro.
5. `go_router` con guardas por estado (sin sesión, bloqueado, desbloqueado) y pantallas vacías.
6. Localización `es` con ARB; mensajes de error por código, portados de `core/messages.ts`.
7. CI en GitHub Actions: formato, análisis, pruebas de todos los paquetes, comprobación de imports y
   de contrato, build de APK de debug.

**Hecho cuando:** la app navega entre pantallas vacías con el tema del diseño en ambos modos y la CI está en verde.

### Fase 3 · `axonote_crypto` (1 sem)

API equivalente a `src/lib/core/crypto` y `src/lib/data/crypto/account-keys.ts`: `b64u`, `seal`, `open`,
`sealWithIv` (solo pruebas), `wrap`, `unwrap`, `pad`, `unpadJson`, `deriveFromPassword`,
`deriveFromRecoveryKey`, `formatRecoveryKey`, `parseRecoveryKey`, `createAccountKeys`,
`unlockWithPassword`, `changePasswordKeys`, `recoverWithRecoveryKey`, `rotateRecoveryKeys`, y los códecs
de nota, carpeta y enlace. Errores: `DecryptError`, `CryptoFormatError`, `KdfUnsupported`.
Las claves viven en un tipo `SecretKeyBytes` que no implementa `toString` útil y se puede borrar.

**Hecho cuando:** pasan al 100 % `kdf`, `sealed` (incluidos los fallos esperados), `wrap`, `padding`,
`recovery-key`, `note-payload` y `share`, y la cobertura del paquete es ≥ 95 %.

### Fase 4 · `axonote_api` (1 sem)

1. Cliente `dio`: tiempo máximo, `Authorization`, mapeo de errores idéntico a `toFailure` de
   `src/lib/data/remote/http-client.ts`, cabeceras de Cloudflare Access solo si están definidas.
2. Renovación de sesión de **vuelo único**: una sola petición a `/auth/refresh` aunque fallen varias a
   la vez; el token nuevo se persiste antes de reintentar; un solo reintento.
3. Todos los endpoints del contrato salvo `google/*` y `trusted-devices/*`. DTO con `fromJson` estricto.
4. Prueba de contrato: cada ruta y método usados existen en `contract/openapi.yaml`.
5. Pruebas de integración contra el backend local (`make up && make run` en `notify_backend`, con
   parámetros ligeros de KDF): registro, verificación, inicio de sesión, renovación, sincronización vacía.

**Hecho cuando:** pruebas unitarias con adaptador simulado y de integración en verde; ningún registro contiene cuerpos ni cabeceras.

### Fase 5 · Seguridad local (1,5 sem)

Módulo `axonote_platform` (§5.2), almacén seguro, `Vault` (clave maestra en memoria, claves de elemento
con caché, bloqueo), gestor de bloqueo (§5.3) y endurecimiento (§5.4).

**Hecho cuando:** pruebas instrumentadas cubren guardar, cargar con biometría, cancelar y borrado;
la app bloquea por tiempo, al salir y manualmente; con la app bloqueada el archivo de base no se
puede abrir. **Enmienda 2026-10-11 (ver docs/decisions.md):** se quita «invalidación por huella
nueva» de este criterio — en el dispositivo de referencia (API ≥ 30) una huella nueva no invalida
la clave, por decisión, no por fallo; en su lugar se cubre que una huella nueva **no** afecta a la
clave guardada.

### Fase 6 · Datos locales (1,5 sem)

Esquema de la §6, DAO, FTS5 con disparadores, repositorios de notas y carpetas con las reglas de la web,
`SyncStore` sobre drift, códec de elemento, borrado total por cuenta (A1), conjunto de datos de prueba
grande (2 000 y 10 000 notas) generado localmente.

**Hecho cuando:** pruebas de repositorio y de migración en verde; con 10 000 notas la lista inicial se
consulta en < 50 ms y una búsqueda en < 100 ms en el ZTE.

### Fase 7 · Sincronización (2 sem)

`axonote_sync` (§7), disparadores, estado de sincronización (`idle|syncing|offline|error`, pendientes,
primer conflicto), primera descarga por páginas en isolate con progreso.

**Hecho cuando:** pasan todos los escenarios de `sync-behavior.json` (con el transporte guionizado de la
fase 1b) y `sync.json`; prueba manual
documentada con la web y el móvil sobre la misma cuenta en el backend local: crear, editar, mover a la
papelera, borrar y generar un conflicto en ambos sentidos, sin pérdida de datos.

### Fase 8 · Cuenta (2 sem)

Bienvenida e introducción, registro con medidor de contraseña, verificación con reenvío y enfriamiento,
clave de recuperación (mostrar una vez, confirmar), inicio de sesión (`prelogin` → KDF con progreso →
`login`), segundo paso, desbloqueo, sesión vencida, solicitud de restablecimiento. Validaciones
portadas de `src/lib/domain/validation.ts`. Dispositivo: nombre del modelo y plataforma `android`.

**Hecho cuando:** una cuenta creada en el móvil abre en la web y al revés, con y sin verificación en dos pasos.

### Fase 9 · Notas (3 sem)

Lista con grupos (reglas de `src/lib/domain/note-groups.ts`), navegación por carpetas y etiquetas,
orden, fijar, duplicar, mover, papelera con días restantes y vaciado, búsqueda con resaltado, acciones
por menú y por gesto, diálogo de conflicto con las tres opciones, estados vacío, carga, error y sin conexión.

**Hecho cuando:** todas las pantallas de notas de `docs/screens.md` coinciden con Penpot en claro y
oscuro; desplazamiento sin cuadros perdidos con 10 000 notas en build de perfil.

### Fase 10 · Editor (6 sem)

1. `axonote_markdown`: modelo, analizador, serializador, conservación por bloque, bloque opaco (3 sem).
2. Adaptador a `appflowy_editor`, barra sobre el teclado, bloque opaco de solo lectura (2 sem).
3. Guardado, recarga por sincronización, enlace público, rendimiento con notas grandes (1 sem).

**Hecho cuando:** (a) para cada caso de `markdown.json`, analizar `canonical` y guardar sin editar
devuelve los mismos bytes; (b) para cada caso `supported`, forzar el serializador sobre todos los
bloques devuelve `canonical`; (b2) cada caso de `serialize` produce su `markdown` byte a byte;
(c) prueba de propiedad: editar el bloque *i* deja idénticos los bytes de
los demás; (d) una nota de 100 KB abre en < 300 ms y se escribe sin retraso perceptible en el ZTE;
(e) ida y vuelta manual web ↔ móvil con cada formato, documentada.

### Fase 11 · Resto de la paridad (3 sem)

Enlaces públicos; ajustes completos; verificación en dos pasos (QR y secreto, activar, desactivar,
regenerar códigos); cambio de nombre, correo y contraseña; rotación de la clave de recuperación; borrar
cuenta; dispositivos (lista y revocar); uso de espacio; importar (`.md`, `.markdown`, `.txt`, hasta 2 MB,
reglas de `src/lib/domain/markdown-import.ts`) y exportar Markdown; acerca de y textos legales.

**Hecho cuando:** cada función de ajustes de la web existe en el móvil salvo las de la tabla «Fuera», y
cada cambio hecho en un cliente se refleja en el otro.

### Fase 12 · Endurecimiento y entrega local (2 sem)

Perfilado contra los presupuestos de la §11; TalkBack en todos los flujos; texto al 200 %; contraste;
revisión de seguridad con la lista de la §5.4 y de `notify_backend/docs/security.md`; build de release
firmado con un almacén de claves local (fuera del repo), instalado en el ZTE; prueba contra QA con el
token de servicio; `README.md` con instalación, ejecución y pruebas.

**Hecho cuando:** APK de release instalado y usado en el ZTE contra QA; todos los presupuestos cumplidos
y anotados en `docs/benchmarks.md`; ninguna tarea abierta en `docs/blockers.md`.

### Fase 13 · Publicación (opcional; requiere dominio y cuenta de Google Play)

Identificador definitivo, App Links (`assetlinks.json` en el dominio de la web), restablecimiento de
contraseña dentro de la app, ficha de privacidad, lanzamiento por pruebas internas.

**Total fases 0–12 (con la 1b): unas 26 semanas de una persona.**

---

## 11. Calidad

**Puertas de cada fase** (también en CI): `dart format --set-exit-if-changed`, `flutter analyze` sin
avisos, todas las pruebas, comprobación de imports, comprobación de contrato, build de APK.

**Pruebas**

| Capa | Tipo | Mínimo |
| --- | --- | --- |
| `axonote_crypto`, `axonote_markdown`, `axonote_sync` | Unitarias con vectores | 95 % de cobertura |
| `axonote_domain`, `axonote_api` | Unitarias | 90 % |
| `app/lib/data` | Unitarias con base en memoria + migraciones | 85 % |
| Estado | Unitarias con repositorios falsos | 80 % |
| Interfaz | «Golden» de componentes y pantallas clave en claro y oscuro | pantallas de `docs/screens.md` |
| Extremo a extremo | `integration_test` contra el backend local | registro → nota → sincronización → bloqueo → desbloqueo |

**Presupuestos de rendimiento** (ZTE con Android 13, build de perfil o release, cuenta con 2 000 notas)

| Medida | Límite |
| --- | --- |
| Arranque en frío hasta la pantalla de desbloqueo | 1,5 s |
| Desbloqueo con biometría hasta ver la lista | 500 ms |
| Argon2id con parámetros reales | 3 s |
| Abrir una nota de 10 KB | 150 ms |
| Búsqueda (por pulsación) | 100 ms |
| Desplazamiento de la lista | sin cuadros > 16 ms en el percentil 99 |
| Primera sincronización de 2 000 notas (red local) | 15 s, con progreso y sin bloquear la interfaz |
| Memoria en reposo con la lista abierta | 200 MB |
| Tamaño del APK (arm64) | 40 MB |

Los límites son objetivos fijados en este plan, no mediciones. Si uno no se alcanza al cerrar la fase 12,
se anota la medida real y la causa en `docs/benchmarks.md`.

---

## 12. Riesgos y alternativas ya decididas

| Riesgo | Se detecta en | Alternativa (sin replanificar) |
| --- | --- | --- |
| `appflowy_editor` no compila con el Flutter estable | Fase 0 | Copiar el paquete a `packages/third_party/appflowy_editor` y corregirlo allí. El códec no depende de él. |
| `sqlite3mc` sin FTS5 | Fase 0 | Búsqueda con tabla de términos propia (`note_terms`) mantenida al escribir. |
| Argon2id > 3 s en el ZTE | Fase 0 | Se acepta hasta 5 s con indicador de progreso. Nunca se bajan parámetros en el cliente. |
| `sodium` no corre en isolate | Fase 0 | Enlace FFI propio a `crypto_pwhash` desde el isolate, con la misma librería empaquetada. |
| `cryptography` es lento en AES-GCM por lotes | Fase 6 | Usar `crypto_aead_aes256gcm` de libsodium si el dispositivo lo admite; si no, se mantiene. |
| TipTap no se puede ejecutar sin interfaz en Node | Fase 1 | Generar `markdown.json` con Playwright sobre una página interna de la web. |
| El serializador no iguala `canonical` en algún caso | Fase 10 | Ese tipo de bloque pasa a `supported: false` y se trata como opaco. Se anota en `docs/decisions.md`. |
| La web borra tablas, imágenes, HTML y notas al pie al editar una nota (comprobado) | Hoy | No bloquea al móvil, que conserva esos bloques. Queda como defecto de `notify_web` a corregir aparte: afecta ya a «Importar notas». |
| La web guarda sin escapar un párrafo que empieza por `#`, `-` o `1.` (al releer cambia de tipo) | Hoy | El móvil replica el comportamiento de la web para no divergir; defecto de `notify_web` a corregir aparte. |
| El servidor sube `parallelism` | Producción | Mensaje «Actualiza AxoNote»; nueva versión con otra librería de Argon2id. |
| Token de renovación gastado tras un cierre brusco | Producción | Se pierde la sesión; se pide iniciar sesión otra vez. La base local se conserva solo si la cuenta coincide. |

---

## 13. Lo que debe aportar la persona

1. Instalar Flutter estable, el SDK de Android y `adb`; activar la depuración USB en el teléfono.
2. Conectar el archivo de Penpot al MCP antes de la fase 2.
3. Antes de la fase 12: URL de la API de QA, token de servicio de Cloudflare Access y origen de la web para `SHARE_ORIGIN`.
4. Antes de la fase 13: dominio y cuenta de Google Play.
