import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Barra superior de una pantalla con botón «atrás» (tableros «Android — Ajustes…»): 48 de alto,
/// relleno [4,8], botón de 40×40 (radio 20) con la flecha de 24 y título 22/700. [actions] va a la
/// derecha.
class AxoTopBar extends StatelessWidget {
  const AxoTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return SizedBox(
      height: 48,
      child: Padding(
        // Sin relleno vertical: el botón mide 48 (área táctil de la §12.3) y el icono queda igual
        // de centrado que antes (relleno 4 + 40).
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _BackButton(onTap: onBack),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AxoType.heading.copyWith(color: c.textPrimary),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Tooltip(
      message: 'Atrás',
      child: Semantics(
        button: true,
        label: 'Atrás',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              // 40×48 de área táctil (plan §12.3): la altura llega a 48 sin mover el icono; el
              // ancho se mantiene en 40 (medida del diseño).
              width: 40,
              height: 48,
              child: Center(
                child: AppIcon('arrow-left', size: 24, color: c.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
