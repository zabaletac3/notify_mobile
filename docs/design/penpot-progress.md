# Extracción de la base visual desde Penpot — progreso

Decisión D16: **manda Penpot**. Archivo «Apunte – App de notas», página **App Mobile**, 41 tableros de
412×915. Penpot es de solo lectura: no se modifica nada.

Estado: **base visual reextraída de Penpot (hecho).** Queda **un** punto abierto: re-renderizar los PNG de
los tableros con un renderizador fiel (ver «Pendiente»).

- Medidas de componentes, tipografía, radios e iconos → [`penpot-measurements.md`](penpot-measurements.md).
- Datos crudos (tokens, colores, tamaños, ids) → [`penpot-extract.json`](penpot-extract.json).
- PNG de los tableros → [`boards/`](boards/README.md).
- Diferencias frente a lo que había (web) → `docs/decisions.md`.

## Qué se extrajo

- **Colores:** los 17+17 tokens (claro/oscuro) coinciden **exactamente** con `tokens.dart`. Colores usados
  no-token: `#b7791f` (resplandor decorativo de las pantallas de auth) y `#4285f4` (logo de Google).
- **Tipografía (Inter):** roles con sus usos y conteos → tabla en `penpot-measurements.md`. Conviven
  tamaños/interlineados distintos por contexto (p. ej. título de auth 28 y título de pantalla 22–24;
  cuerpo de lectura 15/22 y texto de interfaz 15/1.2).
- **Radios, sombras, espaciados** y **10 componentes** medidos (tabla en `penpot-measurements.md`).
- **Iconos:** Lucide con trazo **1,75**; tamaños 11–24 por contexto.
- **Editores:** «Android — Editor» = solo el chasis; «3 · Notas — Android — Editor» = editor completo (lo
  usado). Comparado y anotado.

## Pausas por la regla de conexión (histórico)

1. MCP suspendido por el navegador; dos reintentos de `getPages` fallaron.
2. Reanudado; se extrajeron los colores, pero **6 consultas en paralelo** saturaron el plugin (5 timeouts)
   → cancelar. **Lección:** el plugin atiende **de una en una**.
3. Reanudado; se procesaron los 41 tableros de uno en uno y se volcó el acumulador.
4. Reanudado; se recogieron las medidas de componentes y los SVG de los 41 tableros (vía servidor local) y
   se convirtieron a PNG.

## Fase 8 (2026-10-11): PARADA por regla de Penpot (diseño no leído)

**Regla vigente (sustituye a la anterior):** si el MCP no devuelve un tablero, no se inventa ni se
deduce el diseño (ni de los PNG, ni de la web, ni de memoria) y **no se sigue construyendo ninguna
pantalla**. Se para y se pide reconectar Penpot.

**Estado de la lectura por el MCP en esta sesión:**

| Tablero de la fase 8 | ¿Leído por el MCP? |
| --- | --- |
| 2 · Autenticación — Registro (claro) | **SÍ** (textos y estructura completos) |
| 1 · Onboarding — Bienvenida | **SÍ** (textos y cajas principales) |
| 1 · Onboarding — Onboarding 1 | **SÍ** (textos + ilustración) |
| 1 · Onboarding — Onboarding 2 | **SÍ** (textos + ilustración) |
| 1 · Onboarding — Onboarding 3 | **SÍ** (textos + ilustración) |
| 2 · Autenticación — Verificación de correo | **SÍ** (textos + cajas y casillas OTP) |
| 2 · Autenticación — Inicio de sesión | **SÍ** (textos + tarjeta, campos y botones) |
| 2 · Autenticación — Recuperar contraseña (correo) | **SÍ** (textos + cajas) |
| 2 · Autenticación — Recuperar contraseña (enviado) | **SÍ** (textos + cajas) |
| 7 · Estados y errores — Sesión expirada | **SÍ** (textos del diálogo) |
| 7 · Estados y errores — Error de servidor | **SÍ** (textos) |
| 7 · Estados y errores — Toasts | **SÍ** (textos + 4 toasts 388×41, radio 12) |
| 8 · Modo oscuro — Registro (oscuro) | **SÍ** (textos + cajas; full-screen, sin Google) |

La pestaña respondió a `getPages` y se leyó el tablero **Registro**. Al leer varios tableros en una
misma ejecución y, después, un tablero suelto, llegaron **dos timeouts seguidos** → se canceló la
lectura (regla de conexión). No se reintentó en bucle.

**Segundo intento (tras reconectar, 2026-10-11):** se leyó bien **Bienvenida**; al leer **Onboarding 1**
llegaron **dos timeouts seguidos** (la consulta y su reintento) → se volvió a **parar**. Datos de
Bienvenida ya extraídos: marca «Apunte» 34/700 centrada; eslogan 16/400 `text.secondary`; logo 96×96;
primario «Crear cuenta» y secundario «Ya tengo una cuenta», ambos 362×54; pie legal 12/400 centrado
`text.tertiary`. No se siguió con más tableros.

**Tercer intento (tras reconectar de nuevo, 2026-10-11):** se leyeron, uno a uno, Bienvenida,
Onboarding 1–3 (con ilustraciones), Verificación de correo, Inicio de sesión, Recuperar contraseña
(correo), Recuperar contraseña (enviado), Sesión expirada y Error de servidor. Al pedir **Toasts**
llegaron **dos timeouts seguidos** (la consulta y su reintento) → se **paró**. Quedan sin leer:
**Toasts** y **Registro (oscuro)**.

**Nota de honestidad sobre lo ya escrito:** antes de recibir la regla nueva, se avanzó con pantallas
basadas en los **PNG** de `docs/design/boards/` (que la regla nueva ya **no** acepta como fuente).
Ese trabajo de pantallas **no se da por válido**: debe rehacerse o validarse contra cada tablero leído
por el MCP antes de continuar. Lo que sí queda válido (no depende del diseño): validaciones del
dominio, interfaces de repositorio, capa `data`, estado (`AuthController`) y sus pruebas unitarias.

**Tarea previa del PNG `8-modo-oscuro-registro-oscuro.png`:** no se pudo rehacer (requiere
`generateMarkup` de Penpot, que ya no respondía tras los timeouts). El PNG defectuoso sigue en su sitio.

## Pendiente

- Re-renderizar **3** tableros con Chromium a 824×1830, recortados al tablero (el resto, 38, ya está hecho):
  `3-notas-lista-de-notas`, `8-modo-oscuro-editor-oscuro`, `8-modo-oscuro-registro-oscuro`. **Bloqueado:** al
  reexportar estos 3 la pestaña de Penpot se suspendió (dos veces seguidas → cancelar por la regla).
  Al reconectar: reexportar su SVG (servidor local + `generateMarkup`) forzando
  `viewBox="<x> <y> 412 915"` y `width`/`height` del SVG raíz al tablero, y renderizar con el Chromium de
  Playwright (`~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome`) a `--force-device-scale-factor=2`.

### Cómo se renderizan (para los 38 hechos)

`generateMarkup([board], {type:'svg'})`; se **fuerza** el `viewBox` y `width`/`height` del `<svg>` raíz al
rectángulo del tablero (`board.bounds`, 412×915), porque Penpot los agranda cuando el contenido desborda
(resplandores del login/registro, sombra del editor). Luego el SVG se envía por `fetch` a un servidor local
y se captura con **Chromium sin cabeza** a 2× (`--window-size=412,915 --force-device-scale-factor=2`
→ 824×1830), con la **fuente Inter** instalada en `~/.fonts` (fontconfig) para que no caiga a serif.

