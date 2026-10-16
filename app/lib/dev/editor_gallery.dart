import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';

import '../features/editor/state/editor_controller.dart';
import '../features/editor/ui/editor_view.dart';
import '../ui/components.dart';
import '../ui/theme.dart';
import '../ui/tokens.dart';

/// Estados de la maqueta del editor (§«Movil v2» + `notify_web` para lo que Pencil no cubre).
enum EditorMockState {
  normal('Normal'),
  completo('Todos los bloques'),
  unreadable('Ilegible (solo lectura)'),
  conflict('Conflicto'),
  syncing('Sincronizando'),
  keyboard('Teclado abierto');

  const EditorMockState(this.label);

  final String label;
}

/// Maqueta del editor con datos falsos, solo en modo debug (ruta `/dev/editor`). No usa cifrado,
/// red ni base local: sirve para aprobar la capa visual y para los goldens.
class EditorGallery extends StatefulWidget {
  const EditorGallery({
    super.key,
    this.initialState = EditorMockState.normal,
    this.initialDark = false,
    this.showDevBar = true,
  });

  /// Estado con el que se abre (los goldens lo fijan).
  final EditorMockState initialState;

  /// Modo oscuro con el que se abre.
  final bool initialDark;

  /// La barra de depuración se oculta en los goldens.
  final bool showDevBar;

  @override
  State<EditorGallery> createState() => _EditorGalleryState();
}

class _EditorGalleryState extends State<EditorGallery> {
  late EditorMockState _state = widget.initialState;
  late bool _dark = widget.initialDark;

  NoteEditorController? _controller;
  final _titleController = TextEditingController();

  /// Alto del teclado simulado (≈ el teclado de Android).
  static const _keyboardHeight = 291.0;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _rebuild() {
    _controller?.dispose();
    final note = mockNoteFor(_state);
    _controller = NoteEditorController(note: note, save: _noSave)..start();
    _titleController.text = note.title;
  }

  Future<void> _noSave({String? title, String? content}) async {}

  @override
  Widget build(BuildContext context) {
    final note = mockNoteFor(_state);
    final controller = _controller!;
    return Theme(
      data: _dark ? AxoTheme.dark() : AxoTheme.light(),
      child: Builder(
        builder: (context) {
          final c = Theme.of(context).extension<AxoColors>()!;
          Widget view = EditorView(
            note: note,
            controller: controller,
            titleController: _titleController,
            onTitleChanged: (_) async {},
            folderName: 'Universidad',
            onBack: _noop,
            onShare: _noop,
            onMore: _noop,
            syncing: _state == EditorMockState.syncing,
          );

          if (_state == EditorMockState.keyboard) {
            view = MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewInsets: const EdgeInsets.only(bottom: _keyboardHeight),
              ),
              child: Stack(
                children: [
                  view,
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: _MockKeyboard(height: _keyboardHeight),
                  ),
                ],
              ),
            );
          }
          if (_state == EditorMockState.conflict) {
            view = Stack(
              children: [
                view,
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: _ConflictSheet(),
                ),
              ],
            );
          }

          return Scaffold(
            backgroundColor: c.bgApp,
            body: SafeArea(
              child: Column(
                children: [
                  if (widget.showDevBar)
                    _DevBar(
                      state: _state,
                      dark: _dark,
                      onState: (s) => setState(() {
                        _state = s;
                        _rebuild();
                      }),
                      onDark: (v) => setState(() => _dark = v),
                    ),
                  Expanded(child: view),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void _noop() {}

/// Contenido del tablero «Android — Editor» (las tres viñetas al MISMO nivel).
const _boardContent = '''
La normalización organiza las tablas para evitar redundancia y anomalías al insertar, actualizar o borrar.

## Formas normales

- 1FN: valores atómicos.
- 2FN: sin dependencias parciales.
- 3FN: sin dependencias transitivas.

## Pendientes

- [x] Repasar dependencias funcionales
- [x] Taller 4 (diagramas ER)
- [ ] Preguntar por BCNF
- [ ] Armar fichas para el viernes
''';

/// Contenido con TODOS los bloques soportados (para el estado «Todos los bloques»).
const _completoContent = '''
La normalización organiza las tablas para evitar redundancia y anomalías al insertar, actualizar o borrar.

# Título de sección

## Formas normales

- 1FN: valores atómicos.
- 2FN: sin dependencias parciales.
  - 3FN: sin dependencias transitivas.

### Numeradas

1. Primero
2. Segundo
3. Tercero

- [ ] Pendiente
- [x] Hecha

> Repasar el capítulo 6 antes del parcial.

```js
const notas = 42;
```

Usa `const` para declarar y `let` para reasignar. Visita [AxoNote](https://apunte.app "la web").

---

| Alumno | Nota |
| ------ | ---- |
| Ana    | 4.5  |
''';

/// Nota de ejemplo del estado pedido.
Note mockNoteFor(EditorMockState state) {
  return Note(
    id: 'mock-note',
    folderId: 'mock-folder',
    title: 'Resumen: Bases de datos II',
    content: state == EditorMockState.completo
        ? _completoContent
        : _boardContent,
    tags: const ['parcial', 'lecturas'],
    pinned: true,
    createdAt: '2026-10-07T09:12:00',
    updatedAt: '2026-10-07T09:12:00',
    deletedAt: null,
    revision: 3,
    syncStatus: NoteSyncStatus.synced,
    lastEditedDeviceId: 'mock-device',
    unreadable: state == EditorMockState.unreadable,
    preview: 'La normalización organiza…',
  );
}

/// Contenido del tablero (una prueba del adaptador lo usa).
String mockBoardContent() => _boardContent;

/// Barra de depuración: elige el estado y el modo.
class _DevBar extends StatelessWidget {
  const _DevBar({
    required this.state,
    required this.dark,
    required this.onState,
    required this.onDark,
  });

  final EditorMockState state;
  final bool dark;
  final ValueChanged<EditorMockState> onState;
  final ValueChanged<bool> onDark;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      color: c.bgSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<EditorMockState>(
              value: state,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: AxoType.chipActive.copyWith(color: c.textPrimary),
              dropdownColor: c.bgSidebar,
              onChanged: (v) => v == null ? null : onState(v),
              items: [
                for (final s in EditorMockState.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AxoSwitch(value: dark, onChanged: onDark),
        ],
      ),
    );
  }
}

/// Teclado simulado (el diseño no lo dibuja; se compone con los tokens).
class _MockKeyboard extends StatelessWidget {
  const _MockKeyboard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    const rows = [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['⇧', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '⌫'],
      ['?123', ',', 'espacio', '.', '↵'],
    ];
    return Container(
      height: height,
      width: double.infinity,
      color: c.bgSidebar,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        children: [
          for (final row in rows) ...[
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  for (final key in row) ...[
                    Expanded(
                      flex: key == 'espacio' ? 4 : 1,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.bgEditor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          key == 'espacio' ? '' : key,
                          style: AxoType.caption.copyWith(color: c.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hoja de conflicto (la pieza real es `features/notes/ui/conflict_sheet.dart`, de la fase 9).
class _ConflictSheet extends StatelessWidget {
  const _ConflictSheet();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.bgSidebar,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AxoRadii.sheet),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Esta nota cambió en otro dispositivo',
            style: AxoType.sheetTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Elige qué versión conservar.',
            style: AxoType.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: AxoButton(
                  label: 'Conservar la mía',
                  variant: AxoButtonVariant.outline,
                  onPressed: _noop,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: AxoButton(label: 'Usar la otra', onPressed: _noop),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
