import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Chip de carpeta de la lista (tablero «Android — Lista de notas», «Chip»): 33 de alto, radio 10,
/// relleno [8,14], hueco 6 y borde `borderDefault`. Activo: relleno `bgSelected`, icono
/// `folder` 15 `accent` y etiqueta 14/600 `accent`.
class AxoFolderChip extends StatelessWidget {
  const AxoFolderChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool selected;

  /// Icono Lucide a la izquierda (normalmente `folder`; «Todas» va sin icono).
  final String? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final fg = selected ? c.accentDefault : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? c.bgSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(AxoRadii.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AxoRadii.chip),
          child: Container(
            height: AxoSizes.chip,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AxoRadii.chip),
              border: selected ? null : Border.all(color: c.borderDefault),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  AppIcon(icon!, size: 15, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: (selected ? AxoType.chipActive : AxoType.chip)
                      .copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
