import 'package:flutter/material.dart';

import '../tokens.dart';

/// Campo OTP del diseño: casillas separadas y rellenas (48×60, radio 12), foco azul. Muestra el valor
/// recibido; el manejo del teclado se añadirá con la pantalla de verificación (fase 8).
class AxoOtpField extends StatelessWidget {
  const AxoOtpField({super.key, this.length = 6, this.value = '', this.focusedIndex});

  final int length;
  final String value;
  final int? focusedIndex;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final focus = focusedIndex ?? value.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < length; i++) ...[
          if (i > 0) const SizedBox(width: AxoSpacing.sm),
          Container(
            width: AxoSizes.otpWidth,
            height: AxoSizes.otpHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bgInput,
              borderRadius: BorderRadius.circular(AxoRadii.lg),
              border: i == focus ? Border.all(color: c.accentDefault, width: 2) : null,
            ),
            child: Text(
              i < value.length ? value[i] : '',
              style: AxoType.heading.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ],
    );
  }
}
