import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'otp.dart';

/// Entrada de código OTP (6 casillas del diseño). Un único [TextField] invisible captura la
/// escritura y las casillas muestran el valor con la casilla activa resaltada.
class AxoOtpInput extends StatefulWidget {
  const AxoOtpInput({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.autofocus = false,
    this.enabled = true,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;
  final bool enabled;

  @override
  State<AxoOtpInput> createState() => _AxoOtpInputState();
}

class _AxoOtpInputState extends State<AxoOtpInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _value = '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final clean = value.replaceAll(RegExp(r'\D'), '');
    final capped = clean.length > widget.length
        ? clean.substring(0, widget.length)
        : clean;
    if (capped != value) {
      _controller.value = TextEditingValue(
        text: capped,
        selection: TextSelection.collapsed(offset: capped.length),
      );
    }
    setState(() => _value = capped);
    widget.onChanged?.call(capped);
    if (capped.length == widget.length) widget.onCompleted?.call(capped);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AxoOtpField(
            length: widget.length,
            value: _value,
            focusedIndex: _focus.hasFocus
                ? _value.length.clamp(0, widget.length - 1)
                : null,
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: widget.length,
                showCursor: false,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.transparent),
                onChanged: _onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Medidor de fuerza de contraseña del diseño: **una sola barra continua** (alto 4, radio 2),
/// pista `borderDefault` y progreso `accent`. [score] va de 0 a 4.
class AxoPasswordStrength extends StatelessWidget {
  const AxoPasswordStrength({super.key, required this.score});

  /// 0–4.
  final int score;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final fraction = (score / 4).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Container(color: c.borderDefault),
            FractionallySizedBox(
              widthFactor: fraction,
              alignment: Alignment.centerLeft,
              child: Container(color: c.accentDefault),
            ),
          ],
        ),
      ),
    );
  }
}
