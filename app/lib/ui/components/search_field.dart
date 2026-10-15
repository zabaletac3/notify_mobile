import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Buscador de la lista (tablero «Android — Lista de notas», «Search bar»): 48 de alto, radio 28,
/// relleno [14,18], hueco 12, relleno `bgInput`. Icono `search` 20 `textSecondary`, texto 16/400
/// (`textPrimary`; placeholder `textTertiary`) y botón `close` 20 a la derecha cuando hay texto.
class AxoSearchField extends StatelessWidget {
  const AxoSearchField({
    super.key,
    required this.controller,
    this.hint = 'Buscar notas',
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      height: AxoSizes.searchBar,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: c.bgInput,
        borderRadius: BorderRadius.circular(AxoRadii.card),
      ),
      child: Row(
        children: [
          AppIcon('search', size: 20, color: c.textSecondary),
          const SizedBox(width: AxoSpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: AxoType.search.copyWith(color: c.textPrimary),
              cursorColor: c.accentDefault,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AxoType.search.copyWith(color: c.textTertiary),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onClear?.call();
              },
              behavior: HitTestBehavior.opaque,
              child: AppIcon('x', size: 20, color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}
