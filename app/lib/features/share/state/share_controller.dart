import 'dart:async';

import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_session.dart';
import '../../../bootstrap/providers.dart';
import '../../../data/crypto/share_codec.dart';
import '../../../data/crypto/vault.dart';
import '../../vault/state/vault_lock.dart';

/// Enlaces públicos de solo lectura («Compartir nota») con cifrado de extremo a extremo: la nota se
/// copia cifrada con una clave propia del enlace y esa clave viaja solo en el fragmento de la URL.
/// Portado de `notify_web/src/lib/features/share/state/share.svelte.ts`.
class ShareState {
  const ShareState({
    this.links = const <Id, ShareLink>{},
    this.busy = false,
    this.error,
  });

  final Map<Id, ShareLink> links;
  final bool busy;
  final AppError? error;

  ShareLink? linkFor(Id noteId) => links[noteId];

  ShareState copyWith({
    Map<Id, ShareLink>? links,
    bool? busy,
    Object? error = _unset,
  }) => ShareState(
    links: links ?? this.links,
    busy: busy ?? this.busy,
    error: identical(error, _unset) ? this.error : error as AppError?,
  );

  static const Object _unset = Object();
}

final shareControllerProvider = NotifierProvider<ShareController, ShareState>(
  ShareController.new,
);

class ShareController extends Notifier<ShareState> {
  @override
  ShareState build() => const ShareState();

  ShareRepository? get _repo => ref.read(shareRepositoryProvider);

  Vault? _vault() {
    try {
      return ref.read(vaultLockControllerProvider).vault;
    } on VaultLockedError {
      return null;
    }
  }

  /// Crea el enlace (o devuelve el que ya existe).
  Future<Result<ShareLink>> create(Id noteId) => _run(() async {
    final repo = _repo;
    final vault = _vault();
    final notes = ref.read(noteRepositoryProvider);
    if (repo == null || vault == null || notes == null) {
      throw const AppFailure(LockedError());
    }
    final note = await notes.get(noteId);
    if (note.unreadable) {
      throw const AppFailure(DecryptError());
    }
    final stored = await repo.createLink(
      noteId,
      await createShare(
        vault,
        noteId: noteId,
        title: note.title,
        content: note.content,
      ),
    );
    return _remember(stored);
  });

  /// Trae el enlace que ya tiene la nota (al abrir «Compartir», p. ej. tras recargar).
  Future<Result<ShareLink?>> load(Id noteId) => _run(() async {
    final repo = _repo;
    final vault = _vault();
    if (repo == null || vault == null) {
      throw const AppFailure(LockedError());
    }
    final stored = await repo.getLink(noteId);
    if (stored == null) return _forget(noteId);
    return _remember(stored);
  });

  Future<Result<void>> revoke(Id noteId) => _run(() async {
    final repo = _repo;
    if (repo == null) {
      throw const AppFailure(LockedError());
    }
    await repo.revokeLink(noteId);
    _forget(noteId);
  });

  /// La nota compartida cambió: se actualiza su copia pública. No hace nada si la nota no tiene
  /// enlace. Se llama desde el guardado del editor (§8.3, plan §385).
  Future<void> republish(Id noteId) async {
    if (state.links[noteId] == null) return;
    final vault = _vault();
    final repo = _repo;
    final notes = ref.read(noteRepositoryProvider);
    if (vault == null || repo == null || notes == null) return;
    try {
      final note = await notes.get(noteId);
      final stored = await repo.getLink(noteId);
      if (stored == null) return;
      final key = await openShareKey(vault, stored);
      await repo.updateLinkPayload(
        noteId,
        await sealSharedNote(
          key,
          stored.slug,
          title: note.title,
          content: note.content,
        ),
      );
    } catch (_) {
      // Best-effort: se reintenta con la siguiente edición (igual que la web).
    }
  }

  /// Lee una nota compartida desde su URL (sin sesión). Un enlace revocado, inexistente o con la
  /// clave equivocada dan el mismo resultado: `not-found` (§ de la web).
  Future<Result<SharedNoteContent>> open(String slug, String fragment) =>
      _run(() async {
        final repo = _repo;
        if (repo == null) {
          throw const AppFailure(LockedError());
        }
        final public = await repo.readPublic(slug);
        return openSharedNote(slug, fragment, public.payload, public.updatedAt);
      });

  /// Guarda el enlace en memoria con su URL completa (la clave sale de la copia del servidor).
  Future<ShareLink> _remember(SharedNote stored) async {
    final vault = _vault()!;
    final key = await openShareKey(vault, stored);
    final link = ShareLink(
      id: stored.id,
      noteId: stored.noteId,
      url: shareUrl(ref.read(shareOriginProvider), stored, key),
      createdAt: stored.createdAt,
    );
    state = state.copyWith(links: {...state.links, stored.noteId: link});
    return link;
  }

  ShareLink? _forget(Id noteId) {
    final next = Map<Id, ShareLink>.of(state.links)..remove(noteId);
    state = state.copyWith(links: next);
    return null;
  }

  Future<Result<T>> _run<T>(Future<T> Function() action) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final value = await action();
      state = state.copyWith(busy: false);
      return Ok(value);
    } on AppFailure catch (failure) {
      state = state.copyWith(busy: false, error: failure.error);
      return Err(failure.error);
    } catch (_) {
      state = state.copyWith(busy: false, error: const UnknownError());
      return const Err(UnknownError());
    }
  }
}
