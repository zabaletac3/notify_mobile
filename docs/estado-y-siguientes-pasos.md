# AxoNote · Estado del proyecto y siguientes pasos

> Escrito el 2026-10-16 para retomar el trabajo desde otro equipo. Cubre los tres repos
> (`notify_backend`, `notify_web`, `notify_mobile`), lo que falta para dar la **app móvil por completa** y
> cómo empezar las apps de **Linux, Windows e iOS**. Las fuentes de detalle están en `docs/plan.md`,
> `docs/handoff-fase*.md`, `docs/blockers.md` y, para escritorio, en `escritorio.md` (fuera de los repos, ver §6).

## 1. Dónde está todo

| Repo | Rama | Estado |
| --- | --- | --- |
| `notify_backend` (Go) | `main` | Completo hasta MFA/Google (PR #33). Falta desplegar con `GOOGLE_*`. |
| `notify_web` (SvelteKit) | `main` | Completa: cookie HttpOnly opcional, MFA, Google, borrado de cuenta con contraseña, legales, sidebar recogible. |
| `notify_mobile` (Flutter, Android) | `main` | Fases 0–12 mergeadas (PR #9, #10, #11). |

Nada queda sin commitear en los tres repos. Lo único fuera de git son `.qwen/` (configuración local de
Qwen) y la carpeta de apuntes `/home/cristian/repositories/notes/*.md`, que **no es un repositorio** y
contiene además credenciales (claves de recuperación, códigos de respaldo, `google-oauth-credential.json`,
`id_aws`): esas nunca deben subirse a Git.

## 2. Lo hecho

### Backend y web
- Contrato de rutas con prueba (opción B), `POST /me/delete` con contraseña (retención 14 días), textos legales
  (`/terms`, `/privacy`), filas de «Acerca de».
- Vectores compartidos (`docs/api/vectors`, copiados en `contract/vectors` del móvil) para cripto, formato `a1.`,
  envoltura de claves, enlaces y Markdown.
- Sesión web en modo `body` (por defecto) o `cookie` (cabecera `X-AxoNote-Session: cookie`, cookie `axonote_rt`
  HttpOnly; exige mismo dominio registrable).
- Verificación en dos pasos (TOTP + 10 códigos de respaldo), acceso con Google (código + PKCE) y dispositivos de
  confianza. Renombrado de «Apunte» a «AxoNote» (las etiquetas criptográficas `apunte/v1/...` NO se renombran).
- CI: govulncheck con Go 1.26.9; el flake `workerd SQLITE_BUSY` de la web se resuelve repitiendo.

### Móvil (Android, Flutter) · fases 0–12
| Fase | Resultado |
| --- | --- |
| 0–2 | Entorno, vectores, esqueleto, sistema de diseño (tokens claro/oscuro, componentes). |
| 3–4 | `axonote_crypto` (Argon2id, HKDF, AES-GCM, clave maestra) y `axonote_api`. |
| 5–7 | Seguridad local (bloqueo, biometría), base local cifrada (drift + sqlite3mc), motor de sincronización. |
| 8 | Cuenta: registro, verificación, clave de recuperación, login con segundo paso, desbloqueo. Arranque en frío que restaura la sesión (bienvenida solo la primera vez). |
| 9 | Notas: lista, carpetas, etiquetas, fijar, duplicar, mover, papelera (30 días), búsqueda, gestos, conflictos, menú lateral. |
| 10 | Editor Markdown (`axonote_markdown` + `appflowy_editor` vendorizado), bloque opaco, barra de formato, tema propio claro/oscuro. |
| 11 | Ajustes completos, cuenta (nombre, correo, contraseña, borrar cuenta, dispositivos, uso), 2FA con QR, rotación de clave de recuperación, enlaces públicos y Compartir, importar/exportar Markdown, Acerca de y legales. |
| 12 | Mediciones en el ZTE, accesibilidad, revisión de seguridad, release firmable, cobertura y README. |

### Mediciones en el ZTE (release/perfil, Android 13)
Cumplen 10 de 11 presupuestos: arranque en frío 469–594 ms (límite 1,5 s), Argon2id 675 ms (3 s), nota de 10 KB
10 ms (150 ms), búsqueda 11 ms (100 ms), primera sincronización de 2 000 notas 6,25 s (15 s), memoria ~181 MB
(200 MB), APK arm64 26,8 MB (40 MB), nota de 100 KB abre en 96 ms. El desplazamiento queda en el filo
(p99 14,7–16,5 ms; el equipo es de 90 Hz). La biometría queda para medición manual.

### Calidad
Formato de CI, `flutter analyze` sin avisos, 482 pruebas en la app y las de cada paquete en verde, comprobación
de imports y de contrato, goldens claro/oscuro, comparación geométrica contra Pencil («Movil v2»).

## 3. Lo que falta para dar la app móvil por completa

Lo que **solo puede hacer el dueño**:
1. **Almacén de claves de release** (fuera del repo) y `key.properties`; firmar el release (`apksigner verify`) e
   instalarlo en el ZTE. Guía: `docs/guides/fase12-firma-release.md`.
2. **Prueba contra QA** con el token de servicio y las URLs de QA; guion en `docs/guides/fase12-prueba-qa.md`.
   El token no se escribe en ningún archivo.
3. **Pruebas manuales en el ZTE** de todo lo no probado en el móvil real: fase 11 completa (Ajustes, cuenta,
   2FA, rotación de clave, Compartir, importar/exportar), biometría y recorrido con TalkBack. Guías en
   `docs/guides/fase11-prueba-manual.md` y `fase12-*`. Evitar «Eliminar cuenta» y rotar la clave con la cuenta real.
4. **Desplegar** backend y web con las variables de Google (`GOOGLE_*`, `PUBLIC_GOOGLE_AUTH`) y decidir el dominio.

Lo que **queda por programar o decidir** (todo opcional o fuera de v1 salvo indicación):
- Repetir la medición del desplazamiento con el dispositivo en reposo (margen estrecho).
- Botón de imagen y selección de imágenes: están fuera (el paquete vendorizado perdió `file_picker`); requieren
  diseño de adjuntos cifrados compartido con la web y el backend.
- Iconos que faltan del diseño (`compose`, `more`, `notes`, `close`, `sidebar`): hoy se usan equivalentes.
- Marca: el diseño dice «Apunte», la app «AxoNote» (decisión documentada).
- Revisión legal de textos y datos (dirección, proveedores, retención de copias, dígito del NIT).
- **Fase 13 (opcional):** identificador definitivo, App Links (`assetlinks.json`), restablecer contraseña dentro de la
  app, ficha de privacidad y lanzamiento por pruebas internas. Requiere dominio propio y cuenta de Google Play.
- Fuera de v1 por decisión: Google y dispositivos de confianza en nativas, pinning de certificado, sincronización
  en segundo plano.
- `DELETE /me` heredado: retirarlo tras 14 días del despliegue (Sunset provisional 2026-11-30).
- Apagar Postgres local si no se usa (`make down-podman`); borrar ramas ya mergeadas.

## 4. Aplicación de escritorio (Linux y Windows) · Tauri 2

La decisión ya está tomada (ADR 0001 de `notify_web`): el escritorio **envuelve la web con Tauri 2**, sin
reescribir la interfaz. Repo nuevo `zabaletac3/notify_desktop` con `notify_web` como submódulo fijado a un tag.
Estimación: 3–4 semanas. El plan completo está en `escritorio.md` (hoy fuera de los repos; ver §6).

| Fase | Contenido |
| --- | --- |
| D0 | Esqueleto Tauri 2, submódulo, `build-web.sh`, ventana, instancia única, iconos, CI Linux + Windows. |
| D1 | Cambios en `notify_web`: `adapter-static` con `fallback` si `PUBLIC_TARGET=desktop`; `SHARE_ORIGIN`/`PUBLIC_API_URL` configurables (hoy `share-codec.ts` fija `https://apunte.app`); `isTauri()`; `TokenStore` y `device-keys` inyectables para usar el llavero; CSP en `tauri.conf.json`. |
| D2 | Backend: añadir `tauri://localhost` y `http://tauri.localhost` a `ALLOWED_ORIGINS` y probar CORS de `/v1/*`. |
| D3 | Llavero del sistema vía comandos Rust (crate `keyring`: Credential Manager en Windows, Secret Service en Linux) para tokens y clave maestra opcional. |
| D4 | Menú nativo, atajos (Ctrl+N, Ctrl+K), aviso sin conexión, bandeja, deep link opcional. |
| D5 | Rendimiento con miles de notas en WebKitGTK (el más lento); Argon2id en Rust opcional con los mismos vectores. |
| D6 | Empaquetado y actualizaciones (`tauri-plugin-updater`, firma ed25519), instalador NSIS con WebView2; AppImage/deb en Linux. |
| D7 | Pruebas de humo con `tauri-driver`; los e2e siguen en la web. |

Prerrequisitos: Rust estable, Node + pnpm; en Linux `webkit2gtk-4.1`, `libayatana-appindicator3` y `librsvg2`;
en Windows, WebView2. Para probar contra un servidor real hace falta QA desplegado. Riesgos: diferencias de
WebKitGTK (TipTap, IndexedDB, Web Locks) y coste y tiempo de la firma en Windows.

Orden recomendado: D1 y D2 primero (son cambios en `notify_web` y `notify_backend`, pequeños y sin riesgo para
las apps actuales), luego D0 y D3.

## 5. iOS

iOS está **fuera de v1 por la decisión D1** del plan móvil. Para empezarlo hay que reabrir esa decisión.
Dos caminos, sin elegir todavía:

| Opción | Qué implica | Contras |
| --- | --- | --- |
| **A. Flutter para iOS** (el mismo `notify_mobile`) | Reutiliza dominio, cripto, sincronización, editor y UI. Hay que revisar los plugins nativos (`sodium`, `sqlite3mc`, `cryptography_flutter`, almacén seguro en Keychain, biometría con Face ID, ocultar contenido en el selector de apps), tests de goldens y el vendorizado de `appflowy_editor`. | Todo el plan y las mediciones están hechos para Android; hay que replicarlos. |
| **B. Tauri 2 móvil** (`notify_desktop` + target iOS) | Reutiliza la web, como en escritorio. | Tauri móvil es más joven; el rendimiento de Argon2id y el editor TipTap en WKWebView hay que medirlos. |

Requisitos en ambos: un Mac con Xcode, cuenta de Apple Developer (de pago) para firmar e instalar fuera del simulador,
e identificador y perfiles de aprovisionamiento. Sin Mac no se puede compilar ni probar. Recomendación: terminar
primero Android y escritorio y decidir iOS cuando exista el Mac y la cuenta.

## 6. Cómo retomar desde casa

1. `git clone`/`git pull` de los tres repos en `main`.
2. Toolchain móvil: Flutter estable (3.47.7 en CI), JDK 17, Android SDK (plataforma 36). El script de entorno
   no se versiona: recrearlo con `JAVA_HOME`, `ANDROID_HOME` y el `PATH` de Flutter. API por defecto del
   móvil: `--dart-define=API_URL=…` y `--dart-define=SHARE_ORIGIN=…`.
3. Pencil: el diseño vive en `~/.pencil/documents/…/axonote.pen` (sección «Movil v2»); no está en Git. Las
   capturas de referencia están en `app/test/design_refs/`.
4. Los apuntes de planificación de la carpeta raíz (`escritorio.md`, `movil.md`, `backend.md`, `frontend.md`,
   `faltantes*.md`, `plan-*.md`) **no están versionados**: copiarlos por separado o subirlos a un repo
   (sin las credenciales).
5. Agentes: OpenCode y Qwen se lanzaron en paneles de Herdr; en casa basta abrirlos en el repo con el plan de
   cada fase como encargo.
