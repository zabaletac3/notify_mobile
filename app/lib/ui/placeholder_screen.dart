import 'package:flutter/material.dart';

import '../router/navigation.dart';
import 'app_icon.dart';
import 'tokens.dart';

/// Pantalla vacía del esqueleto (fase 2): solo el título y un marcador. Cada pantalla real la sustituye
/// en su fase. Lleva una flecha «atrás» que siempre sale (a la lista si no hay pila).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return PopScope(
      canPop: canGoBack(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Atrás',
            onPressed: () => goBack(context),
            icon: AppIcon('arrow-left', size: 24, color: c.textPrimary),
          ),
          title: Text(
            title,
            style: AxoType.heading.copyWith(color: c.textPrimary),
          ),
          backgroundColor: c.bgApp,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AxoType.screenTitle.copyWith(color: c.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AxoSpacing.sm),
              Text(
                '(pantalla vacía)',
                style: AxoType.body.copyWith(color: c.textTertiary),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AxoSpacing.xl),
                ...actions,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
