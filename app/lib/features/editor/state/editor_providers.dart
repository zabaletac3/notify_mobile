import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_session.dart';

/// Carga una nota por id desde la base local. `null` si el cofre está bloqueado.
final noteByIdProvider = FutureProvider.family<Note, Id>((ref, id) async {
  final repo = ref.watch(noteRepositoryProvider);
  if (repo == null) {
    throw StateError('La base local no está abierta');
  }
  return repo.get(id);
});

/// Nombre de la carpeta de una nota (`null` si no tiene). Para el chip de la barra superior.
final noteFolderProvider = FutureProvider.family<String?, Id>((ref, id) async {
  final note = await ref.watch(noteByIdProvider(id).future);
  final folderId = note.folderId;
  if (folderId == null) return null;
  final repo = ref.watch(folderRepositoryProvider);
  if (repo == null) return null;
  final folders = await repo.list();
  for (final folder in folders) {
    if (folder.id == folderId) return folder.name;
  }
  return null;
});
