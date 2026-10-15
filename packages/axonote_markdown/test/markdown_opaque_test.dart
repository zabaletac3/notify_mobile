import 'package:axonote_markdown/axonote_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('bloque opaco (§8.2.5)', () {
    const cases = {
      'tabla': '| a | b |\n| - | - |\n| 1 | 2 |',
      'html-de-bloque': '<div>\n<p>hola</p>\n</div>',
      'nota-al-pie': '[^1]: Nota al pie.',
      'imagen-en-linea': 'texto ![alt](https://example.com/x.png) texto',
    };

    cases.forEach((name, source) {
      test('$name: se analiza como opaco y se conserva byte a byte', () {
        final doc = MarkdownDocument.parse(source);
        expect(doc.blocks, isNotEmpty);
        expect(doc.blocks.first.node.type, MdNodeType.opaque);
        expect(doc.save(), source);
      });

      test('$name: el serializador lo emite intacto (forzado)', () {
        final tree = MarkdownParser.parse(source);
        expect(MarkdownSerializer.serialize(tree), source);
      });
    });

    test('un bloque opaco convive con bloques normales', () {
      const source = 'antes\n\n| a | b |\n| - | - |\n| 1 | 2 |\n\ndespués';
      final doc = MarkdownDocument.parse(source);
      expect(doc.blocks, hasLength(3));
      expect(doc.blocks[1].node.type, MdNodeType.opaque);
      expect(doc.save(), source);

      // Editar el primer bloque no toca la tabla.
      doc.blocks[0].node = MdNode.paragraph([MdNode.textNode('cambiado')]);
      final saved = doc.save();
      expect(saved.contains('| a | b |\n| - | - |\n| 1 | 2 |'), isTrue);
      expect(saved.startsWith('cambiado'), isTrue);
    });

    test('la imagen del párrafo cubre todas sus líneas', () {
      const source = 'texto ![alt](x.png) texto\nsegunda línea';
      final doc = MarkdownDocument.parse(source);
      expect(doc.blocks.single.node.type, MdNodeType.opaque);
      expect(doc.save(), source);
    });
  });
}
