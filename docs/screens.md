# Inventario de pantallas (Penpot → app)

Fuente: archivo de Penpot «Apunte – App de notas», página **App Mobile** (41 tableros, 412×915 px). El
resto de páginas del archivo están vacías. Este inventario mapea cada tablero a su **ruta**, su **fase** de
implementación (§10 del plan) y sus **estados** (vacío, carga, error, sin conexión).

Las rutas replican las de `notify_web` (`src/routes`) salvo donde la versión móvil difiere. Los tokens y
medidas salen de `notify_web/docs/design-tokens.md` y `components.md` (sistema ya validado contra el mismo
diseño; ver `docs/decisions.md`), más lo explorado en Penpot (tableros, tipografía Inter, tamaños).

Editor: se usa el tablero **«3 · Notas — Android — Editor»** como referencia. Diferencias con el tablero
antiguo **«Android — Editor»** (comparado en Penpot): el antiguo tenía **solo las barras** superior y de
estado (botones atrás/compartir/deshacer/más y selector de carpeta), **sin documento ni barra de formato**;
el nuevo añade el **documento** (etiquetas, checklist, viñetas, títulos, título de nota y fecha) y la
**barra de formato**. Se usa el nuevo.

## 1 · Onboarding — Fase 8

| Tablero | Ruta | Estados |
| --- | --- | --- |
| 1 · Onboarding — Bienvenida | `/welcome` | — |
| 1 · Onboarding — Onboarding 1 | `/onboarding` | paso 1/3 |
| 1 · Onboarding — Onboarding 2 | `/onboarding` | paso 2/3 |
| 1 · Onboarding — Onboarding 3 | `/onboarding` | paso 3/3 |

## 2 · Autenticación — Fase 8

| Tablero | Ruta | Estados |
| --- | --- | --- |
| 2 · Autenticación — Registro | `/register` | por defecto, error de validación, cargando |
| 2 · Autenticación — Verificación de correo | `/verify` | por defecto, código incorrecto, reenvío en enfriamiento |
| 2 · Autenticación — Inicio de sesión | `/login` | por defecto, credenciales incorrectas, cargando |
| 2 · Autenticación — Recuperar contraseña (correo) | `/forgot-password` | por defecto, error |
| 2 · Autenticación — Recuperar contraseña (enviado) | `/forgot-password/sent` | — |

## 3 · Notas — Fases 9 y 10

| Tablero | Ruta | Fase | Estados |
| --- | --- | --- | --- |
| 3 · Notas — Lista de notas | `/notes` | 9 | lista, vacío, carga (skeleton), error, sin conexión |
| 3 · Notas — Menú contextual de nota | `/notes` (hoja inferior) | 9 | sobre la lista |
| 3 · Notas — Modal mover nota | `/notes` (diálogo) | 9 | sobre la lista |
| 3 · Notas — Confirmar eliminación | `/notes` (diálogo) | 9 | sobre la lista / editor |
| 3 · Notas — Compartir nota | `/notes/:id/share` | 11 | creando, creado, revocado |
| 3 · Notas — Android — Editor | `/notes/:id` | 10 | normal, conflicto, nota ilegible (solo lectura), sincronizando |

## 4 · Organización — Fase 9

| Tablero | Ruta | Estados |
| --- | --- | --- |
| 4 · Organización — Primera vez (vacío) | `/notes` | estado vacío «sin notas» |
| 4 · Organización — Carpeta vacía | `/folders/:id` | vacío, carga, error |
| 4 · Organización — Papelera | `/trash` | con notas, vacío, días restantes |
| 4 · Organización — Modal nueva carpeta | overlay `/notes` | — |

## 5 · Búsqueda — Fase 9

| Tablero | Ruta | Estados |
| --- | --- | --- |
| 5 · Búsqueda — Resultados de búsqueda | `/search` | resultados, sin conexión |
| 5 · Búsqueda — Búsqueda sin resultados | `/search` | vacío |

## 6 · Ajustes — Fase 11

| Tablero | Ruta | Estados |
| --- | --- | --- |
| 6 · Ajustes — Menú lateral | `/settings/menu` | — |
| 6 · Ajustes — Ajustes generales | `/settings/general` | — |
| 6 · Ajustes — Mi cuenta | `/settings/account` | — |
| 6 · Ajustes — Sincronización y dispositivos | `/settings/sync` | sincronizado, sincronizando, error |
| 6 · Ajustes — Privacidad y seguridad | `/settings/privacy` | — |
| 6 · Ajustes — Almacenamiento y exportación | `/settings/storage` | uso, exportar, importar |
| 6 · Ajustes — Eliminar cuenta | `/settings/delete-account` | confirmación |
| 6 · Ajustes — Acerca de | `/settings/about` | — |

## 7 · Estados y errores — transversal

| Tablero | Uso | Estados |
| --- | --- | --- |
| 7 · Estados y errores — Cargando (skeletons) | cualquier lista/carga | — |
| 7 · Estados y errores — Sin conexión | global | aviso persistente |
| 7 · Estados y errores — Error de servidor | global | aviso + reintento |
| 7 · Estados y errores — Sesión expirada | global | diálogo → inicio de sesión |
| 7 · Estados y errores — Conflicto de sincronización | editor | diálogo de tres opciones |
| 7 · Estados y errores — Toasts | global | avisos efímeros |

## 8 · Modo oscuro — variantes (verificación)

| Tablero | Verifica |
| --- | --- |
| 8 · Modo oscuro — Lista (oscuro) | `/notes` con el set oscuro |
| 8 · Modo oscuro — Editor (oscuro) | `/notes/:id` con el set oscuro |
| 8 · Modo oscuro — Registro (oscuro) | `/register` con el set oscuro |

El tema oscuro se **deriva del set de tokens oscuro** (`Apunte/Color oscuro/Dark`), no de estos tableros;
los tres tableros sirven solo para comprobar el resultado en claro/oscuro.

## 9 · Tienda — fuera de v1 (Fase 13)

| Tablero | Motivo |
| --- | --- |
| 9 · Tienda — Ficha de tienda | Publicación en Play Store: fuera de v1 (§1). Sin ruta, sin componente, sin golden. |

## Fuera de v1

| Pantalla | Motivo |
| --- | --- |
| 2 · Autenticación — Nueva contraseña | El restablecimiento se completa en la web (§1). |

## Sin tablero en Penpot (se construyen con los mismos tokens y componentes base)

Lista del plan (§1) sin tablero propio. Ruta de referencia: la equivalente de `notify_web`. No se inventan
estilos: se componen con los tokens y componentes base.

| Pantalla | Ruta (referencia web) | Fase |
| --- | --- | --- |
| Clave de recuperación (mostrar/crear) | `/recovery-key` (`(auth)`) | 8 |
| Segundo paso del login (TOTP o código de respaldo) | `/two-factor` (`(auth)`) | 8 |
| Desbloqueo del cofre | `/unlock` (`(auth)`) | 8 |
| Verificación en dos pasos (ajustes) | `/settings/two-factor` | 11 |
| Cambio de correo (confirmación por código) | `/settings/account` | 11 |
| Cambio de contraseña | `/settings/account` | 11 |
| Dispositivos (lista y revocar) | `/settings/sync` | 11 |
| Importar notas (`.md`, `.markdown`, `.txt`) | `/settings/storage` | 11 |
| Textos legales (privacidad, términos, licencias, soporte, novedades) | `/(legal)/*` | 11 |

Acceso con Google y dispositivos de confianza: **fuera de v1** (D5); el botón no aparece.
