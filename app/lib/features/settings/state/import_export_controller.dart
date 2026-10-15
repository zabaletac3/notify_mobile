import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_session.dart';
import '../../../data/markdown_files.dart';

/// Resultado de importar archivos: cuántas notas se crearon y cuántos archivos se omitieron.
class ImportOutcome {
  const ImportOutcome({required this.created, required this.skipped});

  final int created;
  final int skipped;
}

/// Importar y exportar notas en Markdown (plan §10, fase 11.5). La interfaz solo habla con este
/// estado; el acceso a los archivos y al `.zip` vive en `app/lib/data/markdown_files.dart`.
class ImportExportController {
  ImportExportController(this._ref);

  final Ref _ref;

  NoteRepository? get _notes => _ref.read(noteRepositoryProvider);

  /// Elige archivos `.md`/`.markdown`/`.txt`, los parsea y crea las notas.
  Future<Result<ImportOutcome>> importNotes() async {
    return _run(() async {
      final notes = _notes;
      if (notes == null) throw const AppFailure(LockedError());
      final selection = await pickMarkdownNotes();
      var created = 0;
      var failed = 0;
      for (final draft in selection.notes) {
        try {
          await notes.create(
            NoteDraft(title: draft.title, content: draft.content),
          );
          created++;
        } catch (_) {
          failed++;
        }
      }
      return ImportOutcome(
        created: created,
        skipped: selection.skipped + failed,
      );
    });
  }

  /// Exporta todas las notas (sin la papelera) como un `.zip` de Markdown. `false` si se cancela.
  Future<Result<bool>> exportAllNotes() async {
    return _run(() async {
      final notes = _notes;
      if (notes == null) throw const AppFailure(LockedError());
      final all = await notes.list(const NoteQuery(sort: NoteSort.title));
      return saveNotesZip(fileName: 'axonote-notas.zip', notes: all);
    });
  }

  /// Exporta una nota como `.md`. `false` si se cancela.
  Future<Result<bool>> exportNote(Id noteId) async {
    return _run(() async {
      final notes = _notes;
      if (notes == null) throw const AppFailure(LockedError());
      final note = await notes.get(noteId);
      final name = note.title.trim().isEmpty ? 'nota' : note.title.trim();
      return saveMarkdownFile(
        fileName: '$name.md',
        markdown: exportNoteMarkdown(note.title, note.content),
      );
    });
  }

  Future<Result<T>> _run<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on AppFailure catch (failure) {
      return Err(failure.error);
    } catch (_) {
      return const Err(UnknownError());
    }
  }
}

final importExportControllerProvider = Provider<ImportExportController>(
  ImportExportController.new,
);
