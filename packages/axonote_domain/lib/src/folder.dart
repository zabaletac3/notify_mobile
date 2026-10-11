import 'ids.dart';

/// Una carpeta tal como la ve la aplicación (el nombre en claro).
class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final Id id;
  final String name;
  final IsoDate createdAt;
  final IsoDate updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Folder &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt);
}

/// Longitud máxima del nombre de una carpeta (igual que `FOLDER_NAME_MAX_LENGTH` de la web).
const int folderNameMaxLength = 30;
