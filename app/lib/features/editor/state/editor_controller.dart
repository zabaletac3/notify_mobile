import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_markdown/axonote_markdown.dart';

import 'editor_adapter.dart';

/// Estado del editor de una nota: árbol de AppFlowy, guardado con espera de 400 ms (A10) y los
/// comandos de formato que usa la barra. Vive en `state/` para que la interfaz no hable con
/// `appflowy_editor` ni con el códec directamente.
class NoteEditorController {
  NoteEditorController({
    required this.note,
    required this.save,
    this.debounce = const Duration(milliseconds: 400),
  });

  /// Nota cargada (título y contenido).
  final Note note;

  /// Persiste el contenido (y opcionalmente el título) ya serializado.
  final Future<void> Function({String? title, String? content}) save;

  /// Espera antes de guardar tras la última edición (A10: 400 ms).
  final Duration debounce;

  /// Árbol que consume `AppFlowyEditor`.
  late final EditorState editorState;

  StreamSubscription<EditorTransactionValue>? _subscription;
  Timer? _timer;
  bool _dirty = false;
  String _savedContent = '';

  /// Última selección conocida. AppFlowy borra la selección cuando el editor pierde el foco (al abrir
  /// el menú de estilo o al tocar la barra), y sin ella los comandos de formato no tendrían efecto.
  Selection? _lastSelection;

  /// `true` si hay cambios sin guardar.
  bool get isDirty => _dirty;

  /// Se puede editar salvo si la nota no se pudo descifrar o está en conflicto (§8.3).
  bool get editable =>
      !note.unreadable && note.syncStatus != NoteSyncStatus.conflict;

  /// Prepara el estado del editor a partir del Markdown guardado.
  void start() {
    _savedContent = note.content;
    final blocks = MarkdownParser.parse(note.content).content;
    editorState = EditorState(document: EditorAdapter.toDocument(blocks));
    editorState.editableNotifier.value = editable;
    editorState.selectionNotifier.addListener(_rememberSelection);
    if (editable) {
      _subscription = editorState.transactionStream.listen((_) => _onChanged());
    }
  }

  void _rememberSelection() {
    final selection = editorState.selection;
    if (selection != null) _lastSelection = selection;
  }

  /// Selección vigente o, si el editor la perdió al perder el foco, la última conocida.
  Selection? get _selection => editorState.selection ?? _lastSelection;

  /// Devuelve la selección al editor antes de aplicar un comando; `false` si nunca hubo una.
  bool _restoreSelection() {
    if (editorState.selection != null) return true;
    final last = _lastSelection;
    if (last == null) return false;
    editorState.selection = last;
    return true;
  }

  void _onChanged() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(debounce, _saveNow);
  }

  /// Serializa el documento a Markdown (conservando los bloques intactos).
  String content() {
    final blocks = EditorAdapter.toBlocks(editorState.document);
    return MarkdownSerializer.serialize(MdNode.doc(blocks));
  }

  /// Guarda ya, si hay cambios.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (!_dirty) return;
    await _saveNow();
  }

  Future<void> _saveNow() async {
    final next = content();
    if (next == _savedContent) {
      _dirty = false;
      return;
    }
    _savedContent = next;
    _dirty = false;
    await save(content: next);
  }

  /// Guarda un título nuevo (sin espera).
  Future<void> saveTitle(String title) async {
    if (title == note.title) return;
    await save(title: title);
  }

  // ── Comandos de la barra de formato ──

  /// Tipo del bloque en el cursor: `paragraph`, `heading`, `bulleted_list`, `todo_list`…
  String? get blockType {
    final selection = _selection;
    if (selection == null) return null;
    final node = editorState.getNodeAtPath(selection.start.path);
    return node?.type;
  }

  void _toggle(String key) {
    if (_restoreSelection()) editorState.toggleAttribute(key);
  }

  void toggleBold() => _toggle(AppFlowyRichTextKeys.bold);

  void toggleItalic() => _toggle(AppFlowyRichTextKeys.italic);

  void toggleStrike() => _toggle(AppFlowyRichTextKeys.strikethrough);

  void toggleUnderline() => _toggle(AppFlowyRichTextKeys.underline);

  void toggleCode() => _toggle(AppFlowyRichTextKeys.code);

  /// Cambia el estilo de párrafo del bloque actual (párrafo, título 1‑3, cita, código).
  void setBlockType(String type, {int level = 1}) {
    if (!_restoreSelection()) return;
    final selection = editorState.selection!;
    editorState.formatNode(
      selection,
      // `copyWith(attributes:)` REEMPLAZA los atributos, y el texto (`delta`) vive en ellos: hay que
      // partir siempre de los atributos del nodo o la nota pierde el contenido del bloque.
      (node) => node.type == type && node.attributes['level'] == level
          ? node.copyWith(
              type: 'paragraph',
              attributes: {...node.attributes}..remove('level'),
            )
          : node.copyWith(
              type: type,
              attributes: {...node.attributes, 'level': level},
            ),
    );
  }

  /// Alterna una lista (viñetas o tareas) en el bloque actual.
  void toggleList(String type) {
    if (!_restoreSelection()) return;
    final selection = editorState.selection!;
    editorState.formatNode(
      selection,
      (node) => node.copyWith(
        type: node.type == type ? 'paragraph' : type,
        attributes: {
          ...node.attributes,
          if (type == 'todo_list' && node.type != type) 'checked': false,
        },
      ),
    );
  }

  /// `true` si la marca está activa en el cursor (para el estado activo de la barra).
  bool isMarkActive(String key) {
    final selection = _selection;
    if (selection == null || !selection.isSingle) return false;
    final node = editorState.getNodeAtPath(selection.start.path);
    final delta = node?.delta;
    if (delta == null) return false;
    final offset = selection.start.offset;
    var position = 0;
    for (final operation in delta) {
      if (operation is! TextInsert) continue;
      final start = position;
      final end = position + operation.text.length;
      if (offset >= start && offset <= end) {
        return operation.attributes?[key] == true;
      }
      position = end;
    }
    return false;
  }

  /// Mantiene el foco (y el teclado) en el editor mientras la barra abre un menú; sin esto AppFlowy
  /// cierra el teclado y borra la selección al perder el foco.
  void holdEditorFocus() => keepEditorFocusNotifier.increase();

  void releaseEditorFocus() => keepEditorFocusNotifier.decrease();

  void undo() => editorState.undoManager.undo();

  void dispose() {
    editorState.selectionNotifier.removeListener(_rememberSelection);
    _timer?.cancel();
    _subscription?.cancel();
  }
}
