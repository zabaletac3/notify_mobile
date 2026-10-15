# Traspaso · Fase 10 (Editor)

Rama `fase-10-editor` (sobre `fase-9-notas`). Fecha: 2026-10-14. Los commits, el push y el PR los
hace el dueño; todo quedó en el árbol de trabajo.

## Qué se hizo

### 10.1 · `packages/axonote_markdown` (códec propio, D2)

- **Modelo** (`lib/src/ast.dart`): árbol de nodos con nombre/atributos/contenido/marcas, igual que
  el JSON de TipTap (`doc`, `paragraph`, `heading`, listas, `taskList`, `blockquote`, `codeBlock`,
  `horizontalRule`, `hardBreak`, `text`, `opaque`), más `toJson`/`fromJson` y huella estructural.
- **Analizador** (`lib/src/parser.dart`): pasada sobre líneas (títulos, vallas, citas, listas con
  anidación, separadores, párrafos, líneas en blanco como párrafos vacíos, bloques opacos) y
  sub‑analizador en línea (negrita, cursiva, tachado, subrayado, código, enlaces, autolinks,
  entidades HTML, escapes, saltos duros, URLs). Normaliza como la web (§8.1).
- **Serializador** (`lib/src/serializer.dart`): reproduce byte a byte el canónico de TipTap
  (marcadores de lista, sangría, anidación de marcas, escapes/entidades, `&nbsp;`, saltos duros).
- **Conservación por bloque** (`lib/src/document.dart`): cada bloque de primer nivel guarda su texto
  original; al guardar, los bloques sin cambios se emiten byte a byte y los cambiados pasan por el
  serializador; los separadores originales se conservan entre bloques intactos.
- **Bloque opaco** (§8.2.5): tabla, HTML de bloque, nota al pie e imagen en línea → bloque `opaque`
  conservado intacto.

### 10.2 · Editor en la app

- **Adaptador** `app/lib/features/editor/state/editor_adapter.dart`: bloques ↔ nodos de
  `appflowy_editor` (el códec no importa AppFlowy). Listas agrupadas por tipo; salto duro propio;
  opaco como nodo `axonote_opaque`.
- **Pantalla** `app/lib/features/editor/ui/editor_screen.dart` (ruta `/notes/:id`, sustituye al
  marcador `_EditorHome`): barra superior (atrás, carpeta, deshacer, compartir, más), documento
  (fecha, título, etiquetas, cuerpo con `AppFlowyEditor`), aviso y solo lectura si la nota es
  ilegible.
- **Barra de formato** `app/lib/features/editor/ui/format_bar.dart`: estilo de párrafo, negrita,
  cursiva, lista y tareas, con las medidas del tablero «Android — Editor»; va sobre el teclado.
- **Bloque opaco** `app/lib/features/editor/ui/opaque_block.dart`: tarjeta «Bloque no editable» de
  solo lectura.
- **Estado** `app/lib/features/editor/state/editor_controller.dart`: monta el árbol, guarda 400 ms
  tras la última edición (A10) y al ir a segundo plano, y ofrece los comandos de formato.

### 10.3 · Guardado, recarga y rendimiento

- **Guardado** con espera de 400 ms; **recarga** al llegar una revisión nueva por sincronización si
  no hay cambios locales pendientes (`RevisionToken`); **enlace público** es fase 11 (el botón
  «Compartir» existe pero sin acción).
- **Rendimiento (d)**: prueba `app/integration_test/editor_performance_test.dart`. Ver
  `docs/benchmarks.md` (§Fase 10): 100,4 KB / 1901 bloques → **apertura 94 ms**, **escritura
  68 ms** en el ZTE en `--profile`.
- **Guía manual (e)**: `docs/guides/fase10-prueba-manual.md`.

## Salida de las puertas (2026-10-14)

| Puerta | Resultado |
| --- | --- |
| `dart format --set-exit-if-changed` (CI) | **OK** (225 archivos, 0 cambiados) |
| `flutter analyze` | **OK** (sin avisos) |
| `flutter test` · app | **OK** (251 pruebas) |
| `flutter test` · `packages/axonote_markdown` | **OK** (320 pruebas) |
| `flutter test` · `packages/axonote_domain` / `axonote_sync` | **OK** (66 / 10) |
| Cobertura `axonote_markdown` | **99,0 %** (≥95 % de la §11) |
| `dart run tool/check_imports.dart` | **OK** (arquitectura correcta) |
| `NOTIFY_WEB=… bash tool/check_contract.sh` | **OK** (contrato correcto) |
| `cd app && flutter build apk --debug` | **OK** (`app-debug.apk`) |
| Rendimiento (d) en el ZTE, `--profile` | **OK** (94 ms / 68 ms; §10 (d) < 300 ms) |

## Decisiones y cambios fuera de lo previsto

- **`package:markdown` (aparecía en la §9) no se usa**: no reproduce el canónico de TipTap y D2 pide
  un códec propio. La dependencia no se añadió. Detalle en `docs/decisions.md`.
- **Dependencias nuevas**: `appflowy_editor` (path a `packages/third_party`), `axonote_markdown` y
  `provider` (para el componente del bloque opaco) en `app/pubspec.yaml`.
- **Dos parches nuevos del paquete vendorizado** (`packages/third_party/appflowy_editor/PATCHES.md`):
  retirar `device_info_plus` (choca con `win32` 6 de `flutter_secure_storage`) y `file_picker`
  (choca con `win32` 6 y con `dbus` 0.8 de `connectivity_plus`). Ninguno afecta al editor de texto;
  la selección de imágenes queda fuera de alcance (las imágenes son bloque opaco).
- **Barra de formato**: se omite el **botón de imagen** del tablero (fuera de alcance) y el
  **«deshacer»** queda en la barra superior, como el diseño (el plan §8.2.7 lo listaba en la barra).
  Los iconos `bold`/`italic`/`list` no están en el set vendorizado: se usan glifos «B»/«I» y el
  icono más cercano (`menu`, `check-check`).
- **Estados del editor sin tablero**: conflicto (hoja de la fase 9), ilegible (solo lectura),
  sincronizando (indicador de la fase 7).

## Pendientes y riesgos

- **Prueba manual web ↔ móvil (e)**: pendiente del dueño (`docs/guides/fase10-prueba-manual.md`). El
  caso 4 (bloque opaco) solo se puede probar metiendo Markdown a mano (la importación es fase 11).
- **Enlace público**: el botón «Compartir» no hace nada todavía (fase 11).
- **`saveFile`/selección de archivos** del paquete vendorizado lanzan `UnsupportedError`: no se usa.
- **Divergencia de lectura** (conocida y acotada): títulos con subrayado (`Título` + `====`) y otras
  normalizaciones de Markdown «crudo» no se normalizan al leer; solo importarían al **importar**
  `.md` (fase 11). No afecta a los criterios (los vectores usan el canónico).
- **Salto duro dentro de un párrafo**: al editar un bloque con salto duro, el editor lo conserva
  (se marca aparte en el delta), pero conviene revisarlo en la prueba manual.
- **Golden del editor**: no se añadió. El `AppFlowyEditor` no es estable para goldens de texto; el
  resto de la pantalla sigue las medidas del tablero. Anotado por si dirección lo quiere.
- **Margen del rendimiento**: 94 ms sobre 300 ms, holgado; pero si se toca el códec o el adaptador,
  conviene repetir `editor_performance_test.dart`.
