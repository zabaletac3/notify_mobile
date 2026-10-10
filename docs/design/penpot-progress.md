# Extracción de la base visual desde Penpot — progreso

Decisión D16: **manda Penpot**. En la fase 2 los valores salieron de `notify_web` porque Penpot se
congeló; hay que rehacerlos con lo que diga el archivo de Penpot («Apunte – App de notas», página
**App Mobile**, 41 tableros de 412×915). Penpot es de solo lectura: no se modifica nada.

Estado: **EN PAUSA.** Al reanudar, continuar desde este archivo.

## Motivo de la pausa

- 2026-10-10: el MCP de Penpot estaba **suspendido por el navegador** (`no heartbeat for 3828s`).
  Se hicieron **dos** reintentos consecutivos de una consulta mínima (`getPages`) y los dos fallaron.
  Regla de conexión: con dos fallos seguidos, cancelar y esperar a que el usuario reconecte. No se
  rellenó nada con valores de `notify_web` ni de memoria.

## Ya extraído (de una exploración anterior del archivo, antes de la pausa)

Solo estructura; **faltan los valores** (colores, medidas, estilos).

- **Páginas:** una con contenido, `App Mobile` (id `c8bfcdf8-0242-80fe-8008-c4376da04e8d`); otras 9
  vacías (`1 · Onboarding` … `9 · Tienda`).
- **Tableros de `App Mobile` (41)**, nombres y tamaño 412×915:
  - 1 · Onboarding: Bienvenida, Onboarding 1, Onboarding 2, Onboarding 3 (4)
  - 2 · Autenticación: Registro, Verificación de correo, Inicio de sesión, Recuperar contraseña (correo),
    Recuperar contraseña (enviado), Nueva contraseña (6)
  - 3 · Notas: Lista de notas, Android — Editor, 3 · Notas — Android — Editor, Menú contextual de nota,
    Modal mover nota, Confirmar eliminación, Compartir nota (7)
  - 4 · Organización: Primera vez (vacío), Carpeta vacía, Papelera, Modal nueva carpeta (4)
  - 5 · Búsqueda: Resultados, Sin resultados (2)
  - 6 · Ajustes: generales, Mi cuenta, Sincronización y dispositivos, Privacidad y seguridad,
    Almacenamiento y exportación, Eliminar cuenta, Acerca de, Menú lateral (8)
  - 7 · Estados y errores: Sin conexión, Conflicto de sincronización, Sesión expirada, Error de servidor,
    Cargando (skeletons), Toasts (6)
  - 8 · Modo oscuro: Lista (oscuro), Editor (oscuro), Registro (oscuro) (3)
  - 9 · Tienda: Ficha de tienda (1)
- **Tokens (solo nombres):** dos sets de color:
  - `Apunte/Color/Light`: `bg.input`, `border.default`, `accent.default`, `text.primary`, `bg.sidebar`,
    `status.danger`, `text.tertiary`, `bg.selected`, `bg.hover`, `accent.on`, `bg.app`, `tag.amber`,
    `text.secondary`, `bg.editor`, `status.danger-bg`, `tag.plum`, `status.success`.
  - `Apunte/Color oscuro/Dark`: los mismos con sufijo `-1`.
  - **No** hay tokens de tipografía, radios ni espaciado (salen de las formas).
- **Tipografía (muestra):** familia **Inter**, pesos vistos 400/500/600/700, tamaños vistos 11/12/13/14/22.

## Pendiente (todo lo demás)

1. **Colores:** valores (hex) de los dos sets completos; y colores usados en tableros que **no** casan
   con ningún token (con el tablero donde aparecen).
2. **Tipografía:** escala completa (familia, peso, tamaño, interlineado, `letterSpacing`) y uso de cada
   estilo, desde los textos reales.
3. **Radios, bordes, sombras y espaciados** usados (valores distintos y dónde).
4. **Los 10 componentes base** medidos en sus apariciones reales: botón (tamaños y variantes), campo de
   texto (etiqueta, ayuda, error), interruptor, casilla, casilla OTP, tarjeta de nota, hoja inferior,
   elemento de menú, diálogo, aviso/toast. Para cada uno: alto, ancho, relleno, radio, borde, sombra,
   tipografía, colores por estado, tamaño de icono. Si algo no aparece, decirlo (no inventar).
5. **Iconos:** lista de iconos usados, tamaño y trazo.
6. **Los 41 tableros:** estructura en `docs/screens.md` + export PNG en `docs/design/boards/<nombre>.png`
   (`export_shape`).
7. **Comparar** «3 · Notas — Android — Editor» con «Android — Editor» y anotar diferencias.

## Al reanudar

Continuar por el punto 1 (colores), consultas pequeñas de un tablero por llamada, sin `findShapes` sobre
toda la página, guardando resultados intermedios en `storage`. Y aplicar lo extraído a
`app/lib/ui/tokens.dart`, los 10 componentes, la galería `/dev/components`, los golden y
`docs/decisions.md`.
