import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Campo de texto del diseño: relleno (`bg/input`), sin borde, foco con borde azul de 2 px y error con
/// borde `status/danger`. Si es de contraseña, lleva un botón de ojo para mostrarla.
class AxoField extends StatefulWidget {
  const AxoField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.error,
    this.prefixIcon,
    this.onChanged,
    this.keyboardType,
    this.autofocus = false,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final String? error;
  final String? prefixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  State<AxoField> createState() => _AxoFieldState();
}

class _AxoFieldState extends State<AxoField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late bool _hidden = widget.obscure;
  bool _focused = false;

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final error = widget.error;
    final borderColor = error != null
        ? c.statusDanger
        : _focused
        ? c.accentDefault
        : Colors.transparent;
    final borderWidth = error != null || _focused ? 2.0 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AxoType.label.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AxoSpacing.xs),
        ],
        Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: Container(
            height: AxoSizes.input,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: c.bgInput,
              borderRadius: BorderRadius.circular(AxoRadii.lg),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Row(
              children: [
                if (widget.prefixIcon != null) ...[
                  AppIcon(widget.prefixIcon!, size: 18, color: c.textTertiary),
                  const SizedBox(width: AxoSpacing.sm),
                ],
                Expanded(
                  child: TextField(
                    controller: _controller,
                    obscureText: _hidden,
                    onChanged: widget.onChanged,
                    keyboardType: widget.keyboardType,
                    autofocus: widget.autofocus,
                    style: AxoType.bodyUi.copyWith(color: c.textPrimary),
                    cursorColor: c.accentDefault,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: AxoType.bodyUi.copyWith(color: c.textTertiary),
                    ),
                  ),
                ),
                if (widget.obscure)
                  GestureDetector(
                    onTap: () => setState(() => _hidden = !_hidden),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: AxoSizes.tapTarget,
                      height: AxoSizes.tapTarget,
                      child: Center(
                        child: AppIcon(
                          _hidden ? 'eye' : 'eye-off',
                          size: 18,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AxoSpacing.xs),
          Text(error, style: AxoType.caption.copyWith(color: c.statusDanger)),
        ],
      ],
    );
  }
}
