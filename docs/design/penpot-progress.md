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

## Fase 8 (2026-10-11): estado real de la lectura por el MCP

**Regla vigente:** si el MCP no devuelve un tablero (o da dos timeouts seguidos), no se inventa ni se
deduce el diseño y **no se sigue construyendo ninguna pantalla**; se para y se pide reconectar.

Lectura **pantalla por pantalla** (tablero por tablero, un tablero por consulta). Fecha: 2026-10-11.

| Pantalla / tablero | ¿Leído por el MCP? | Última lectura | Qué se leyó |
| --- | --- | --- | --- |
| Bienvenida / `1 · Onboarding — Bienvenida` | **Sí** | 2026-10-11 (tarde) | fondo `#fffdf8`, logo 96 radio 24, marca 34/700, eslogan 16/400, botones 16/600 y 362×54, secundario con borde, pie 12/400 |
| Onboarding 1–3 / `1 · Onboarding — Onboarding 1/2/3` | **Sí** | 2026-10-11 | fondo `#fffdf8`, panel 362×340 radio 28 `#dce7f5`, tarjetas 240×45, título 28/700 centrado, cuerpo 15/400, puntos 22/8, botón 362×54 |
| Registro (claro) / `2 · Autenticación — Registro` | **Sí** | 2026-10-11 (tarde) | fondo `bgApp #f6f2ea`, **3 resplandores** (`#2a5db0` 20 %, `#7b4b8a` 14 %, `#b7791f` 12 %), tarjeta `#fffdf8` radio 28 a y=91 con **sombra** (`#1f1a14` 10 %, blur 64, y 24, spread −8), logo 48 radio 14, título 24/700, subtítulo 14/400, etiquetas 13/500 `#1f1d1a`, inputs 52 radio 12 `#eae4d9`, medidor barra continua, botón 16/600 |
| Inicio de sesión / `2 · Autenticación — Inicio de sesión` | **Sí** | 2026-10-11 (tarde) | mismo fondo/resplandores/sombra; tarjeta 372×533 a y=177; título 24/700; enlace 13/600 |
| Verificación de correo / `2 · Autenticación — Verificación de correo` | **Sí** | 2026-10-11 (tarde) | fondo `#fffdf8`, vuelta 40 radio 20, icono 72, título 28/700, cuerpo 15/400 (correo en negrita), OTP 53×60 radio 12 (activa `#fffdf8` + borde `#2a5db0`), reenvío 14, botón 362×54 |
| Recuperar contraseña (correo) / `2 · Autenticación — Recuperar contraseña (correo)` | **Sí** | 2026-10-11 (tarde) | fondo `#fffdf8`, título 28/700, subtítulo 15/400, campo 362×74, botón y enlace al pie |
| Recuperar contraseña (enviado) / `2 · Autenticación — Recuperar contraseña (enviado)` | **Sí** | 2026-10-11 (tarde) | fondo `#fffdf8`, icono 96 radio 48, título 28/700 centrado, cuerpo 15/400 centrado, botón y pie al pie |
| Sesión expirada / `7 · Estados y errores — Sesión expirada` | **Sí** | 2026-10-11 | textos del diálogo (título, cuerpo, «Seguir sin conexión»/«Iniciar sesión») |
| Toasts / `7 · Estados y errores — Toasts` | **Sí** | 2026-10-11 | 4 toasts 388×41 radio 12 `#fffdf8`, mensaje 14/500, acción 14/600 |
| Error de servidor / `7 · Estados y errores — Error de servidor` | **Sí** | 2026-10-11 (noche, relectura fina) | círculo 80 radio 40 `#f8e3e0` con «!» 40/700 `#b3382c`; título 20/700 `#1f1d1a` centrado; cuerpo 14/400 `#57514a` centrado; botón abrazado 115×46 radio 12 `#2a5db0`, etiqueta 15/600 blanca; «Código de error 500» 12/400 `#675f55`; márgenes: círculo→título 14, título→cuerpo 34, cuerpo→botón 14, botón→código 14; padding lateral 32 |
| Registro (oscuro) / `8 · Modo oscuro — Registro (oscuro)` | **Sí** | 2026-10-11 | pantalla completa sin tarjeta ni Google; fondo `bgEditor` oscuro; título 28/700 a la izquierda; campos 362×74; medidor; botón 362×54 |

### Historial de paradas por la regla de conexión

1. Varios tableros en una consulta y uno suelto → **dos timeouts seguidos** → parada.
2. Tras reconectar: Bienvenida OK; Onboarding 1 → **dos timeouts seguidos** → parada.
3. Tras reconectar: leídos Bienvenida, Onboarding 1–3, Verificación, Inicio de sesión, Recuperar
   (correo y enviado), Sesión expirada, Error de servidor; Toasts → **dos timeouts seguidos** → parada.
4. Tras reconectar: leídos Toasts y Registro (oscuro).
5. Revisión de fidelidad (tarde): releídos con detalle Bienvenida, Registro claro, Inicio de sesión,
   Verificación, Recuperar (correo y enviado); Error de servidor → **dos timeouts seguidos** → parada.
6. Revisión de fidelidad 2 (noche): leído «Error de servidor» en detalle (ver tabla); consulta de etiquetas
   de botón en 6 tableros → timeout; scans `findShapes` sueltos dieron timeouts, resuelto con recorrido
   manual de `root.children` (ligero). Confirmado: botones primarios **16/600** en Bienvenida, Registro e
   Inicio de sesión; «Reintentar» del error de servidor es **15/600** (excepción de ese tablero).
   `penpot_export_shape` (PNG) dio **dos timeouts seguidos** → PNG sin rehacer.

**Pantallas sin tablero en Penpot** (composición con tokens y componentes base, según `screens.md`):
Clave de recuperación, Segundo factor (2FA) y Desbloqueo.

**Tarea previa del PNG `8-modo-oscuro-registro-oscuro.png`:** no se pudo rehacer (requiere `generateMarkup`
de Penpot, que no respondía tras los timeouts; `penpot_export_shape` también dio **dos timeouts seguidos**
en la reconexión). El PNG defectuoso sigue en su sitio.

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

