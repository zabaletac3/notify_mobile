import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/local_session.dart';
import '../../../ui/components.dart';
import '../state/editor_controller.dart';
import '../state/editor_providers.dart';
import 'editor_view.dart';

/// Pantalla del editor de una nota (`/notes/:id`). Conecta el repositorio con la vista pura
/// ([EditorView]); la vista no conoce proveedores ni servicios.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.noteId});

  final Id noteId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
  NoteEditorController? _controller;
  final _titleController = TextEditingController();
  RevisionToken? _loaded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al ir a segundo plano se guarda lo pendiente (§8.3).
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller?.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) {
      controller.flush();
      controller.dispose();
    }
    _titleController.dispose();
    super.dispose();
  }

  /// Crea el controlador una sola vez por revisión de la nota (recarga al llegar por sincronización
  /// si no hay cambios locales; §8.3).
  void _ensureController(Note note) {
    final token = RevisionToken(note.id, note.revision, note.content);
    if (_loaded == token) return;
    // Con cambios locales pendientes no se pisa lo que se está escribiendo.
    if (_loaded != null &&
        _loaded!.id == note.id &&
        (_controller?.isDirty ?? false)) {
      return;
    }
    _controller?.dispose();
    final controller = NoteEditorController(
      note: note,
      save: ({String? title, String? content}) async {
        final repo = ref.read(noteRepositoryProvider);
        if (repo == null) return;
        await repo.update(note.id, NoteDraft(title: title, content: content));
      },
    )..start();
    _controller = controller;
    _loaded = token;
    _titleController.text = note.title;
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteByIdProvider(widget.noteId));

    return noteAsync.when(
      loading: () => const EditorScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => EditorScaffold(
        onBack: () => context.go('/notes'),
        child: Center(
          child: AxoEmptyState(
            danger: true,
            illustrationText: '!',
            title: 'No pudimos abrir la nota',
            subtitle: 'Vuelve a la lista e inténtalo otra vez.',
            footer: AxoButton(
              label: 'Volver a las notas',
              variant: AxoButtonVariant.outline,
              onPressed: () => context.go('/notes'),
            ),
          ),
        ),
      ),
      data: (note) {
        _ensureController(note);
        final controller = _controller!;
        return EditorView(
          note: note,
          controller: controller,
          titleController: _titleController,
          onTitleChanged: controller.saveTitle,
          folderName: ref.watch(noteFolderProvider(widget.noteId)).value,
          onBack: () => context.go('/notes'),
          onShare: () {},
          onMore: () {},
        );
      },
    );
  }
}

/// Token que identifica (id, revisión, contenido) para decidir si hay que recargar el editor.
class RevisionToken {
  const RevisionToken(this.id, this.revision, this.content);

  final Id id;
  final int revision;
  final String content;

  @override
  bool operator ==(Object other) =>
      other is RevisionToken &&
      other.id == id &&
      other.revision == revision &&
      other.content == content;

  @override
  int get hashCode => Object.hash(id, revision, content);
}
