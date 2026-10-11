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

/// Barra de fuerza de contraseña (4 segmentos del diseño). Los segmentos activos van en `accent`
/// (como en Penpot); el texto de ayuda lo pone la pantalla.
class AxoPasswordStrength extends StatelessWidget {
  const AxoPasswordStrength({super.key, required this.score});

  /// 0–4.
  final int score;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: AxoSpacing.xs),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < score ? c.accentDefault : c.bgInput,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
