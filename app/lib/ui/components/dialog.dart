import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Diálogo del diseño (tableros «Android — Confirmar eliminación» y «Android — Sesión expirada»):
/// 348 de ancho, radio 20, relleno 24, hueco 16, relleno `bgEditor` y borde `borderDefault`.
///
/// Si se pasa [icon] (diálogos de estado), aparece una ilustración circular arriba y el texto se
/// centra. Su tamaño y color dependen de [danger]: 56 en `statusDangerBg` con icono `statusDanger`
/// (peligro) o 64 en `bgSelected` con icono `accent`.
class AxoDialog extends StatelessWidget {
  const AxoDialog({
    super.key,
    required this.title,
    this.content,
    this.actions = const [],
    this.icon,
    this.danger = false,
  });

  final String title;
  final Widget? content;
  final List<Widget> actions;

  /// Icono de la ilustración circular superior (opcional).
  final String? icon;

  /// Ilustración de peligro (`statusDangerBg` + icono `statusDanger`, 56) en vez de la neutra
  /// (`bgSelected` + icono `accent`, 64).
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final centered = icon != null;
    final illustration = danger ? 56.0 : 64.0;
    return Container(
      constraints: const BoxConstraints(maxWidth: 348),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.bgEditor,
        borderRadius: BorderRadius.circular(AxoRadii.xxl),
        border: Border.all(color: c.borderDefault),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Container(
              width: illustration,
              height: illustration,
              decoration: BoxDecoration(
                color: danger ? c.statusDangerBg : c.bgSelected,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  icon!,
                  size: illustration * 0.46,
                  color: danger ? c.statusDanger : c.accentDefault,
                ),
              ),
            ),
            const SizedBox(height: AxoSpacing.lg),
          ],
          Text(
            title,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
          ),
          if (content != null) ...[
            const SizedBox(height: AxoSpacing.lg),
            content!,
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AxoSpacing.lg),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: AxoSpacing.md),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
