/// Cola para que las escrituras locales (y aplicar lo que llega del servidor) no se pisen entre
/// sí. Leer, cifrar/descifrar y escribir es asíncrono y no puede ir dentro de una transacción de
/// la base, así que cada operación se ejecuta de principio a fin antes de que empiece la
/// siguiente. Equivale a `Mutex` de `notify_web/src/lib/data/local/gate.ts`.
class Mutex {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
