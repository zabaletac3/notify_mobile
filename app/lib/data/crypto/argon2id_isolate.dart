import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';

/// Argon2id en un isolate de trabajo (plan §4.4: «Argon2id: siempre en un isolate»).
///
/// La librería nativa de libsodium se carga **una sola vez** dentro del isolate y se atienden las
/// peticiones de derivación en serie. Mientras el isolate calcula, la interfaz sigue fluida: el
/// estado muestra un indicador de progreso. La contraseña cruza al isolate solo como bytes y se
/// borra allí al terminar la petición.
class IsolateArgon2id implements Argon2idDeriver {
  IsolateArgon2id._(this._isolate, this._requests, this._subscription);

  final Isolate _isolate;
  final SendPort _requests;
  final StreamSubscription<Object?> _subscription;
  final ReceivePort _responses = ReceivePort();
  final Map<int, Completer<Uint8List>> _pending = {};
  int _nextId = 0;
  bool _disposed = false;

  /// Arranca el isolate y espera a que la librería nativa esté cargada.
  static Future<IsolateArgon2id> spawn() async {
    final handshake = ReceivePort();
    final isolate = await Isolate.spawn(
      _workerMain,
      handshake.sendPort,
      debugName: 'axonote-argon2id',
    );
    final completer = Completer<SendPort>();
    final sub = handshake.listen((message) {
      if (message is SendPort && !completer.isCompleted) {
        completer.complete(message);
      }
    });
    final requests = await completer.future;
    // El canal de traspaso ya cumplió su función; las respuestas van por `_responses`.
    await sub.cancel();
    handshake.close();
    final worker = IsolateArgon2id._(isolate, requests, sub);
    worker._responses.listen(worker._onResponse);
    return worker;
  }

  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required int memoryKiB,
    required int iterations,
  }) {
    if (_disposed) {
      return Future.error(StateError('IsolateArgon2id ya se cerró'));
    }
    final id = _nextId++;
    final completer = Completer<Uint8List>();
    _pending[id] = completer;
    _requests.send(<Object?>[
      id,
      _responses.sendPort,
      password,
      salt,
      memoryKiB,
      iterations,
    ]);
    return completer.future;
  }

  void _onResponse(Object? message) {
    if (message is! List || message.length != 3) return;
    final id = message[0] as int;
    final completer = _pending.remove(id);
    if (completer == null) return;
    final error = message[1];
    final bytes = message[2];
    if (error is String) {
      completer.completeError(StateError(error));
    } else {
      completer.complete(bytes as Uint8List);
    }
  }

  /// Cierra el isolate. Idempotente.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _isolate.kill(priority: Isolate.immediate);
    await _subscription.cancel();
    _responses.close();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('IsolateArgon2id cerrado'));
      }
    }
    _pending.clear();
  }
}

/// Punto de entrada del isolate de Argon2id.
Future<void> _workerMain(SendPort handshake) async {
  final inbox = ReceivePort();
  handshake.send(inbox.sendPort);
  final argon2id = await SodiumArgon2id.load();
  await for (final message in inbox) {
    if (message is! List || message.length != 6) continue;
    final id = message[0] as int;
    final reply = message[1] as SendPort;
    final password = message[2] as Uint8List;
    final salt = message[3] as Uint8List;
    final memoryKiB = message[4] as int;
    final iterations = message[5] as int;
    try {
      final bytes = await argon2id.derive(
        password: password,
        salt: salt,
        memoryKiB: memoryKiB,
        iterations: iterations,
      );
      reply.send(<Object?>[id, null, bytes]);
    } catch (e) {
      // Solo el mensaje de la excepción: nunca la contraseña ni los bytes.
      reply.send(<Object?>[id, e.toString(), Uint8List(0)]);
    } finally {
      password.fillRange(0, password.length, 0);
    }
  }
}
