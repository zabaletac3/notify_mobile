import 'dart:typed_data';

/// Un archivo elegido por la persona (solo lo que el editor usa al insertar una imagen).
///
/// Sustituye al `PlatformFile` de `file_picker` para no depender de ese paquete (choca con
/// `win32` 6 de `flutter_secure_storage`; ver `PATCHES.md`).
class PickedFile {
  const PickedFile({required this.path, this.bytes});

  /// Ruta del archivo en disco.
  final String path;

  /// Contenido, cuando se pidió `withData`.
  final Uint8List? bytes;
}

class FilePickerResult {
  const FilePickerResult(this.files);

  /// Archivos elegidos.
  final List<PickedFile> files;
}

/// Qué tipo de archivo se puede elegir (equivalente al `FileType` de `file_picker`).
enum PickedFileType { any, image, custom }

/// Abstract file picker as a service to implement dependency injection.
abstract class FilePickerService {
  Future<String?> getDirectoryPath({String? title}) async =>
      throw UnimplementedError('getDirectoryPath() has not been implemented.');

  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    PickedFileType type = PickedFileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
  }) async =>
      throw UnimplementedError('pickFiles() has not been implemented.');

  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    PickedFileType type = PickedFileType.any,
    List<String>? allowedExtensions,
    bool lockParentWindow = false,
  }) async =>
      throw UnimplementedError('saveFile() has not been implemented.');
}
