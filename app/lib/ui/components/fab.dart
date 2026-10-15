import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// FAB «Nueva nota» (tablero «Android — Lista de notas», «FAB · Nueva nota»): 54 de alto, radio 18,
/// relleno `accent`, relleno [16,22,16,18], hueco 10, icono `compose` 22 y etiqueta 15/600 blanca.
class AxoFab extends StatelessWidget {
  const AxoFab({
    super.key,
    required this.label,
    this.icon = 'pencil',
    this.onPressed,
  });

  final String label;
  final String icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: c.accentDefault,
        borderRadius: BorderRadius.circular(AxoRadii.fab),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AxoRadii.fab),
          child: Container(
            height: AxoSizes.buttonLg,
            padding: const EdgeInsets.fromLTRB(16, 0, 18, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(icon, size: 22, color: c.accentOn),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: AxoType.buttonSm.copyWith(color: c.accentOn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
