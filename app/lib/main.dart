import 'dart:async';

import 'package:axonote_crypto/axonote_crypto.dart'
    show Argon2idDeriver, SodiumArgon2id;
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/local_session.dart';
import 'bootstrap/providers.dart';
import 'data/crypto/argon2id_isolate.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/auth/state/vault_lifecycle.dart';
import 'features/auth/ui/session_expired_dialog.dart';
import 'features/settings/state/settings_controller.dart';
import 'features/vault/state/vault_lock.dart';
import 'features/vault/ui/vault_activity_gate.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'ui/secure_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final argon2id = await _createArgon2id();
  final deviceName = await _resolveDeviceName();
  runApp(
    ProviderScope(
      overrides: [
        argon2idProvider.overrideWithValue(argon2id),
        deviceNameProvider.overrideWithValue(deviceName),
        vaultActivityStoreProvider.overrideWith(
          (ref) => ref.watch(secureVaultPrefsProvider),
        ),
        vaultLifecycleProvider.overrideWith(_vaultLifecycle),
      ],
      child: const AxoNoteApp(),
    ),
  );
}

/// Cierra la costura entre las fases 7 y 8 que quedó pendiente: al desbloquear, abre la base local
/// de la cuenta y monta el motor de sincronización (fase 9); al bloquear o cerrar sesión, la
/// cierra (A3). Si la base no se puede abrir, la lista de notas se queda en carga y el resto de la
/// app sigue funcionando.
VaultLifecycle _vaultLifecycle(Ref ref) {
  return VaultLifecycle(
    onUnlocked: (userId, vault) async {
      try {
        final directory = await getApplicationSupportDirectory();
        final deviceId = await ref.read(deviceIdProvider.future);
        await ref
            .read(localSessionProvider.notifier)
            .open(
              ref: ref,
              vault: vault,
              userId: userId,
              directory: directory,
              http: ref.read(httpClientProvider),
              deviceId: deviceId,
              deviceName: ref.read(deviceNameProvider),
            );
      } catch (_) {
        // Sin base local no se pueden leer ni editar notas; se ignora aquí para no romper el
        // desbloqueo (la interfaz muestra el estado de carga).
      }
    },
    onLocked: () {
      unawaited(ref.read(localSessionProvider.notifier).close());
    },
    onSignedOut: (_) => ref.read(localSessionProvider.notifier).close(),
  );
}

/// Argon2id en un isolate (plan §4.4). Si el isolate no arranca, se usa la implementación directa
/// como último recurso (bloquearía la interfaz durante la derivación, pero es preferible a no
/// poder iniciar sesión).
Future<Argon2idDeriver> _createArgon2id() async {
  try {
    return await IsolateArgon2id.spawn();
  } catch (_) {
    return SodiumArgon2id.load();
  }
}

/// Nombre del modelo del dispositivo para la lista de dispositivos.
Future<String> _resolveDeviceName() async {
  try {
    return await AxonotePlatform.instance.deviceModel();
  } catch (_) {
    return 'Android';
  }
}

/// Raíz de la app: tema claro/oscuro del diseño, localización `es`, navegación con guardas y
/// arranque en frío del cofre.
class AxoNoteApp extends ConsumerStatefulWidget {
  const AxoNoteApp({super.key});

  @override
  ConsumerState<AxoNoteApp> createState() => _AxoNoteAppState();
}

class _AxoNoteAppState extends ConsumerState<AxoNoteApp> {
  @override
  void initState() {
    super.initState();
    // Arranque en frío: decide sesión, bloqueo y desbloqueo con la clave recordada.
    Future.microtask(() {
      ref.read(authControllerProvider.notifier).bootstrap();
      ref.read(settingsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeMode = themeModeOf(settings.theme);
    final textScale = textScaleOf(settings.textSize);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AxoTheme.light(),
      darkTheme: AxoTheme.dark(),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: VaultActivityGate(
          child: SessionNoticeHost(
            child: SecureScreen(
              restoreOnDispose: false,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
