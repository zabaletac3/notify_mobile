import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;

/// Las pruebas abren varias bases en memoria a la vez; drift avisa de ello en modo debug. No es
/// un problema aquí (cada una tiene su propio ejecutor), así que se silencia ese aviso.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
