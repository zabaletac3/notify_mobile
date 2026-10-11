/// Traduce un texto de búsqueda a una consulta FTS5 segura (prefijos). A7: sin tolerancia a
/// errores de tipeo; las tildes las resuelve el tokenizador (`remove_diacritics 2`).
String? ftsMatch(String term) {
  final tokens = term
      .trim()
      .split(RegExp(r'\s+'))
      .map((t) => t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return null;
  return tokens.map((t) => '"$t"*').join(' ');
}
