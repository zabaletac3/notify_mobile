# Comparación Pencil «Movil v2» ↔ goldens de Ajustes (fase 11.1)

- Referencias: `app/test/design_refs/crop/settings-<sección>-claro.png` (capturas de Pencil
  recortadas al **área del dispositivo, 412×915**). Capturas completas (2×, 824×1830) en
  `app/test/design_refs/Android — …png`.
- Goldens: `app/test/features/settings/goldens/settings-<sección>-{claro,oscuro}.png` (412×915, dpr 1).
- Lado a lado para revisión a ojo: `docs/design/fase11-<sección>-pencil-vs-golden.png` (Pencil |
  golden).
- Pruebas: `test/features/settings/settings_golden_test.dart` (16 goldens) y
  `test/features/settings/settings_compare_test.dart` (puerta con Pencil).

En la puerta geométrica, cada banda de texto del tablero debe tener una banda en el golden a
**≤ 4 px** en vertical, alineando por la barra superior, y el fondo de la página debe ser `bgEditor`
en claro. Los tableros de Ajustes solo existen en **claro**; el modo oscuro se cubre con goldens.

**Resultado: en verde.** 14 pruebas (7 de color + 7 de geometría). `flutter test` de la app:
**329 pruebas, 0 fallos**.

## Pantallas y correspondencia

| Ruta | Tablero Pencil | Golden | Comparación |
| --- | --- | --- | --- |
| `/settings/menu` | *(sin tablero)* | `settings-menu-*` | Se sigue el responsive móvil de la web (`notify_web/.../settings/menu`). Solo golden. |
| `/settings/general` | Android — Ajustes generales | `settings-general-*` | ✔ |
| `/settings/account` | Android — Mi cuenta | `settings-cuenta-*` | ✔ (excluye la tarjeta de perfil, ver abajo) |
| `/settings/sync` | Android — Sincronización y dispositivos | `settings-sync-*` | ✔ |
| `/settings/privacy` | Android — Privacidad y seguridad | `settings-privacidad-*` | ✔ |
| `/settings/storage` | Android — Almacenamiento y exportación | `settings-almacenamiento-*` | ✔ |
| `/settings/delete-account` | Android — Eliminar cuenta | `settings-eliminar-cuenta-*` | ✔ (excluye la confirmación, ver abajo) |
| `/settings/about` | Android — Acerca de | `settings-acerca-*` | ✔ |
| `/settings/two-factor` | *(sin tablero; subfase 11.3)* | — | `PlaceholderScreen` con «atrás». |

## Diferencias conocidas (documentadas, no son fallo de maquetación)

1. **`/settings/menu` sin tablero**: se reproduce el menú de secciones de la web (ocho filas
   Generales → Acerca de). En pantallas anchas la web redirige a `/settings/general`; en móvil se
   mantiene el menú.
2. **«Eliminar cuenta»**: el tablero pide escribir «ELIMINAR»; la app pide la **contraseña**
   (`POST /me/delete` exige `authKey`, ver `contract/openapi.yaml`; §7 del encargo). La maquetación
   (aviso + etiqueta + campo + botones) es la del tablero; cambia el texto de la confirmación. Ese
   tramo queda fuera de la puerta de bandas.
3. **Avatar de «Mi cuenta»**: el borde difuminado del avatar en la captura (rasterizado a 1×)
   retrasa su banda; el tramo de la tarjeta de perfil queda fuera de la puerta (solo ahí).
4. **Valores de la maqueta**: los interruptores y valores mostrados son datos de muestra. Los
   valores por defecto reales son los de la web (p. ej. Tema «Sistema»; el tablero dibuja «Claro»).
5. **Marca**: el tablero usa el nombre viejo «Apunte»; en la app se escribe «AxoNote»
   (`docs/decisions.md`, 2026-10-14).

## Ritmo vertical

- Fila de ajustes: 52 (`valor`/chevron), 54 (interruptor), 66 (con descripción), 46 (solo acción o
  peligro). Encabezado de sección 11/600 (13 + 8 de hueco); tarjeta `bgApp` radio 14; grupos
  separados 20; cuerpo con relleno 16/12.
- Se corrigió que el tap target del interruptor (44) hinchaba la fila; ahora la fila fija su altura
  y el control se centra.

## Correcciones tras la revisión de la maqueta (2026-10-15)

La maqueta se aprobó con tres correcciones a ojo (la puerta de bandas no las veía). Ya aplicadas:

