import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Tarjeta de nota del diseño: 80 px de alto, radio 10, relleno 12/14, hueco 4. El icono de fijado va
/// antes del título, de 13 px y color `tag/amber`.
class AxoNoteCard extends StatelessWidget {
  const AxoNoteCard({
    super.key,
    required this.title,
    this.preview = '',
    this.date,
    this.pinned = false,
    this.onTap,
  });

  final String title;
  final String preview;
  final String? date;
  final bool pinned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Semantics(
      button: onTap != null,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: AxoSizes.noteCard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.bgEditor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  if (pinned) ...[
                    const AppIcon('pin', size: 13, color: Color(0xFF8A590C)),
                    const SizedBox(width: AxoSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AxoType.label.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (date != null)
                    Text(
                      date!,
                      style: AxoType.caption.copyWith(color: c.textTertiary),
                    ),
                ],
              ),
              const SizedBox(height: AxoSpacing.xs),
              Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AxoType.caption.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
