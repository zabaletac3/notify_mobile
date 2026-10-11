@Tags(<String>['integration'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:axonote_api/axonote_api.dart';
import 'package:test/test.dart';

/// Pruebas de integración contra el backend local. **No corren en la CI normal** (tag `integration`).
///
/// Preparación (el backend no se toca):
///   1. En `notify_backend`: `make up-podman` (PostgreSQL) y `make run`.
///      Con `MAIL_PROVIDER=log` (lo normal en dev) el código de verificación se imprime en la salida
///      de errores del proceso. Redirígela a un fichero y pásalo en `AXONOTE_MAIL_LOG`.
///   2. Exporta `AXONOTE_API_URL` (por defecto `http://localhost:8080/v1`) y `AXONOTE_MAIL_LOG`.
///   3. `dart test --run-skipped -t integration` desde `packages/axonote_api`.
///
/// Los parámetros de KDF que envía el cliente son ligeros (1 MiB, t=1), como pide el plan.
void main() {
  final baseUrl =
      Platform.environment['AXONOTE_API_URL'] ?? 'http://localhost:8080/v1';
  final mailLog = Platform.environment['AXONOTE_MAIL_LOG'];

  test(
    'registro, verificación, login, renovación y sincronización vacía',
    () async {
      if (mailLog == null || mailLog.isEmpty) {
        throw StateError(
          'Falta AXONOTE_MAIL_LOG con la salida del backend (donde se imprime el código).',
        );
      }

      final store = MemoryTokenStore();
      final client = HttpClient(
        HttpClientOptions(baseUrl: baseUrl, tokens: store),
      );
      final auth = AuthApi(client, deviceName: 'Integración');
      final sync = SyncApi(client);

      final email = 'intg-${DateTime.now().microsecondsSinceEpoch}@example.com';
      final authKey = _b64u(_randomBytes(32));
      final recoveryAuth = _b64u(_randomBytes(32));
      final userId = _uuidV7();

      // 1. Registro con claves propias y KDF ligero.
      final registered = await auth.register(
        RegisterRequestDto(
          userId: userId,
          fullName: 'Integración',
          email: email,
          acceptedTerms: true,
          authKey: authKey,
          recoveryAuth: recoveryAuth,
          keys: _keys(),
        ),
      );
      expect(registered.email, email);

      // 2. Verificación con el código que el backend escribió en su log de correo.
      final code = await _waitForCode(mailLog, email);
      final user = await auth.verifyEmail(email, code);
      expect(user.email, email);
      expect(user.emailVerified, isTrue);
      expect(await client.hasSession, isTrue);

      // 3. Inicio de sesión.
      final login = await auth.login(email, authKey);
      expect(login, isA<LoginSession>());
      expect((login as LoginSession).result.user.id, user.id);

      // 4. Renovación de sesión: se invalida el token de acceso para forzar el 401 y el refresh.
      final tokens = await store.read();
      await store.write(
        StoredTokens(
          accessToken: 'token-de-acceso-invalido',
          refreshToken: tokens!.refreshToken,
          expiresAt: tokens.expiresAt,
        ),
      );
      final session = await auth.currentSession();
      expect(session, isNotNull);
      expect(
        (await store.read())!.accessToken,
        isNot('token-de-acceso-invalido'),
        reason: 'la renovación guarda un token nuevo',
      );
      expect(await client.hasSession, isTrue);

      // 5. Sincronización vacía: debe responder sin cambios.
      final response = await sync.sync(
        SyncRequestDto(
          deviceId: userId,
          deviceName: 'Integración',
          changes: const <SyncChangeDto>[],
        ),
      );
      expect(response.cursor, isNotEmpty);
      expect(response.applied, isEmpty);
      expect(response.remoteChanges, isEmpty);
      expect(response.conflicts, isEmpty);

      // 6. Cierre de sesión.
      await auth.logout();
      expect(await client.hasSession, isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Map<String, Object?> _kdf() => <String, Object?>{
  'alg': 'argon2id',
  'memoryKiB': 1024,
  'iterations': 1,
  'parallelism': 1,
  'salt': _b64u(_randomBytes(16)),
};

KeyBundleDto _keys() {
  // Claves cifradas ficticias con la forma correcta: el servidor solo valida su forma.
  const sealedKey = 'a1.AAAAAAAAAAAAAAAA.AAAA';
  return KeyBundleDto(
    kdf: KdfParamsDto.fromJson(_kdf()),
    wrappedMasterKey: sealedKey,
    recoveryWrappedMasterKey: sealedKey,
    keysVersion: 0,
  );
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

String _b64u(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// UUID v7 como el que genera el cliente (los 48 bits altos son la hora).
String _uuidV7() {
  final bytes = _randomBytes(16);
  var timestamp = DateTime.now().millisecondsSinceEpoch;
  for (var i = 5; i >= 0; i--) {
    bytes[i] = timestamp % 256;
    timestamp ~/= 256;
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x70;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Espera a que el log del backend contenga el código de verificación de [email].
Future<String> _waitForCode(String path, String email) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    final file = File(path);
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      final at = content.indexOf('Para: $email');
      if (at >= 0) {
        final match = RegExp(r'código de verificación es (\d{6})')
            .firstMatch(content.substring(at));
        if (match != null) return match.group(1)!;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError('No se encontró el código de verificación para $email.');
}
