import 'dart:convert';
import 'dart:io';

import 'package:axonote_markdown/axonote_markdown.dart';
import 'package:test/test.dart';

List<Map<String, Object?>> _cases() {
  final file = File('../../contract/vectors/markdown.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return (json['cases']! as List).cast<Map<String, Object?>>();
}

/// Devuelve una copia del árbol con el primer texto en orden de documento alargado con `X`.
/// Mantiene la forma (no cambia el número de bloques), así que sirve para editar «un bloque».
MdNode? _editFirstText(MdNode node) {
  if (node.type == MdNodeType.text) {
    return MdNode.textNode('${node.text ?? ''}X', node.marks);
  }
  final edited = <MdNode>[];
  var changed = false;
  for (final child in node.content) {
    if (!changed) {
      final childEdited = _editFirstText(child);
      if (childEdited != null) {
        edited.add(childEdited);
        changed = true;
        continue;
      }
    }
    edited.add(child);
  }
  if (!changed) return null;
  return MdNode(
    node.type,
    attrs: node.attrs,
    content: edited,
    text: node.text,
    marks: node.marks,
  );
}

void main() {
  group('conservación por bloque (c): editar el bloque i no toca los demás', () {
    for (final c in _cases()) {
      if (c['supported'] != true) continue;
      final name = c['name']! as String;
      final canonical = c['canonical']! as String;

      test(name, () {
        final original = MarkdownDocument.parse(canonical);
        final sources = original.blocks
            .map((b) => b.source)
            .toList(growable: false);

        for (var i = 0; i < original.blocks.length; i++) {
          final doc = MarkdownDocument.parse(canonical);
          final edited = _editFirstText(doc.blocks[i].node);
          if (edited == null) continue; // bloque sin texto (separador, vacío…)
          doc.blocks[i].node = edited;

          final saved = doc.save();
          final reparsed = MarkdownDocument.parse(saved);

          expect(
            reparsed.blocks.length,
            doc.blocks.length,
            reason:
                '$name · editar el bloque $i no debe cambiar el número de bloques',
          );
          for (var j = 0; j < reparsed.blocks.length; j++) {
            if (j == i) continue;
            expect(
              reparsed.blocks[j].source,
              sources[j],
              reason:
                  '$name · editar el bloque $i alteró los bytes del bloque $j',
            );
          }
        }
      });
    }
  });

  group('conservación · reconstrucción de líneas en blanco', () {
    test('un párrafo vacío entre dos se conserva y se edita aparte', () {
      const original = 'a\n\n\n\nb';
      final doc = MarkdownDocument.parse(original);
      expect(doc.save(), original);
      expect(doc.blocks, hasLength(3));
      expect(doc.blocks[1].node.isEmptyParagraph, isTrue);

      // Editar el segundo párrafo deja intacto el resto (incluido el vacío).
      final edited = doc.blocks[2].node;
      doc.blocks[2].node = MdNode.paragraph([MdNode.textNode('c')]);
      final saved = doc.save();
      expect(saved.startsWith('a\n\n\n\n'), isTrue);
      expect(saved.endsWith('c'), isTrue);
      expect(edited.type, MdNodeType.paragraph);
    });

    test('dos párrafos vacíos seguidos vuelven con &nbsp;', () {
      const original = 'a\n\n\n\n&nbsp;\n\nb';
      final doc = MarkdownDocument.parse(original);
      expect(doc.save(), original);
      // Cuatro bloques: a, vacío, el del &nbsp; (vacío) y b.
      expect(doc.blocks, hasLength(4));
      expect(doc.blocks[1].node.isEmptyParagraph, isTrue);
      expect(doc.blocks[2].node.isEmptyParagraph, isTrue);
    });
  });
}
