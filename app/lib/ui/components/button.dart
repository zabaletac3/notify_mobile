import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Variantes del botón del diseño.
enum AxoButtonVariant { primary, outline, destructive, destructiveSoft }

/// Tamaños del botón (altura / relleno / radio del diseño).
enum AxoButtonSize { sm, md, lg }

/// Botón base. Primario azul; `outline` (borde, sin relleno) es el secundario; `destructive` sólido y
/// `destructiveSoft` tintado.
class AxoButton extends StatelessWidget {
  const AxoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AxoButtonVariant.primary,
    this.size = AxoButtonSize.md,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AxoButtonVariant variant;
  final AxoButtonSize size;
  final String? icon;
  final bool expand;

  double get _height => switch (size) {
    AxoButtonSize.sm => AxoSizes.buttonSm,
    AxoButtonSize.md => AxoSizes.button,
    AxoButtonSize.lg => AxoSizes.buttonLg,
  };

  double get _pad => switch (size) {
    AxoButtonSize.sm => 14,
    AxoButtonSize.md => 20,
    AxoButtonSize.lg => 24,
  };

  double get _radius => size == AxoButtonSize.lg ? AxoRadii.xl : AxoRadii.lg;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final (bg, fg, border) = switch (variant) {
      AxoButtonVariant.primary => (c.accentDefault, c.accentOn, null),
      AxoButtonVariant.outline => (null, c.textPrimary, c.borderDefault),
      AxoButtonVariant.destructive => (c.statusDanger, c.accentOn, null),
      AxoButtonVariant.destructiveSoft => (c.statusDangerBg, c.statusDanger, null),
    };

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Material(
          color: bg ?? Colors.transparent,
          borderRadius: BorderRadius.circular(_radius),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(_radius),
            child: Container(
              height: _height,
              width: expand ? double.infinity : null,
              padding: EdgeInsets.symmetric(horizontal: _pad),
              decoration: border == null
                  ? null
                  : BoxDecoration(
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(_radius),
                    ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    AppIcon(icon!, size: 18, color: fg),
                    const SizedBox(width: AxoSpacing.sm),
                  ],
                  Text(label, style: AxoType.body.copyWith(color: fg, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
