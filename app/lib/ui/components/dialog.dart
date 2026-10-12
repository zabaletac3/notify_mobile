import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Diálogo del diseño: radio 20, relleno 28 y hueco 16. Si se pasa [icon] (diálogos de estado,
/// como «sesión expirada»), aparece una ilustración circular de 56 arriba y el texto se centra.
class AxoDialog extends StatelessWidget {
  const AxoDialog({
    super.key,
    required this.title,
    this.content,
    this.actions = const [],
    this.icon,
  });

  final String title;
  final Widget? content;
  final List<Widget> actions;

  /// Icono de la ilustración circular superior (opcional).
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final centered = icon != null;
    return Container(
      constraints: const BoxConstraints(maxWidth: 348),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.bgEditor,
        borderRadius: BorderRadius.circular(AxoRadii.xxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.bgSelected,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(icon!, size: 26, color: c.accentDefault),
              ),
            ),
            const SizedBox(height: AxoSpacing.lg),
          ],
          Text(
            title,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AxoSpacing.lg),
          if (content != null) ...[
            content!,
            const SizedBox(height: AxoSpacing.lg),
          ],
          if (actions.isNotEmpty)
            Row(
              mainAxisAlignment: centered
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.end,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: AxoSpacing.md),
                  Flexible(child: actions[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
