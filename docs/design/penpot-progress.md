# Extracción de la base visual desde Penpot — progreso

Decisión D16: **manda Penpot**. En la fase 2 los valores salieron de `notify_web` porque Penpot se
congeló; hay que rehacerlos con lo que diga el archivo de Penpot («Apunte – App de notas», página
**App Mobile**, 41 tableros de 412×915). Penpot es de solo lectura: no se modifica nada.

Estado: **EN PAUSA.** Al reanudar, continuar desde este archivo.

## Motivo de la pausa (2.ª vez, 2026-10-10)

1. El MCP estaba suspendido (`no heartbeat for 3828s`); dos reintentos de `getPages` fallaron → pausa.
2. Tras reconectar el usuario: los **tokens de color se extrajeron bien** (una llamada). Después lancé
   **6 consultas en paralelo** (agregación de tableros): la 1.ª respondió y las otras 5 dieron
   `MCP error -32001: Request timed out`. Una consulta mínima posterior también dio timeout.
3. **Lección:** el plugin de Penpot atiende **de una en una**; no enviar llamadas en paralelo. Con dos
   timeouts seguidos, cancelar (regla). Se cancela.

## Progreso de esta sesión

### Área 1 · Colores — tokens: HECHO (claro y oscuro), y **idénticos** a `tokens.dart`

Los 17+17 tokens de color se leyeron con valor; coinciden **exactamente** con los de `app/lib/ui/tokens.dart`
(tomados de `notify_web`). Tabla (claro / oscuro):

| Token | Claro | Oscuro (sufijo -1) |
| --- | --- | --- |
| bg.editor | #fffdf8 | #262522 |
| bg.app | #f6f2ea | #1b1a18 |
| bg.sidebar | #ede7dc | #222120 |
| bg.selected | #dce7f5 | #26364d |
| bg.hover | #e6dfd3 | #2e2c29 |
| bg.input | #eae4d9 | #2a2826 |
| border.default | #e2dacd | #3a3733 |
| text.primary | #1f1d1a | #f1ede6 |
| text.secondary | #57514a | #bab3a8 |
| text.tertiary | #675f55 | #a09990 |
| accent.default | #2a5db0 | #7ba7e6 |
| accent.on | #ffffff | #0f1e36 |
| tag.amber | #8a590c | #e3b062 |
| tag.plum | #7b4b8a | #c49ad3 |
| status.danger | #b3382c | #e88a7e |
| status.danger-bg | #f8e3e0 | #3b2421 |
| status.success | #2f7d5c | #6cc79c |

Pendiente del área 1: colores usados en tableros que **no** casen con estos tokens.

### Agregación de tableros: iniciada

`storage.acc` acumula (fuente, tamaño|peso|interlineado|letterSpacing, colores, radios, sombras, textos).
Procesado hasta ahora: **solo `1 · Onboarding — Bienvenida`** (6 tamaños, 7 colores distintos).

## Pendiente (todo lo demás)

1. **Colores:** no-token usados en los tableros (con el tablero donde aparecen).
2. **Tipografía:** escala completa y uso, desde los textos reales (agregando por tablero).
3. **Radios, bordes, sombras y espaciados** (valores distintos y dónde).
4. **Los 10 componentes base** medidos en sus apariciones reales (alto, ancho, relleno, radio, borde,
   sombra, tipografía, colores por estado, tamaño de icono). Si algo no aparece, decirlo.
5. **Iconos:** lista, tamaño y trazo.
6. **Los 41 tableros:** estructura en `docs/screens.md` + PNG en `docs/design/boards/<nombre>.png`.
7. **Comparar** «3 · Notas — Android — Editor» con «Android — Editor».

## Al reanudar

Consultas **de una en una** (nunca en paralelo), un tablero por llamada; `storage.acc` ya está definido,
así que reanudar llamando a `storage.mergeBoard(...)` por tablero, empezando por los no procesados.
Después volcar `storage.acc`, exportar los PNGs y aplicar lo extraído a `tokens.dart`, componentes,
galería `/dev/components`, golden y `docs/decisions.md`.
