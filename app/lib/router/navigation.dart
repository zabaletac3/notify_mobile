import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// `true` si hay una pantalla anterior a la que volver. Usa el `Navigator` (funciona con `go_router`
/// y también en pruebas/goldens sin router).
bool canGoBack(BuildContext context) => Navigator.of(context).canPop();

/// Vuelve a la pantalla anterior. Si no hay pila (se llegó con `go`, p. ej. desde un enlace directo),
/// cae a la lista de notas para no dejar al usuario atrapado. Todos los botones «atrás» de la app
/// usan esto.
void goBack(BuildContext context) {
  if (canGoBack(context)) {
    context.pop();
  } else {
    context.go('/notes');
  }
}
