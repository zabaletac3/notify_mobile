import 'package:flutter/material.dart';

import '../tokens.dart';

/// Diálogo del diseño: radio 20, relleno 28 y hueco 16. El presentador (`showDialog`) se añadirá con
/// las pantallas; esto es la superficie base.
class AxoDialog extends StatelessWidget {
  const AxoDialog({
    super.key,
    required this.title,
    this.content,
    this.actions = const [],
  });

  final String title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      constraints: const BoxConstraints(maxWidth: 348),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.bgEditor,
        borderRadius: BorderRadius.circular(AxoRadii.xxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AxoType.heading.copyWith(color: c.textPrimary)),
          const SizedBox(height: AxoSpacing.lg),
          if (content != null) ...[
            content!,
            const SizedBox(height: AxoSpacing.lg),
          ],
          if (actions.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
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
