import 'package:flutter/material.dart';

import '../tokens.dart';

/// Radio del diseño (tableros «Android — Modal mover nota» y «Conflicto de sincronización»):
/// 20×20, radio 10, borde 2 (`borderDefault`; `accent` cuando está seleccionado) y punto interior
/// de 10 en `accent`.
class AxoRadio extends StatelessWidget {
  const AxoRadio({super.key, required this.selected, this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? c.accentDefault : c.borderDefault,
              width: 2,
            ),
          ),
          child: selected
              ? Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.accentDefault,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
