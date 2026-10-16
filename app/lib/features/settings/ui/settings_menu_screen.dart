import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components.dart';
import 'settings_widgets.dart';

/// Menú de secciones de Ajustes (`/settings/menu`, tablero móvil sin tablero propio: se sigue el
/// responsive móvil de `notify_web`, que lista las secciones). Cada fila navega con `push` a su
/// pantalla.
class SettingsMenuScreen extends ConsumerWidget {
  const SettingsMenuScreen({super.key});

  /// Secciones (mismo orden y etiquetas que `notify_web/.../settings/sections.ts`).
  static const List<(String, String)> sections = [
    ('/settings/general', 'Generales'),
    ('/settings/account', 'Mi cuenta'),
    ('/settings/sync', 'Sincronización'),
    ('/settings/privacy', 'Privacidad y seguridad'),
    ('/settings/two-factor', 'Verificación en dos pasos'),
    ('/settings/storage', 'Almacenamiento'),
    ('/settings/delete-account', 'Eliminar cuenta'),
    ('/settings/about', 'Acerca de'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsScaffold(
      title: 'Ajustes',
      children: [
        AxoSettingsGroup(
          children: [
            for (final (href, label) in sections)
              AxoSettingRow(
                label: label,
                chevron: true,
                onTap: () => context.push(href),
              ),
          ],
        ),
      ],
    );
  }
}
