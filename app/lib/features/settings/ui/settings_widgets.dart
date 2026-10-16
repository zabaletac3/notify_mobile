import 'package:flutter/material.dart';

import '../../../router/navigation.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';

/// Armazón de una pantalla de Ajustes (tableros «Android — Ajustes…»): barra superior con flecha
/// «atrás» (que sale a la pantalla anterior o, si no hay pila, a la lista) y cuerpo desplazable con
/// relleno 16/12 y grupos separados 20 px. Fondo `bgEditor`.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return PopScope(
      canPop: canGoBack(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack(context);
      },
      child: Scaffold(
        backgroundColor: c.bgEditor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AxoTopBar(title: title, onBack: () => goBack(context)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: AxoSpacing.xl),
                      children[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior para elegir una opción de una fila de ajustes (el valor y el chevron del tablero).
Future<void> showSettingsChoice(
  BuildContext context, {
  required String title,
  required String value,
  required List<(String, String)> options,
  required ValueChanged<String> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final c = Theme.of(sheetContext).extension<AxoColors>()!;
      return AxoBottomSheet(
        children: [
          Text(
            title,
            style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AxoSpacing.lg),
          AxoSheetActions(
            children: [
              for (final (optionValue, label) in options)
                AxoOptionRow(
                  label: label,
                  icon: optionValue == value ? 'check' : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onSelected(optionValue);
                  },
                ),
            ],
          ),
        ],
      );
    },
  );
}
