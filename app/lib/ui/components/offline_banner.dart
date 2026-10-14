import 'package:flutter/material.dart';

import '../tokens.dart';

/// Aviso persistente de «sin conexión» (tablero «Android — Sin conexión»): 60 de alto, relleno
/// `bgHover`, relleno [12,16], hueco 10, punto 8 `tagAmber`, texto 13/500 `textPrimary` y acción
/// 13/600 `accent`.
class AxoOfflineBanner extends StatelessWidget {
  const AxoOfflineBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: c.bgHover,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c.tagAmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AxoType.label.copyWith(color: c.textPrimary),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 10),
            Semantics(
              button: true,
              child: InkWell(
                onTap: onRetry,
                child: Text(
                  'Reintentar',
                  style: AxoType.label.copyWith(
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
