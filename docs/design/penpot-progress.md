# Extracción de la base visual desde Penpot — progreso

Decisión D16: **manda Penpot**. En la fase 2 los valores salieron de `notify_web` porque Penpot se
congeló; hay que rehacerlos con lo que diga el archivo de Penpot («Apunte – App de notas», página
**App Mobile**, 41 tableros de 412×915). Penpot es de solo lectura: no se modifica nada.

Estado: **EN PAUSA (3.ª vez).** Al reanudar, continuar desde este archivo.

Datos crudos ya extraídos y guardados: [`docs/design/penpot-extract.json`](penpot-extract.json).

## Pausas (regla de conexión)

1. **Suspendido por el navegador** (`no heartbeat for 3828s`); dos reintentos fallaron.
2. Reconectado: se extrajeron los **tokens de color** y se empezó la agregación; al lanzar **6 consultas
   en paralelo** la 1.ª fue bien y las otras 5 dieron timeout, y una consulta mínima después también →
   cancelar. **Lección:** el plugin atiende **de una en una**; no paralelizar.
3. Reanudado: se procesaron los **41 tableros** de uno en uno (bien) y se volcó el acumulador (bien).
   Después, `export_shape` del tablero «Lista de notas» dio **dos timeouts seguidos** → cancelar.

## Hecho

### Área 1 · Colores — HECHO
- Los **17+17 tokens** de color (claro/oscuro) leídos con valor. **Idénticos** a `app/lib/ui/tokens.dart`
  (tomados de `notify_web`): en colores **no hay diferencias** con Penpot. Tabla en `penpot-extract.json`.
- **Colores usados que NO son token**: `#b7791f` (ámbar antiguo, 3×) y `#4285f4` (azul del logo de Google, 3×).

### Áreas 2 y 3 (parcial) · Tipografía, radios, sombras — AGREGADO (41 tableros)
- **Fuentes:** Inter (953 textos) y `sourcesanspro` (2). 
- **Sombras:** 56 shapes con sombra.
- **Radios** (distribución) y **escala tipográfica** (tamaño|peso|interlineado|letterSpacing y conteos) en
  `penpot-extract.json`. Observaciones:
  - `title` 28/34 (1.214) y `body` 15/22 (1.467) **sí** casan con la web; `label` 13/18 (1.385) también.
  - El resto usa mayoritariamente interlineado **1.2** (p. ej. 18|600 → 21.6, no 24; 12|400 → 14.4, no 16):
    **difiere** de la escala de la web.
  - Los títulos llevan **letterSpacing negativo** (p. ej. 22|700 → -0.44; 28|700 → -0.56).
  - Aparecen muchos tamaños (11,12,13,14,15,16,18,20,22,24,28,30,…), más que la escala de 5 pasos de la web.
- **Ids de los 41 tableros** en `penpot-extract.json` (para exportar/comparar).

## Pendiente

1. (Área 1) Dónde aparece `#b7791f` (tablero).
2. (Área 4) **Los 10 componentes base** medidos en sus apariciones reales (alto, ancho, relleno, radio,
   borde, sombra, tipografía, colores por estado, tamaño de icono). Sin medir todavía.
3. (Área 5) **Iconos:** lista, tamaño y trazo.
4. (Área 6) **PNGs de los 41 tableros** en `docs/design/boards/<nombre>.png` (`export_shape`):
   **bloqueado** (2 timeouts seguidos con «Lista de notas»). Reintentar con exportaciones más ligeras
   (¿uno a uno, sin prisa?) o desde el navegador.
5. (Área 6) Estructura de cada tablero en `docs/screens.md`.
6. (Área 7) Comparar «3 · Notas — Android — Editor» con «Android — Editor».
7. **Código:** tokens.dart (tipografía/radios/espaciado), los 10 componentes, galería `/dev/components`
   (mover «Ver componentes (dev)» y «Entrar (demo)» al centro), regenerar golden y tabla en `decisions.md`.

## Al reanudar

Consultas **secuenciales** (nunca en paralelo), un tablero por llamada. `storage.acc` y `storage.boards`
ya están poblados en la sesión del plugin; si se pierden, re-construir desde `penpot-extract.json` (ids).
Empezar por los **PNGs** (o medir los componentes), y terminar con las actualizaciones de código.
