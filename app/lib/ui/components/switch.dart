import 'package:flutter/material.dart';

import '../tokens.dart';

/// Interruptor del diseño: 44×26 con 3 px de margen; apagado en `text/tertiary`, encendido en `accent`.
class AxoSwitch extends StatelessWidget {
  const AxoSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: AxoSizes.switchWidth,
          height: AxoSizes.tapTarget,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: AxoSizes.switchWidth,
              height: AxoSizes.switchHeight,
              decoration: BoxDecoration(
                color: value ? c.accentDefault : c.textTertiary,
                borderRadius: BorderRadius.circular(AxoSizes.switchHeight / 2),
              ),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
