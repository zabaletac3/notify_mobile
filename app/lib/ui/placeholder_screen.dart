import 'package:flutter/material.dart';

import 'tokens.dart';

/// Pantalla vacía del esqueleto (fase 2): solo el título y un marcador. Cada pantalla real la sustituye
/// en su fase.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: AxoType.heading.copyWith(color: c.textPrimary)),
        backgroundColor: c.bgApp,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AxoType.title.copyWith(color: c.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: AxoSpacing.sm),
            Text('(pantalla vacía)', style: AxoType.body.copyWith(color: c.textTertiary)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AxoSpacing.xl),
              ...actions,
            ],
          ],
        ),
      ),
    );
  }
}
