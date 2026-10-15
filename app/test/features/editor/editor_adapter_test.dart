import 'package:axonote_app/features/editor/state/editor_adapter.dart';
import 'package:axonote_markdown/axonote_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String roundTrip(String source) {
    final blocks = MarkdownParser.parse(source).content;
    final document = EditorAdapter.toDocument(blocks);
    final back = EditorAdapter.toBlocks(document);
    return MarkdownSerializer.serialize(MdNode.doc(back));
  }

  group('adaptador bloques ↔ nodos de AppFlowy', () {
    const supported = [
      'Hola, mundo.',
      '# Título uno',
      '###### Título seis',
      'Texto en **negrita** y normal.',
      'Texto en *cursiva*, ~~tachado~~ y `código`.',
      '[AxoNote](https://apunte.app)',
      '- uno\n- dos\n- tres',
      '1. uno\n2. dos',
      '- [ ] pendiente\n- [x] hecha',
      '- uno\n  - uno.a\n    - uno.a.i',
      '> Una cita célebre.',
      '```js\nconst a = 1;\n```',
      'antes\n\n---\n\ndespués',
      '# Título principal\n\nUn párrafo.\n\n## Subtítulo\n\n- viñeta uno\n- viñeta dos',
    ];

    for (final source in supported) {
      test('ida y vuelta: ${source.split('\n').first}', () {
        expect(roundTrip(source), source);
      });
    }

    test('el bloque opaco viaja como nodo propio y vuelve intacto', () {
      const table = '| a | b |\n| - | - |\n| 1 | 2 |';
      final blocks = MarkdownParser.parse(table).content;
      final document = EditorAdapter.toDocument(blocks);
      expect(document.root.children.first.type, EditorNodeType.opaque);
      expect(
        MarkdownSerializer.serialize(
          MdNode.doc(EditorAdapter.toBlocks(document)),
        ),
        table,
      );
    });

    test('un documento vacío no rompe', () {
      expect(
        EditorAdapter.toBlocks(EditorAdapter.toDocument(const [])),
        isEmpty,
      );
    });
  });
}
