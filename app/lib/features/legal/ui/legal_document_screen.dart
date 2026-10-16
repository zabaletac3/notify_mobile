import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';

import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../settings/ui/settings_widgets.dart';

/// Pantalla de un documento legal (`/terms`, `/privacy`). Muestra el aviso de borrador, la versión,
/// la introducción y las secciones. Sin tablero en «Movil v2»: se sigue el responsive de la web.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return SettingsScaffold(
      title: document.title,
      children: [
        if (document.status == LegalStatus.draft)
          const AxoBanner(
            variant: AxoBannerVariant.info,
            message: 'Borrador pendiente de revisión legal',
          ),
        Text(
          _versionLine(document),
          style: AxoType.settingsRowDescription.copyWith(color: c.textTertiary),
        ),
        Text(
          document.intro,
          style: AxoType.body.copyWith(color: c.textPrimary),
        ),
        for (final section in document.sections) _SectionView(section: section),
      ],
    );
  }

  String _versionLine(LegalDocument document) {
    final status = document.status == LegalStatus.draft
        ? 'borrador'
        : 'vigente';
    final effective = document.effectiveDate;
    final date = effective == null ? '' : ' · en vigor desde $effective';
    return 'Versión ${document.version} · $status$date';
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: AxoType.heading.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AxoSpacing.sm),
        for (final block in section.blocks) ...[
          _BlockView(block: block),
          const SizedBox(height: AxoSpacing.md),
        ],
      ],
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return switch (block) {
      LegalParagraph(:final text) => Text(
        text,
        style: AxoType.body.copyWith(color: c.textPrimary),
      ),
      LegalCallout(:final text) => AxoBanner(
        variant: AxoBannerVariant.note,
        message: text,
      ),
      LegalList(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: AxoSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: AxoType.body.copyWith(color: c.textSecondary),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: AxoType.body.copyWith(color: c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    };
  }
}
