import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Elemento de menú del diseño: 48 px de alto, relleno 16, hueco 12, icono 20. Puede ser destructivo.
class AxoMenuItem extends StatelessWidget {
  const AxoMenuItem({
    super.key,
    required this.label,
    this.icon,
    this.destructive = false,
    this.onTap,
  });

  final String label;
  final String? icon;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final fg = destructive ? c.statusDanger : c.textPrimary;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AxoRadii.sm),
        child: Container(
          height: AxoSizes.menuItem,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (icon != null) ...[
                AppIcon(icon!, size: 20, color: fg),
                const SizedBox(width: AxoSpacing.md),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AxoType.body.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
