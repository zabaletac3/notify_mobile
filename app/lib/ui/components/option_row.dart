import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Contenedor de acciones de una hoja inferior (tablero «Android — Menú contextual de nota»):
/// relleno `bgApp`, radio 14 y borde `borderDefault`, con opciones de 48 separadas por divisores.
class AxoSheetActions extends StatelessWidget {
  const AxoSheetActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Container(height: 1, color: c.borderDefault));
      }
      rows.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: c.bgApp,
        borderRadius: BorderRadius.circular(AxoRadii.xl),
        border: Border.all(color: c.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

/// Opción de una hoja inferior (tablero «Android — Menú contextual de nota», «Opción»): 48 de alto,
/// relleno [14,16], hueco 12, icono 20 y etiqueta 15/500 `textPrimary` (destructiva `statusDanger`).
class AxoOptionRow extends StatelessWidget {
  const AxoOptionRow({
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
        child: Container(
          height: AxoSizes.optionRow,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (icon != null) ...[
                AppIcon(icon!, size: 20, color: fg),
                const SizedBox(width: AxoSpacing.md),
              ],
              Expanded(
                child: Text(label, style: AxoType.option.copyWith(color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
