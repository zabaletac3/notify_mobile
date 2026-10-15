import 'package:axonote_api/axonote_api.dart' as api;
import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth/account_token_store.dart';
import '../data/auth/api_auth_repository.dart';
import '../data/auth/local_data_cleaner.dart';
import '../data/auth/session_events.dart';
import '../data/auth/vault_prefs_repository.dart';
import '../data/secure/account_secure_store.dart';
import '../data/secure/secure_store.dart';
import '../features/vault/state/clock.dart';

/// Raíz de composición (plan §4.1): construye los adaptadores de datos y los expone como
/// proveedores. Aquí es donde se inyecta el almacén seguro, el cliente HTTP y el derivador de
/// Argon2id; las capas de estado solo ven las interfaces de `axonote_domain`.

/// Almacén clave-valor cifrado por el sistema (§5.1).
final secureStoreProvider = Provider<SecureStore>(
  (ref) => FlutterSecureStore(),
);

final accountSecureStoreProvider = Provider<AccountSecureStore>(
  (ref) => AccountSecureStore(ref.watch(secureStoreProvider)),
);

/// Sesión, preferencias de bloqueo y última actividad de la cuenta (§5.1, §5.3).
final secureVaultPrefsProvider = Provider<SecureVaultPrefs>(
  (ref) => SecureVaultPrefs(ref.watch(accountSecureStoreProvider)),
);

/// Interfaz que consume el estado (el almacén seguro real es [secureVaultPrefsProvider]).
final vaultPrefsProvider = Provider<VaultPrefsRepository>(
  (ref) => ref.watch(secureVaultPrefsProvider),
);

/// Canal único de eventos de sesión (§4.3).
final sessionEventBusProvider = Provider<SessionEventBus>((ref) {
  final bus = SessionEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});

/// `API_URL` de la §4.5. En desarrollo apunta al backend local por USB (`adb reverse`).
final apiUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080/v1',
  ),
);

/// Un solo `HttpClient` por cuenta (el vuelo único de la renovación es por instancia, ver
/// `docs/decisions.md`, Fase 4).
final httpClientProvider = Provider<api.HttpClient>((ref) {
  return api.HttpClient(
    api.HttpClientOptions(
      baseUrl: ref.watch(apiUrlProvider),
      tokens: AccountTokenStore(ref.watch(accountSecureStoreProvider)),
    ),
  );
});

/// Nombre del dispositivo para la lista de dispositivos. Se resuelve en el arranque (ver
/// `main.dart`) y se sobrescribe con el modelo real del dispositivo.
final deviceNameProvider = Provider<String>((ref) => 'Android');

/// Identificador de este dispositivo, generado una vez y guardado en el almacén seguro (ver
/// `AccountSecureStore.readOrCreateDeviceId`). Lo necesitan la base local y el motor de
/// sincronización antes de abrir nada.
final deviceIdProvider = FutureProvider<String>((ref) {
  return ref.watch(accountSecureStoreProvider).readOrCreateDeviceId(newId);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(
    http: ref.watch(httpClientProvider),
    account: ref.watch(accountSecureStoreProvider),
    events: ref.watch(sessionEventBusProvider),
    deviceName: ref.watch(deviceNameProvider),
  );
});

/// Derivador de Argon2id. Se sobrescribe en el arranque con el isolate real (o, en pruebas, con
/// uno falso y rápido).
final argon2idProvider = Provider<crypto.Argon2idDeriver>(
  (ref) => throw UnimplementedError('argon2idProvider debe sobrescribirse'),
);

/// Parámetros de Argon2id para cuentas nuevas: los reales por defecto; las pruebas de integración
/// los bajan a los ligeros.
final kdfBaseProvider = Provider<crypto.KdfBase>((ref) => crypto.defaultKdf);

/// Reloj inyectable (inactividad, enfriamiento del reenvío).
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Borrado de la copia local de una cuenta al cerrar sesión o recibir `device-revoked` (A1).
final localDataCleanerProvider = Provider<LocalDataCleaner>(
  (ref) => const FileSystemDataCleaner(),
);
