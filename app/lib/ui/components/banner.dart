import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Variantes del aviso.
enum AxoBannerVariant {
  info,
  danger,
  success,

  /// Aviso informativo de la lista/papelera: relleno `bgSelected` y texto `textPrimary`, sin icono
  /// (tablero «Android — Papelera», «Aviso»).
  note,
}

/// Aviso (banner/toast) del diseño: icono + mensaje, radio 12.
class AxoBanner extends StatelessWidget {
  const AxoBanner({
    super.key,
    required this.message,
    this.variant = AxoBannerVariant.info,
  });

  final String message;
  final AxoBannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    if (variant == AxoBannerVariant.note) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: AxoSpacing.md,
        ),
        decoration: BoxDecoration(
          color: c.bgSelected,
          borderRadius: BorderRadius.circular(AxoRadii.lg),
        ),
        child: Text(
          message,
          style: AxoType.label.copyWith(
            color: c.textPrimary,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }
    final (bg, fg, icon) = switch (variant) {
      AxoBannerVariant.info => (c.bgInput, c.textSecondary, 'info'),
      AxoBannerVariant.danger => (
        c.statusDangerBg,
        c.statusDanger,
        'circle-alert',
      ),
      AxoBannerVariant.success => (c.bgInput, c.statusSuccess, 'circle-check'),
      AxoBannerVariant.note => (c.bgSelected, c.textPrimary, 'info'),
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
          Expanded(
            child: Text(message, style: AxoType.bodyUi.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}
