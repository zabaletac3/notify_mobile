import 'package:flutter/material.dart';

import '../tokens.dart';

/// Hoja inferior del diseño: radio superior 24, relleno 12/20/36/20 y hueco 16.
class AxoBottomSheet extends StatelessWidget {
  const AxoBottomSheet({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: c.bgApp,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AxoRadii.sheet)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: c.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AxoSpacing.lg),
          if (title != null) ...[
            Text(title!, style: AxoType.heading.copyWith(color: c.textPrimary)),
            const SizedBox(height: AxoSpacing.lg),
          ],
          ...children,
        ],
      ),
    );
  }
}
