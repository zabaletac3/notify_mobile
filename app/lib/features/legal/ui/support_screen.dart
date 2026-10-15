import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../settings/state/app_info.dart';
import '../../settings/ui/settings_widgets.dart';

/// «Contacto y soporte» (`/support`), portado de `notify_web/src/routes/(legal)/support`.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final version = ref.watch(appInfoProvider).value?.version ?? '';
    return SettingsScaffold(
      title: 'Contacto y soporte',
      children: [
        Text(
          '¿Tienes un problema con AxoNote o una duda? Escríbenos a ${responsible.email} y te '
          'responderemos.',
          style: AxoType.body.copyWith(color: c.textPrimary),
        ),
        const AxoBanner(
          variant: AxoBannerVariant.info,
          message:
              'Nunca te pediremos tu contraseña ni tu clave de recuperación. Si alguien te los pide '
              'en nombre de AxoNote, no se los des.',
        ),
        _Section(
          title: 'Qué incluir en tu mensaje',
          child: _Bullets([
            'El correo de tu cuenta.',
            'La plataforma en la que usas AxoNote (web, escritorio, iOS o Android).',
            'La versión de la app (versión $version) y, si puedes, una descripción del problema.',
          ]),
        ),
        _Section(
          title: 'Solicitudes sobre tus datos personales',
          child: Text(
            'Las consultas y reclamos sobre tus datos personales (conocer, actualizar, rectificar o '
            'suprimir) también se envían a ${responsible.email}. Los plazos y el procedimiento están '
            'en la Política de privacidad (ver abajo).',
            style: AxoType.body.copyWith(color: c.textPrimary),
          ),
        ),
        _Section(
          title: 'Más información',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Link(
                label: 'Términos de uso',
                onTap: () => context.push('/terms'),
              ),
              const SizedBox(height: AxoSpacing.sm),
              _Link(
                label: 'Política de privacidad',
                onTap: () => context.push('/privacy'),
              ),
              const SizedBox(height: AxoSpacing.sm),
              _Link(
                label: 'Notas de la versión',
                onTap: () => context.push('/changelog'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AxoType.heading.copyWith(color: c.textPrimary)),
        const SizedBox(height: AxoSpacing.sm),
        child,
      ],
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AxoSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: AxoType.body.copyWith(color: c.textSecondary),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: AxoType.body.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: AxoType.chipActive.copyWith(color: c.accentDefault),
      ),
    );
  }
}
