/// Importación y exportación de notas en Markdown. Portado de
/// `notify_web/src/lib/domain/markdown-import.ts`.
library;

/// Una nota lista para crear a partir de un archivo Markdown.
class ImportedNote {
  const ImportedNote({required this.title, required this.content});

  final String title;
  final String content;
}

/// Largo máximo del título de una nota importada.
const int importTitleMaxLength = 200;

/// Tamaño máximo de un archivo a importar (un `.md` normal pesa muy por debajo).
const int importMaxBytes = 2 * 1024 * 1024;

final RegExp _extensionPattern = RegExp(
  r'\.(md|markdown|txt)$',
  caseSensitive: false,
);
final RegExp _headingPattern = RegExp(r'^#\s+(.+?)\s*#*\s*$', multiLine: false);

String _stripExtension(String name) =>
    name.replaceFirst(_extensionPattern, '').trim();

/// Convierte el texto de un archivo Markdown en una nota. Si empieza con un título `# …` (como lo
/// escribe la exportación de AxoNote) ese título pasa a ser el de la nota y se quita del texto; si
/// no, el título es el nombre del archivo. Quita el BOM y unifica los saltos de línea.
ImportedNote parseMarkdownNote(String fileName, String text) {
  final normalized = text
      .replaceFirst(RegExp(r'^\uFEFF'), '')
      .replaceAll(RegExp(r'\r\n?'), '\n');
  final lines = normalized.split('\n');
  final first = lines.indexWhere((line) => line.trim().isNotEmpty);
  final heading = first >= 0 ? _headingPattern.firstMatch(lines[first]) : null;

  final String title;
  final List<String> rest;
  if (heading != null) {
    title = heading.group(1)!.trim();
    rest = lines.sublist(first + 1);
  } else {
    final stripped = _stripExtension(fileName);
    title = stripped.isEmpty ? 'Sin título' : stripped;
    rest = lines.sublist(first >= 0 ? first : 0);
  }
  final content = rest
      .join('\n')
      .replaceFirst(RegExp(r'^\n+'), '')
      .replaceFirst(RegExp(r'\s+$'), '');
  return ImportedNote(
    title: title.length > importTitleMaxLength
        ? title.substring(0, importTitleMaxLength)
        : title,
    content: content,
  );
}

/// Serializa una nota a Markdown con el mismo formato que exporta la web.
String exportNoteMarkdown(String title, String content) =>
    '# $title\n\n$content\n';
