import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_session.dart';

/// Acciones de la persona sobre las notas y carpetas (fijar, duplicar, mover, papelera…). No
/// lanzan: devuelven [Result] para que la interfaz decida qué aviso mostrar (§4.3).
class NotesActions {
  NotesActions(this._ref);

  final Ref _ref;

  NoteRepository? get _notes => _ref.read(noteRepositoryProvider);
  FolderRepository? get _folders => _ref.read(folderRepositoryProvider);

  Future<Result<Note>> create({Id? folderId, String? title}) =>
      _run(() => _notes!.create(NoteDraft(folderId: folderId, title: title)));

  Future<Result<Note>> rename(Id id, String title) =>
      _run(() => _notes!.update(id, NoteDraft(title: title)));

  Future<Result<Note>> togglePin(Note note) =>
      _run(() => _notes!.update(note.id, NoteDraft(pinned: !note.pinned)));

  Future<Result<Note>> duplicate(Id id) => _run(() => _notes!.duplicate(id));

  Future<Result<Note>> moveToFolder(Id id, Id? folderId) => _run(
    () => _notes!.update(
      id,
      // `folderIdPresent` distingue «mover a sin carpeta» de «no tocar la carpeta».
      NoteDraft(folderId: folderId, folderIdPresent: true),
    ),
  );

  Future<Result<Note>> moveToTrash(Id id) =>
      _run(() => _notes!.moveToTrash(id));

  Future<Result<Note>> restore(Id id) => _run(() => _notes!.restore(id));

  Future<Result<void>> deleteForever(Id id) =>
      _run(() async => _notes!.deleteForever(id));

  Future<Result<int>> emptyTrash() => _run(() => _notes!.emptyTrash());

  Future<Result<Folder>> createFolder(String name) =>
      _run(() => _folders!.create(name));

  Future<Result<void>> renameFolder(Id id, String name) =>
      _run(() async => _folders!.rename(id, name));

  Future<Result<void>> deleteFolder(Id id) =>
      _run(() async => _folders!.delete(id));

  /// Ejecuta [action] y traduce cualquier fallo a [Err]. Un fallo que no sea [AppFailure] se
  /// convierte en [UnknownError] (nunca se expone el mensaje de la excepción).
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

final notesActionsProvider = Provider<NotesActions>(NotesActions.new);
