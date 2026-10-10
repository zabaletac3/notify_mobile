import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Variantes del aviso.
enum AxoBannerVariant { info, danger, success }

/// Aviso (banner/toast) del diseño: icono + mensaje, radio 12.
class AxoBanner extends StatelessWidget {
  const AxoBanner({super.key, required this.message, this.variant = AxoBannerVariant.info});

  final String message;
  final AxoBannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final (bg, fg, icon) = switch (variant) {
      AxoBannerVariant.info => (c.bgInput, c.textSecondary, 'info'),
      AxoBannerVariant.danger => (c.statusDangerBg, c.statusDanger, 'circle-alert'),
      AxoBannerVariant.success => (c.bgInput, c.statusSuccess, 'circle-check'),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AxoRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 18, color: fg),
          const SizedBox(width: AxoSpacing.sm),
          Expanded(child: Text(message, style: AxoType.body.copyWith(color: fg))),
        ],
      ),
    );
  }
}
