/// Códec de Markdown de AxoNote: modelo de bloques, analizador, serializador y conservación por
/// bloque.
///
/// Dart puro (sin Flutter). Es el códec propio de la decisión D2; reproduce byte a byte el formato
/// que emite y lee el editor de la web (TipTap 3), fijado por `contract/vectors/markdown.json`.
library;

export 'src/ast.dart';
export 'src/document.dart';
export 'src/parser.dart';
export 'src/serializer.dart';
