import 'package:flutter/material.dart';

import '../tokens.dart';

/// Variante del toast (color del punto, según el tablero «7 · Estados y errores — Toasts»).
enum AxoToastVariant { success, info, error }

/// Toast del diseño: 388 de ancho, radio 12, `bgEditor`, punto de color + mensaje 14/500 y una
/// acción opcional 14/600 en `accent`. Se presenta con [showAxoToast].
class AxoToast extends StatelessWidget {
  const AxoToast({
    super.key,
    required this.message,
    this.variant = AxoToastVariant.info,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AxoToastVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final dot = switch (variant) {
      AxoToastVariant.success => c.statusSuccess,
      AxoToastVariant.info => c.accentDefault,
      AxoToastVariant.error => c.statusDanger,
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 41),
      padding: const EdgeInsets.symmetric(
        horizontal: AxoSpacing.md,
        vertical: AxoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.bgEditor,
        borderRadius: BorderRadius.circular(AxoRadii.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AxoSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AxoType.bodyUi.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: AxoSpacing.md),
            Semantics(
              button: true,
              child: InkWell(
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: AxoType.bodyUi.copyWith(
                    color: c.accentDefault,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Presenta [AxoToast] como aviso flotante temporal.
void showAxoToast(
  BuildContext context, {
  required String message,
  AxoToastVariant variant = AxoToastVariant.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.all(AxoSpacing.md),
      content: AxoToast(
        message: message,
        variant: variant,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    ),
  );
}
