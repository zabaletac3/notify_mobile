import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

void main() {
  group('texto de notas', () {
    test('deriva una vista previa sin sintaxis Markdown', () {
      const md =
          '# Título\n\nLa **normalización** organiza [tablas](http://x).\n\n- [x] Hecho\n- [ ] Pendiente';
      expect(
        derivePreview(md),
        'Título La normalización organiza tablas. Hecho Pendiente',
      );
    });

    test('recorta la vista previa larga con elipsis', () {
      final p = derivePreview('palabra ' * 40, 30);
      expect(p.length, lessThanOrEqualTo(30));
      expect(p.endsWith('…'), isTrue);
    });

    test('cuenta palabras', () {
      expect(countWords(''), 0);
      expect(countWords('# Hola mundo\n\n- uno\n- dos'), 4);
    });

    test('normaliza etiquetas', () {
      expect(normalizeTag('#Proyecto Final'), 'proyecto-final');
      expect(normalizeTag('  Parcial!  '), 'parcial');
    });

    test('quita tildes y mayúsculas para buscar', () {
      expect(foldText('Normalización ÁÉÍ'), 'normalizacion aei');
      expect(foldText('Ünïcôde'), 'unicode');
    });
  });
}
