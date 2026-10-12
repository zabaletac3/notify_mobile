import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart';

/// Activa `FLAG_SECURE` (plan §5.4) mientras está montado: oculta la vista previa en recientes y
/// bloquea capturas. Se usa en las pantallas «siempre» seguras: clave de recuperación, códigos de
/// respaldo, secreto TOTP y desbloqueo.
///
/// Los errores del canal nativo se ignoran a propósito (best-effort): si el endurecimiento no se
/// puede aplicar, la pantalla debe seguir funcionando. No llama a `setSecure(false)` al salir:
/// el ajuste de privacidad global (fase 11) decide el estado base; las pantallas que envuelve
/// reponen `false` al desmontarse porque son de uso puntual.
class SecureScreen extends StatefulWidget {
  const SecureScreen({
    required this.child,
    this.restoreOnDispose = true,
    super.key,
  });

  final Widget child;

  /// Si es `true` (por defecto), al desmontarse vuelve a `false`.
  final bool restoreOnDispose;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _set(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.restoreOnDispose) _set(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _set(true);
  }

  void _set(bool secure) {
    AxonotePlatform.instance.setSecure(secure).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
