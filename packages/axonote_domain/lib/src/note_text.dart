/// Utilidades puras para el texto Markdown de una nota. Portadas de
/// `notify_web/src/lib/domain/note-text.ts`.
library;

/// Quita sintaxis Markdown para mostrar una vista previa de una línea.
String derivePreview(String content, [int maxLength = 90]) {
  final text = content
      .split('\n')
      .map((line) {
        var l = line;
        l = l.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), ''); // títulos
        l = l.replaceFirst(RegExp(r'^\s*>\s?'), ''); // citas
        l = l.replaceFirst(RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s+'), ''); // tareas
        l = l.replaceFirst(RegExp(r'^\s*([-*+]|\d+\.)\s+'), ''); // listas
        l = l.replaceAllMapped(
          RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
          (m) => m.group(1) ?? '',
        ); // imágenes
        l = l.replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]*\)'),
          (m) => m.group(1) ?? '',
        ); // enlaces
        l = l.replaceAll(RegExp(r'[*_`~]+'), ''); // énfasis y código
        return l.trim();
      })
      .where((line) => line.isNotEmpty)
      .join(' ');
  return text.length > maxLength
      ? '${text.substring(0, maxLength - 1).trimRight()}…'
      : text;
}

/// Cuenta palabras ignorando la sintaxis Markdown básica.
int countWords(String content) {
  final words = content
      .replaceAll(RegExp(r'''[#>*_`~\[\]()!-]'''), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words.length;
}

/// Normaliza una etiqueta: sin `#`, minúsculas, espacios → guiones.
String normalizeTag(String tag) {
  return tag
      .trim()
      .replaceFirst(RegExp(r'^#+'), '')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^\p{L}\p{N}_-]', unicode: true), '');
}

const Map<String, String> _diacritics = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'ď': 'd',
  'đ': 'd',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ĕ': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'ğ': 'g',
  'ĝ': 'g',
  'ġ': 'g',
  'ģ': 'g',
  'ĥ': 'h',
  'ħ': 'h',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ĩ': 'i',
  'ī': 'i',
  'ĭ': 'i',
  'į': 'i',
  'ı': 'i',
  'ĵ': 'j',
  'ķ': 'k',
  'ĸ': 'k',
  'ĺ': 'l',
  'ļ': 'l',
  'ľ': 'l',
  'ŀ': 'l',
  'ł': 'l',
  'ñ': 'n',
  'ń': 'n',
  'ņ': 'n',
  'ň': 'n',
  'ŉ': 'n',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'ō': 'o',
  'ŏ': 'o',
  'ő': 'o',
  'œ': 'oe',
  'ŕ': 'r',
  'ŗ': 'r',
  'ř': 'r',
  'ś': 's',
  'ŝ': 's',
  'ş': 's',
  'š': 's',
  'ß': 'ss',
  'ţ': 't',
  'ť': 't',
  'ŧ': 't',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ũ': 'u',
  'ū': 'u',
  'ŭ': 'u',
  'ů': 'u',
  'ű': 'u',
  'ų': 'u',
  'ŵ': 'w',
  'ý': 'y',
  'ÿ': 'y',
  'ŷ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
};

/// Quita acentos y pasa a minúsculas (para búsquedas insensibles a tildes). Dart no trae
/// normalización NFD, así que se usa una tabla de diacríticos latinos (la base local usa FTS5
/// con `remove_diacritics`, ver plan §6 y decisión de la fase 6).
String foldText(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_diacritics[ch] ?? ch);
  }
  return buffer.toString();
}
