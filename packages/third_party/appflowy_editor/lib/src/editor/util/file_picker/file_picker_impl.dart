import 'package:appflowy_editor/src/editor/util/file_picker/file_picker_service.dart';

/// En AxoNote la selección de archivos está fuera de alcance: las imágenes se tratan como bloque
/// opaco y no se insertan. El editor no usa este servicio (ver `PATCHES.md`).
class FilePicker implements FilePickerService {
  @override
  Future<String?> getDirectoryPath({String? title}) async =>
      throw UnsupportedError('AxoNote no elige archivos');

  @override
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
      throw UnsupportedError('AxoNote no elige archivos');

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    PickedFileType type = PickedFileType.any,
    List<String>? allowedExtensions,
    bool lockParentWindow = false,
  }) async =>
      throw UnsupportedError('AxoNote no elige archivos');
}