1. **Avatar de «Mi cuenta»**: círculo `bgSelected` con iniciales en `accentDefault` (antes azul
   oscuro con iniciales blancas), como el tablero.
2. **Trazo de tarjeta**: todas las tarjetas llevan borde de 1 px `borderDefault` (la de peligro,
   `statusDanger`); el marco usa `Material` con `shape` para que el trazo no altere la altura.
3. **Título de la barra**: 18/600 (`AxoType.heading`), no 22/700.

La puerta añade, para que no se repita:
- **Color de borde**: comprueba el trazo de la primera tarjeta de cada sección (color y fila).
- **Avatar**: comprueba que el centro del avatar de «Mi cuenta» es `bgSelected` y que hay píxeles
  `accentDefault` (iniciales).

## Diálogos de cuenta (sin tablero)

Los diálogos de cambio de **nombre**, **correo** y **contraseña** no tienen tablero en «Movil v2»;
se siguen del responsive móvil de `notify_web` y llevan goldens propios
(`settings_dialogo-{nombre,correo,contrasena}-{claro,oscuro}.png`,
`settings_dialogs_golden_test.dart`).

## Cambio tras 11.2b (2026-10-15)

Al conectar los ajustes con servicios reales, la fila «Cifrar notas en este dispositivo» pasa a ser
**informativa** (la base va cifrada siempre): se quita su interruptor falso y la golden de Privacidad
se regenera. Las demás pantallas mantienen el aspecto aprobado (su golden no cambia); el tema y el
tamaño de letra de la maqueta coinciden con los valores por defecto reales, así que la puerta
geométrica sigue verde.

## Cambios tras 11.4 (2026-10-15)

- **Hoja «Compartir nota»** (tablero «Android — Compartir nota»): golden nueva
  `test/features/share/goldens/notes-share-{claro,oscuro}.png` y comparación a ojo con el tablero.
  Coincide en estructura: título, nota entre comillas, campo de URL + «Copiar», fila con interruptor
  («Cualquiera con el enlace puede ver» / «Solo lectura, no pueden editar») y filas
  «Exportar como PDF», «Exportar como Markdown» y «Enviar una copia».
- **Menú contextual de nota**: se añade la fila «Compartir» (entre «Mover a carpeta» y «Cambiar
  nombre», como el tablero); se regenera su golden.
- El tablero de «Compartir nota» **no trae** el texto explicativo que sí tiene la web (la app
  tampoco lo pinta: sigue el tablero).

## Cambios tras 11.7 (2026-10-15)

- **Barra «Sincronizando…»** en el editor: pasa a ir dentro del `Scaffold` (bajo la barra superior),
  como en la web, en vez de por encima de la barra en la maqueta. Se regeneran las dos goldens
  `editor-syncing-{claro,oscuro}.png` (Pencil no dibuja este estado).
- **Conflicto en el editor real**: usa la hoja de conflicto ya aprobada en la fase 9; sin cambio de
  aspecto.
- **Pantallas legales** (`/terms`, `/privacy`, `/changelog`, `/support`): **no hay tablero** en
  «Movil v2»; se siguen del responsive de la web y llevan goldens propias
  (`settings-terminos-*`, `settings-privacidad-legal-*`, `settings-novedades-*`, `settings-soporte-*`).
  «Licencias de código abierto» usa la página de Flutter (sin golden).

## Repaso de la fase 9 contra «Movil v2»

Se revisaron las pantallas de la fase 9 (lista, papelera, búsqueda, carpetas, estados) contra los
tableros de «Movil v2» en claro y oscuro. Muestreo de los PNG de Pencil frente a los tokens:

| Zona | Tablero (px) | Token | Coincide |
| --- | --- | --- | --- |
| Lista clara · fondo | `#F6F2EA` | `bgApp` claro | ✔ |
| Lista oscura · fondo | `#1B1A18` | `bgApp` oscuro | ✔ |
| Papelera clara · fondo | `#F6F2EA` | `bgApp` claro | ✔ |

El resto (barra superior, chips, tarjetas, FAB, cabeceras de grupo) ya se ajustó en la fase 9. **No
se encontraron diferencias de token/estilo que corregir.** Nota: la fase 9 no tiene puerta
geométrica contra Pencil (solo tienen `editor_compare_test` y `settings_compare_test`); el repaso
es visual y por muestreo.
