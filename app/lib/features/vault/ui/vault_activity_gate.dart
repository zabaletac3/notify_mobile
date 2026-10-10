import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/vault_lock.dart';

/// Envuelve la app para avisar al [VaultLockController] de la actividad de la persona y de los
/// cambios de ciclo de vida (plan §5.3): cualquier toque reinicia la cuenta de inactividad, y
/// pasar a segundo plano bloquea según `lockOnExit` o `lockTimeout`.
class VaultActivityGate extends ConsumerStatefulWidget {
  const VaultActivityGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<VaultActivityGate> createState() => _VaultActivityGateState();
}

class _VaultActivityGateState extends ConsumerState<VaultActivityGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(vaultLockControllerProvider);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        controller.appBackgrounded();
        break;
      case AppLifecycleState.resumed:
        controller.appResumed();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onPointerDown(PointerDownEvent event) =>
      ref.read(vaultLockControllerProvider).noteActivity();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: widget.child,
    );
  }
}
