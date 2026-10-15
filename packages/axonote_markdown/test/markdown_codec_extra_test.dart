import 'package:axonote_markdown/axonote_markdown.dart';
import 'package:test/test.dart';

void main() {
  group('modelo', () {
    test('MdMark: json, igualdad, hash y toString', () {
      const link = MdMark(MdMarkType.link, href: 'https://a', title: 't');
      expect(link.toJson(), {
        'type': 'link',
        'attrs': {'href': 'https://a', 'title': 't'},
      });
      expect(MdMark.fromJson(link.toJson()), link);
      expect(link, isNot(MdMark.bold));
      expect(link, isNot(equals(1)));
      expect(link.toString(), contains('link'));
      expect(link.hashCode, MdMark.fromJson(link.toJson()).hashCode);

      const hrefOnly = MdMark(MdMarkType.link, href: 'https://a');
      expect(MdMark.fromJson(hrefOnly.toJson()), hrefOnly);
      expect(hrefOnly.copyWith(title: 'x').title, 'x');

      expect(MdMark.bold.toJson(), {'type': 'bold'});
      expect(MdMark.fromJson({'type': 'bold'}), MdMark.bold);
      expect(
        MdMark.fromJson({
          'type': 'bold',
          'attrs': {'n': 1},
        }),
        MdMark.bold,
      );
    });

    test('MdNode: json de ida y vuelta de un documento completo', () {
      final doc = MdNode.doc([
        MdNode.heading(2, [MdNode.textNode('hola')]),
        MdNode.paragraph([
          MdNode.textNode('a', const [MdMark.bold, MdMark.italic]),
          MdNode.hardBreak,
          MdNode.textNode('b', const [MdMark.code]),
        ]),
        MdNode.orderedList(3, [
          MdNode.listItem([
            MdNode.paragraph([MdNode.textNode('x')]),
          ]),
        ]),
        MdNode.taskList([
          MdNode.taskItem(true, [
            MdNode.paragraph([MdNode.textNode('y')]),
          ]),
        ]),
        MdNode.blockquote([
          MdNode.paragraph([MdNode.textNode('q')]),
        ]),
        MdNode.codeBlock('dart', 'void main() {}'),
        MdNode.horizontalRule,
      ]);
      final round = MdNode.fromJson(doc.toJson());
      expect(round.fingerprint, doc.fingerprint);
      expect(round.content, hasLength(7));
      expect(
        doc.plainText,
        'holaa'
        'b'
        'x'
        'y'
        'q'
        'void main() {}',
      );
    });

    test('MdNode: helpers y párrafos vacíos', () {
      expect(MdNode.paragraph().isEmptyParagraph, isTrue);
      expect(
        MdNode.paragraph([MdNode.textNode('  ')]).isEmptyParagraph,
        isTrue,
      );
      expect(
        MdNode.paragraph([MdNode.textNode('\u00A0')]).isEmptyParagraph,
        isTrue,
      );
      expect(
        MdNode.paragraph([MdNode.textNode('x')]).isEmptyParagraph,
        isFalse,
      );
      expect(MdNode.heading(1).type, MdNodeType.heading);
      expect(MdNode.bulletList().type, MdNodeType.bulletList);
      expect(MdNode.codeBlock(null, '').content, isEmpty);
      expect(MdNode.textNode('x').isText, isTrue);
    });
  });

  group('analizador · bloques', () {
    test('cita con línea vacía y con lista', () {
      final quote = MarkdownParser.parse('> uno\n>\n> dos');
      expect(quote.content.first.type, MdNodeType.blockquote);
      expect(quote.content.first.content, hasLength(2));

      final withList = MarkdownParser.parse('> - uno');
      expect(withList.content.first.content.first.type, MdNodeType.bulletList);
    });

    test('valla de código con lenguaje y sin cierre (no se cuelga)', () {
      final code = MarkdownParser.parse('```js\nx = 1\n```');
      expect(code.content.first.type, MdNodeType.codeBlock);
      expect(code.content.first.attrs['language'], 'js');

      final unterminated = MarkdownParser.parse('```\nabc');
      expect(unterminated.content.first.type, MdNodeType.paragraph);
    });

    test('separadores con asteriscos y guion bajo', () {
      expect(
        MarkdownParser.parse('***').content.first.type,
        MdNodeType.horizontalRule,
      );
      expect(
        MarkdownParser.parse('___').content.first.type,
        MdNodeType.horizontalRule,
      );
      expect(
        MarkdownParser.parse('---').content.first.type,
        MdNodeType.horizontalRule,
      );
    });

    test('lista con línea en blanco y lista anidada dentro del elemento', () {
      final doc = MarkdownParser.parse('- a\n\n  - b');
      final list = doc.content.first;
      expect(list.type, MdNodeType.bulletList);
      expect(list.content, hasLength(1));
      expect(list.content.first.content, hasLength(2));
      expect(list.content.first.content[1].type, MdNodeType.bulletList);
    });

    test('lista numerada con paréntesis y lista de tareas vacía', () {
      final ordered = MarkdownParser.parse('1) uno\n2) dos');
      expect(ordered.content.first.type, MdNodeType.orderedList);
      expect(ordered.content.first.content, hasLength(2));

      final tasks = MarkdownParser.parse('- [x] hecha\n- [ ] pendiente');
      expect(tasks.content.first.type, MdNodeType.taskList);
      expect(tasks.content.first.content.first.attrs['checked'], isTrue);
      expect(tasks.content.first.content[1].attrs['checked'], isFalse);
    });

    test('sangría con tabulador no rompe', () {
      final doc = MarkdownParser.parse('- a\n\tb');
      expect(doc.content.first.type, MdNodeType.bulletList);
      expect(doc.content.first.content.first.content, hasLength(2));
    });

    test('valla sin cerrar al final no se cuelga', () {
      expect(() => MarkdownParser.parse('```'), returnsNormally);
    });
  });

  group('analizador · en línea', () {
    test('autolinks http y mailto', () {
      expect(
        MarkdownSerializer.serialize(MarkdownParser.parse('<https://a.b>')),
        '[https://a.b](https://a.b)',
      );
      expect(
        MarkdownSerializer.serialize(MarkdownParser.parse('<mailto:a@b.c>')),
        '[mailto:a@b.c](mailto:a@b.c)',
      );
      // Un `<` que no es autolink queda literal.
      expect(
        MarkdownSerializer.serialize(MarkdownParser.parse('a < b')),
        'a &lt; b',
      );
    });

    test('entidades numéricas, hexadecimales y desconocidas', () {
      expect(MarkdownSerializer.serialize(MarkdownParser.parse('&#65;')), 'A');
      expect(MarkdownSerializer.serialize(MarkdownParser.parse('&#x41;')), 'A');
      expect(
        MarkdownSerializer.serialize(MarkdownParser.parse('&foo;')),
        '&amp;foo;',
      );
    });

    test('enlace con título, corchete suelto y comilla invertida suelta', () {
      final withTitle = MarkdownSerializer.serialize(
        MarkdownParser.parse('[x](http://a "t")'),
      );
      expect(withTitle, '[x](http://a "t")');
      expect(MarkdownSerializer.serialize(MarkdownParser.parse('[x')), '\\[x');
      expect(MarkdownSerializer.serialize(MarkdownParser.parse('`x')), '\\`x');
      expect(
        MarkdownSerializer.serialize(MarkdownParser.parse('[x](http://a')),
        '\\[x\\](http://a',
      );
    });

    test('salto duro con barra invertida y con dos espacios', () {
      final backslash = MarkdownParser.parse('a\\\nb');
      expect(backslash.content.first.content, hasLength(3));
      expect(backslash.content.first.content[1].type, MdNodeType.hardBreak);
    });

    test('tilde suelta y escapado de cada carácter especial', () {
      expect(
        MarkdownSerializer.serialize(MarkdownParser.parse('a~b')),
        'a\\~b',
      );
      for (final ch in ['*', '_', '`', '[', ']', '~', '\\']) {
        final source = 'a\\${ch}b';
        expect(MarkdownParser.parse(source).content.first.plainText, 'a${ch}b');
      }
    });

    test('marca de código con espacios alrededor', () {
      final nodes = MarkdownParser.parse('`` a `b` c ``').content.first.content;
      expect(nodes, hasLength(1));
      expect(nodes.first.marks.first.type, MdMarkType.code);
      expect(nodes.first.text, 'a `b` c');
    });
  });

  group('documento', () {
    test('isUnchanged y renderBlock público', () {
      final doc = MarkdownDocument.parse('hola');
      expect(doc.isUnchanged, isTrue);
      expect(
        MarkdownSerializer.renderBlock(
          MdNode.paragraph([MdNode.textNode('x')]),
        ),
        'x',
      );
      doc.blocks.first.node = MdNode.paragraph([MdNode.textNode('otra cosa')]);
      expect(doc.isUnchanged, isFalse);
      expect(doc.save(), 'otra cosa');
    });

    test('documento vacío', () {
      final doc = MarkdownDocument.parse('');
      expect(doc.blocks.every((b) => b.node.isEmptyParagraph), isTrue);
      expect(doc.save(), '');
    });
  });
}
