import 'package:flutter/material.dart';

import '../tokens.dart';

/// Cabecera de grupo de la lista (tablero «Android — Lista de notas», «Group»): 38 de alto,
/// relleno [16,0,6,14] y etiqueta 13/600 `textSecondary`.
class AxoNoteGroupHeader extends StatelessWidget {
  const AxoNoteGroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      height: AxoSizes.groupHeader,
      padding: const EdgeInsets.fromLTRB(14, 16, 0, 6),
      alignment: Alignment.topLeft,
      child: Text(
        label,
        style: AxoType.groupHeader.copyWith(color: c.textSecondary),
      ),
    );
  }
}
