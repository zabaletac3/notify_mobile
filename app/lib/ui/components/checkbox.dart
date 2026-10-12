import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Casilla circular del diseño (20 px). Marcada en `accent` con el check blanco.
class AxoCheckbox extends StatelessWidget {
  const AxoCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.labelRich,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  /// Etiqueta enriquecida (con enlaces en color de acento); si se pasa, sustituye a [label].
  final Widget? labelRich;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final box = Container(
      width: AxoSizes.checkbox,
      height: AxoSizes.checkbox,
      decoration: BoxDecoration(
        color: value ? c.accentDefault : Colors.transparent,
        shape: BoxShape.circle,
        border: value ? null : Border.all(color: c.textTertiary, width: 2),
      ),
      child: value
          ? Center(child: AppIcon('check', size: 14, color: c.accentOn))
          : null,
    );

    if (label == null && labelRich == null) {
      return Semantics(
        checked: value,
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: AxoSizes.tapTarget,
            height: AxoSizes.tapTarget,
            child: Center(child: box),
          ),
        ),
      );
    }

    return Semantics(
      checked: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            box,
            const SizedBox(width: AxoSpacing.md),
            Flexible(
              child:
                  labelRich ??
                  Text(
                    label!,
                    style: AxoType.bodyLabel.copyWith(color: c.textPrimary),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
