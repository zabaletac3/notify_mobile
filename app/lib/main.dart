import 'package:axonote_crypto/axonote_crypto.dart'
    show Argon2idDeriver, SodiumArgon2id;
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap/providers.dart';
import 'data/crypto/argon2id_isolate.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/auth/ui/session_expired_dialog.dart';
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
      ],
      child: const AxoNoteApp(),
    ),
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
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AxoTheme.light(),
      darkTheme: AxoTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => VaultActivityGate(
        child: SessionNoticeHost(
          child: SecureScreen(
            restoreOnDispose: false,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
