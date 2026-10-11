import 'package:axonote_domain/axonote_domain.dart';

/// Atajos para lanzar el error de aplicación correcto (mismos `kind` que la web). Los repositorios
/// solo lanzan `AppFailure`.
Never failNotFound(String entity) =>
    throw AppFailure(NotFoundError(entity: entity));

Never failValidation(Map<String, String> fields) =>
    throw AppFailure(ValidationError(fields));

Never failDecrypt() => throw const AppFailure(DecryptError());

Never failLocked() => throw const AppFailure(LockedError());

Never failConflict({String? noteId, String? code}) =>
    throw AppFailure(ConflictError(noteId: noteId, code: code));
