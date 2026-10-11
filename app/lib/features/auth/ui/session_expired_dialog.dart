import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/session.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/components.dart';
import '../state/auth_controller.dart';

/// Muestra el diálogo de «Sesión expirada» (tablero «7 · Estados y errores — Sesión expirada»)
/// cuando la sesión se vence mientras el cofre está desbloqueado. La interfaz de login ya explica
/// el aviso por banner cuando la sesión se perdió sin estar desbloqueado.
class SessionNoticeHost extends ConsumerStatefulWidget {
  const SessionNoticeHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SessionNoticeHost> createState() => _SessionNoticeHostState();
}

class _SessionNoticeHostState extends ConsumerState<SessionNoticeHost> {
  bool _showing = false;

  Future<void> _maybeShow(AuthNotice? notice) async {
    if (notice == null || _showing) return;
    if (ref.read(sessionProvider) != AxoSession.unlocked) return;
    _showing = true;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AxoDialog(
        icon: 'lock',
        title: l10n.sessionExpiredTitle,
        content: Text(l10n.sessionExpiredBody),
        actions: [
          AxoButton(
            label: l10n.sessionExpiredOffline,
            variant: AxoButtonVariant.outline,
            onPressed: () {
              ref.read(authControllerProvider.notifier).clearNotice();
              Navigator.of(dialogContext).pop();
            },
          ),
          AxoButton(
            label: l10n.sessionExpiredLogin,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(authControllerProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
    _showing = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthNotice?>(authControllerProvider.select((s) => s.notice), (
      _,
      next,
    ) {
      _maybeShow(next);
    });
    return widget.child;
  }
}
