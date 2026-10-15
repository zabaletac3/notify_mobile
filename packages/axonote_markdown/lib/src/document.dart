/// Documento de nota con conservación por bloque (§8.2.4 del plan).
///
/// Al cargar se calcula la huella estructural de cada bloque de primer nivel. Al guardar, un bloque
/// con la misma huella se emite con su texto original byte a byte; un bloque cambiado, nuevo o
/// movido pasa por el serializador. Los separadores originales se conservan entre bloques intactos;
/// en los demás casos, `\n\n`.
library;

import 'parser.dart';
import 'serializer.dart';

/// Una nota como secuencia de bloques editables.
class MarkdownDocument {
  MarkdownDocument._(this._original, this.blocks);

  final String _original;

  /// Bloques de primer nivel, en orden. Editarlos cambia lo que se guarda.
  final List<MarkdownBlock> blocks;

  /// Analiza el texto de una nota.
  static MarkdownDocument parse(String source) {
    final parsed = MarkdownParser.parseDetailed(source);
    for (final block in parsed.blocks) {
      block.fingerprint = block.node.fingerprint;
    }
    return MarkdownDocument._(source, parsed.blocks);
  }

  /// `true` si ningún bloque cambió desde el análisis.
  bool get isUnchanged =>
      blocks.every((b) => b.node.fingerprint == b.fingerprint);

  /// Guarda: reconstruye el Markdown conservando los bloques intactos byte a byte.
  String save() {
    if (isUnchanged) return _original;

    final buffer = StringBuffer();
    var previousUnchanged = false;
    var first = true;
    for (final block in blocks) {
      final unchanged = block.node.fingerprint == block.fingerprint;
      final separator = first
          ? (unchanged ? block.separatorBefore : '')
          : ((previousUnchanged && unchanged) ? block.separatorBefore : '\n\n');
      buffer.write(separator);
      buffer.write(
        unchanged ? block.source : MarkdownSerializer.renderBlock(block.node),
      );
      previousUnchanged = unchanged;
      first = false;
    }
    return buffer.toString();
  }
}
