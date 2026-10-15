import 'dart:convert';
import 'dart:io';

import 'package:axonote_markdown/axonote_markdown.dart';
import 'package:test/test.dart';

Map<String, Object?> _loadVectors() {
  final file = File('../../contract/vectors/markdown.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

void main() {
  final vectors = _loadVectors();
  final cases = (vectors['cases']! as List).cast<Map<String, Object?>>();
  final serialize = (vectors['serialize']! as List)
      .cast<Map<String, Object?>>();

  group('markdown.json · casos (analizar canonical y conservar)', () {
    for (final c in cases) {
      final name = c['name']! as String;
      final canonical = c['canonical']! as String;
      final supported = c['supported']! as bool;

      test('(a) conserva byte a byte: $name', () {
        final doc = MarkdownDocument.parse(canonical);
        expect(doc.save(), canonical, reason: 'conservación de $name');
      });

      if (supported) {
        test('(b) el serializador reproduce canonical: $name', () {
          final tree = MarkdownParser.parse(canonical);
          expect(
            MarkdownSerializer.serialize(tree),
            canonical,
            reason: 'serialización forzada de $name',
          );
        });
      }
    }
  });

  group('markdown.json · serialize (documento → Markdown)', () {
    for (final c in serialize) {
      final name = c['name']! as String;
      final doc = (c['doc']! as Map).cast<String, Object?>();
      final markdown = c['markdown']! as String;

      test('(b2) emite el markdown exacto: $name', () {
        expect(
          MarkdownSerializer.serialize(MdNode.fromJson(doc)),
          markdown,
          reason: 'serialización de $name',
        );
      });
    }
  });
}
