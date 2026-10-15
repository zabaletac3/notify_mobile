import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import 'auth_widgets.dart';

/// Pantalla de arranque: se muestra mientras se lee el almacén seguro para decidir la sesión, sin
/// parpadear la introducción ni el desbloqueo (plan §5.3). No decide nada por sí sola.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Scaffold(
      backgroundColor: c.bgEditor,
      body: const Center(child: AuthLogo(size: 96, letter: 'A')),
    );
  }
}
