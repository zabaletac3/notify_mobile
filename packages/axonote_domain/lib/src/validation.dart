import 'folder.dart';
import 'note_text.dart';

/// Códigos de validación. El texto en español vive en la capa de interfaz.
typedef ValidationCode = String;

/// Errores por campo.
typedef FieldErrors = Map<String, ValidationCode>;

/// Resultado de una validación: válida o con errores por campo.
sealed class Validation {
  const Validation();
}

final class Valid extends Validation {
  const Valid();
}

final class Invalid extends Validation {
  const Invalid(this.errors);

  final FieldErrors errors;
}

/// Nombre de carpeta: 1–30 caracteres y único (sin distinguir mayúsculas ni tildes).
/// Portado de `validateFolderName` de `notify_web/src/lib/domain/validation.ts`.
Validation validateFolderName(String name, List<String> existing) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return const Invalid({'name': 'required'});
  if (trimmed.length > folderNameMaxLength) {
    return const Invalid({'name': 'name-too-long'});
  }
  final folded = foldText(trimmed);
  if (existing.any((e) => foldText(e) == folded)) {
    return const Invalid({'name': 'name-taken'});
  }
  return const Valid();
}
