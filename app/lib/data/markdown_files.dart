import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:file_picker/file_picker.dart';

/// Selección de archivos Markdown para importar, ya parseados.
class ImportSelection {
  const ImportSelection({required this.notes, required this.skipped});

  final List<ImportedNote> notes;
  final int skipped;
}

/// Abre el selector del sistema y convierte los `.md`/`.markdown`/`.txt` elegidos en notas. Los
/// archivos de más de [importMaxBytes] o que no se pueden leer se cuentan en `skipped`
/// (`notify_web` hace lo mismo).
Future<ImportSelection> pickMarkdownNotes() async {
  final files = await FilePicker.pickFiles(
    dialogTitle: 'Importar notas',
    type: FileType.custom,
    allowedExtensions: const ['md', 'markdown', 'txt'],
  );
  final notes = <ImportedNote>[];
  var skipped = 0;
  for (final file in files) {
    final length = await file.length();
    if (length == null || length > importMaxBytes) {
      skipped++;
      continue;
    }
    try {
      final bytes = await file.readAsBytes();
      notes.add(
        parseMarkdownNote(file.name, utf8.decode(bytes, allowMalformed: true)),
      );
    } catch (_) {
      skipped++;
    }
  }
  return ImportSelection(notes: notes, skipped: skipped);
}

/// Guarda un `.md` con el selector del sistema. `false` si la persona cancela.
Future<bool> saveMarkdownFile({
  required String fileName,
  required String markdown,
}) async {
  final uri = await FilePicker.saveFile(
    dialogTitle: 'Exportar nota',
    fileName: fileName,
    mimeType: 'text/markdown',
    bytes: Uint8List.fromList(utf8.encode(markdown)),
  );
  return uri != null;
}

/// Guarda un `.zip` con un `.md` por nota (como «Exportar todas las notas» de la web).
Future<bool> saveNotesZip({
  required String fileName,
  required List<Note> notes,
}) async {
  final uri = await FilePicker.saveFile(
    dialogTitle: 'Exportar notas',
    fileName: fileName,
    mimeType: 'application/zip',
    bytes: buildNotesZip(notes),
  );
  return uri != null;
}

/// Empaqueta las notas en un `.zip` (un `.md` por nota). Nombres únicos y sin caracteres que no
/// valen en un nombre de archivo.
Uint8List buildNotesZip(List<Note> notes) {
  final archive = Archive();
  final used = <String>{};
  for (final note in notes) {
    final base = _safeName(note.title);
    var name = '$base.md';
    var suffix = 2;
    while (!used.add(name)) {
      name = '$base ($suffix).md';
      suffix++;
    }
    final data = utf8.encode(exportNoteMarkdown(note.title, note.content));
    archive.add(ArchiveFile(name, data.length, data));
  }
  return ZipEncoder().encodeBytes(archive);
}

final RegExp _invalidName = RegExp(r'[\\/:*?"<>|\x00-\x1f]');

String _safeName(String title) {
  final cleaned = title.replaceAll(_invalidName, '-').trim();
  return cleaned.isEmpty ? 'nota' : cleaned;
}
