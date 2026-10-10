import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Envoltura mínima sobre un almacén clave-valor cifrado por el sistema (Android Keystore, vía
/// `flutter_secure_storage`), para poder sustituirlo por una copia en memoria en pruebas
/// unitarias (ver [FakeSecureStore]). No sabe qué significa cada clave: eso lo decide
/// `AccountSecureStore`.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Borra toda clave para la que `test` devuelva `true`.
  Future<void> deleteWhere(bool Function(String key) test);
}

/// Implementación real: `flutter_secure_storage` sobre Android Keystore (`EncryptedSharedPreferences`
/// cuando el dispositivo lo admite). Nada de lo que pasa por aquí se registra ni se expone en
/// `toString()`.
class FlutterSecureStore implements SecureStore {
  FlutterSecureStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteWhere(bool Function(String key) test) async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (test(key)) await _storage.delete(key: key);
    }
  }
}

/// Copia en memoria para pruebas unitarias: nunca toca el sistema operativo.
class FakeSecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteWhere(bool Function(String key) test) async {
    _values.removeWhere((key, _) => test(key));
  }

  /// Solo para pruebas: qué hay guardado ahora mismo.
  Map<String, String> get debugValues => Map.unmodifiable(_values);
}
