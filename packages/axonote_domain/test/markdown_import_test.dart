import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

/// Casos portados de `notify_web/src/lib/domain/markdown-import.spec.ts`.
void main() {
  group('parseMarkdownNote', () {
    test('toma el título de la primera línea «# …» y lo quita del texto', () {
      final note = parseMarkdownNote('x.md', '# Receta\n\nHuevos\n- sal\n');
      expect(note.title, 'Receta');
      expect(note.content, 'Huevos\n- sal');
    });

    test('lee lo que escribe la exportación de AxoNote', () {
      const exported = '# Reunión del lunes\n\nTemas:\n\n- Presupuesto\n';
      final note = parseMarkdownNote('Reunión del lunes.md', exported);
      expect(note.title, 'Reunión del lunes');
      expect(note.content, 'Temas:\n\n- Presupuesto');
    });

    test('sin título usa el nombre del archivo y conserva todo el texto', () {
      final note = parseMarkdownNote(
        'Ideas sueltas.md',
        'Primera idea\n\nSegunda',
      );
      expect(note.title, 'Ideas sueltas');
      expect(note.content, 'Primera idea\n\nSegunda');
      expect(parseMarkdownNote('notas.MARKDOWN', 'a').title, 'notas');
      expect(parseMarkdownNote('lista.txt', 'a').title, 'lista');
    });

    test('un «## subtítulo» al principio no es el título', () {
      final note = parseMarkdownNote('guía.md', '## Paso 1\n\nHacer algo');
      expect(note.title, 'guía');
      expect(note.content, '## Paso 1\n\nHacer algo');
    });

    test('ignora líneas en blanco iniciales, el BOM y CRLF', () {
      final note = parseMarkdownNote(
        'x.md',
        '\uFEFF\r\n\r\n# Título\r\n\r\nTexto\r\nmás\r\n',
      );
      expect(note.title, 'Título');
      expect(note.content, 'Texto\nmás');
    });

    test('quita los # de cierre y recorta títulos larguísimos', () {
      expect(
        parseMarkdownNote('x.md', '# Con cierre ##\ntexto').title,
        'Con cierre',
      );
      final long = 'a' * (importTitleMaxLength + 50);
      expect(
        parseMarkdownNote('x.md', '# $long\n').title.length,
        importTitleMaxLength,
      );
    });

    test('un archivo vacío da el nombre del archivo y sin texto', () {
      final empty = parseMarkdownNote('vacío.md', '');
      expect(empty.title, 'vacío');
      expect(empty.content, '');
      final noName = parseMarkdownNote('.md', '   \n');
      expect(noName.title, 'Sin título');
      expect(noName.content, '');
    });

    test('solo un título deja el texto vacío', () {
      final note = parseMarkdownNote('x.md', '# Solo título');
      expect(note.title, 'Solo título');
      expect(note.content, '');
    });
  });

  test('exportNoteMarkdown usa el formato de la web', () {
    expect(
      exportNoteMarkdown('Reunión', 'Temas:\n\n- uno'),
      '# Reunión\n\nTemas:\n\n- uno\n',
    );
  });
}
