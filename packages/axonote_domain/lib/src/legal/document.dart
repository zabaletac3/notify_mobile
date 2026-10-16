/// Textos legales y datos del responsable (portado de `notify_web/src/lib/legal/`).
library;

/// Un bloque de contenido de un documento legal.
sealed class LegalBlock {
  const LegalBlock();
}

/// Párrafo de texto.
class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text);

  final String text;
}

/// Lista con viñetas.
class LegalList extends LegalBlock {
  const LegalList(this.items);

  final List<String> items;
}

/// Aviso destacado (p. ej. la advertencia de no recuperación).
class LegalCallout extends LegalBlock {
  const LegalCallout(this.text);

  final String text;
}

/// Una sección de un documento legal.
class LegalSection {
  const LegalSection({
    required this.id,
    required this.title,
    required this.blocks,
  });

  /// Ancla estable (`#id`).
  final String id;
  final String title;
  final List<LegalBlock> blocks;
}

/// Estado de publicación del texto.
enum LegalStatus {
  draft('borrador'),
  inForce('vigente');

  const LegalStatus(this.wire);

  final String wire;
}

/// Un documento legal completo.
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.version,
    required this.effectiveDate,
    required this.status,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String version;

  /// Fecha de entrada en vigor (ISO) o `null` mientras sea borrador.
  final String? effectiveDate;
  final LegalStatus status;
  final String intro;
  final List<LegalSection> sections;
}

/// Datos del responsable del tratamiento. Fuente única para los textos legales y el soporte.
class LegalResponsible {
  const LegalResponsible({
    required this.name,
    required this.nit,
    required this.city,
    required this.country,
    required this.address,
    required this.email,
  });

  final String name;
  final String nit;
  final String city;
  final String country;
  final String address;
  final String email;
}

/// Los valores con `[[REVISAR]]` los confirma quien revisa los textos antes de publicarlos.
const LegalResponsible responsible = LegalResponsible(
  name: 'AXONOTE S.A.S.',
  nit: '900900901-2',
  city: 'Barranquilla',
  country: 'Colombia',
  address: '[[REVISAR: dirección]]',
  email: 'axonote@gmail.com',
);

/// Mientras sea `true`, las páginas muestran «Borrador pendiente de revisión legal».
const bool legalDraft = true;
