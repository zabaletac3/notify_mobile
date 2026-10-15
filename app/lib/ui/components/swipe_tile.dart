import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Acción de un lado del deslizamiento de una tarjeta.
///
/// El documento de Pencil de la fase 9 **no define gestos** y `notify_web` tampoco los tiene (la
/// tarjeta solo responde a `click`). Se decide aquí, siguiendo la convención de Android y el
/// vocabulario del propio diseño; ver `docs/decisions.md` (fase 9, «Gestos de la lista»).
class AxoSwipeAction {
  const AxoSwipeAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onInvoke,
    this.stays = false,
  });

  /// Texto que aparece bajo la tarjeta mientras se desliza.
  final String label;
  final String icon;

  /// Fondo del lado deslizado.
  final Color color;

  /// Color del icono y del texto sobre [color].
  final Color foreground;

  final Future<void> Function() onInvoke;

  /// `true` si la tarjeta sigue en la lista tras la acción (p. ej. fijar): el deslizamiento vuelve
  /// a su sitio en vez de desaparecer.
  final bool stays;
}

/// Envuelve una tarjeta con las acciones de deslizamiento: hacia la derecha ([startAction]) y hacia
/// la izquierda ([endAction]). Los lados sin acción no se pueden deslizar.
class AxoSwipeTile extends StatelessWidget {
  const AxoSwipeTile({
    super.key,
    required this.itemKey,
    required this.child,
    this.startAction,
    this.endAction,
  });

  final Key itemKey;
  final Widget child;
  final AxoSwipeAction? startAction;
  final AxoSwipeAction? endAction;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Dismissible(
      key: itemKey,
      direction: DismissDirection.horizontal,
      background: startAction == null
          ? null
          : _background(context, startAction!, left: true),
      secondaryBackground: endAction == null
          ? null
          : _background(context, endAction!, left: false),
      confirmDismiss: (direction) async {
        final action = direction == DismissDirection.startToEnd
            ? startAction
            : endAction;
        if (action == null) return false;
        await action.onInvoke();
        // Tras la acción, la tarjeta desaparece (la lista es reactiva) salvo que la acción la
        // mantenga (fijar/desfijar).
        return !action.stays;
      },
      // El `Dismissible` no debe quedarse con el hueco: la lista se reconstruye desde el flujo.
      onDismissed: (_) {},
      child: ColoredBox(color: c.bgApp, child: child),
    );
  }

  Widget _background(
    BuildContext context,
    AxoSwipeAction action, {
    required bool left,
  }) {
    final icon = AppIcon(action.icon, size: 20, color: action.foreground);
    final label = Text(
      action.label,
      style: AxoType.option.copyWith(color: action.foreground),
    );
    return Container(
      color: action.color,
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: left
            ? [icon, const SizedBox(width: 10), label]
            : [label, const SizedBox(width: 10), icon],
      ),
    );
  }
}
