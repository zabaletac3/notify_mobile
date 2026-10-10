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

## Pendiente

- **Re-renderizar los 41 PNG con Chromium sin cabeza** (los actuales se hicieron con ImageMagick, que
  añade un lienzo grande y no dibuja bien desenfoques/resplandores). Renderizar a 824×1830 (2x), recortar
  al tablero y revisar los 41. **Bloqueado:** la pestaña de Penpot volvió a dar timeouts al reexportar los
  SVG (regla: dos timeouts seguidos = cancelar). Al reconectar, reexportar los SVG (servidor local +
  `generateMarkup`) y renderizarlos con Chromium del Playwright
  (`~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome`).
