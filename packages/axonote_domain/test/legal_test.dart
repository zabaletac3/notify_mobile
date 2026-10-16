import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

/// Casos portados de `notify_web/src/lib/legal/legal.spec.ts` y `changelog.spec.ts`.
void main() {
  test('los documentos legales son borradores con secciones e intro', () {
    for (final doc in [terms, privacy]) {
      expect(doc.status, legalDraft ? LegalStatus.draft : LegalStatus.inForce);
      expect(doc.intro, isNotEmpty);
      expect(doc.sections, isNotEmpty);
      for (final section in doc.sections) {
        expect(section.id, isNotEmpty);
        expect(section.title, isNotEmpty);
        expect(section.blocks, isNotEmpty);
      }
    }
  });

  test('los términos recogen el responsable y la no recuperación', () {
    expect(terms.title, 'Términos de uso');
    final noRecovery = terms.sections.firstWhere(
      (s) => s.id == 'no-recuperacion',
    );
    expect(noRecovery.blocks.whereType<LegalCallout>(), isNotEmpty);
    expect(terms.intro, contains(responsible.name));
  });

  test('la política incluye el responsable con sus datos', () {
    final block = privacy.sections
        .firstWhere((s) => s.id == 'responsable')
        .blocks
        .whereType<LegalList>()
        .single;
    expect(block.items, contains('NIT: ${responsible.nit}'));
  });

  test(
    'el historial de cambios usa la versión del paquete en la primera entrada',
    () {
      expect(changelog, isNotEmpty);
      expect(changelog.first.version, isNull);
      expect(changelog.first.changes, isNotEmpty);
    },
  );
}
