import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart' show SecretKeyBytes;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session.dart';
import '../../../data/crypto/vault.dart';
import 'clock.dart';
import 'timer_factory.dart';

/// Gestor de bloqueo del cofre (plan §5.3): decide cuándo desbloquear y cuándo bloquear, y lleva
/// la cuenta del tiempo de inactividad. Guarda la clave maestra solo en el [Vault] (en memoria) y,
/// si toca recordarla, en `axonote_platform` (Keystore ligado a biometría).
///
/// No sabe cómo se obtiene la clave maestra la primera vez (contraseña + red): eso es de la
/// pantalla de inicio de sesión (fase 8). Este gestor recibe la clave ya en la mano
/// ([unlock]) o la recupera de lo guardado ([unlockWithStoredKey]).
class VaultLockController {
  VaultLockController({
    required Ref ref,
    AxonotePlatform? platform,
    Clock clock = const SystemClock(),
    TimerFactory timerFactory = const RealTimerFactory(),
  }) : _ref = ref,
       _platform = platform ?? AxonotePlatform.instance,
       _clock = clock,
       _timerFactory = timerFactory;

  final Ref _ref;
  final AxonotePlatform _platform;
  final Clock _clock;
  final TimerFactory _timerFactory;

  Vault? _vault;
  LockSettings _settings = const LockSettings();
  CancelableTimer? _timer;
  DateTime? _lastActiveAt;
  bool _inBackground = false;

  /// El cofre actual. Lanza [VaultLockedError] si no hay sesión o está bloqueado.
  Vault get vault {
    final current = _vault;
    if (current == null) throw const VaultLockedError();
    return current;
  }

  LockSettings get settings => _settings;

  bool get _isUnlocked => _ref.read(sessionProvider) == AxoSession.unlocked;

  void _setSession(AxoSession value) =>
      _ref.read(sessionProvider.notifier).set(value);

  /// Cambia los ajustes que gobiernan el bloqueo (§5.3). Si el cofre está desbloqueado, reajusta
  /// el temporizador al nuevo `lockTimeout` sin perder la actividad ya contada.
  void updateSettings(LockSettings settings) {
    _settings = settings;
    if (_isUnlocked) _rescheduleTimer();
  }

  /// Desbloquea con una clave maestra ya obtenida (contraseña, tras `unlockWithPassword` de
  /// `axonote_crypto`, o la que devolvió [unlockWithStoredKey]). Con `remember` la guarda en
  /// `axonote_platform` para no pedir la contraseña la próxima vez: con `requireAuth` según
  /// `biometricLock` de los ajustes actuales.
  Future<void> unlock({
    required String userId,
    required SecretKeyBytes masterKey,
    required bool remember,
  }) async {
    _replaceVault(userId, masterKey);
    if (remember) {
      await _platform.storeMasterKey(
        userId: userId,
        bytes: masterKey.bytes,
        requireAuth: _settings.biometricLock,
      );
    }
    _setSession(AxoSession.unlocked);
    _noteActivityNow();
  }

  /// Intenta desbloquear con la clave recordada en el dispositivo (pide biometría si
  /// `requireAuth` se guardó como `true`). `false` si no hay nada guardado para `userId`; relanza
  /// cualquier otro error ([AuthCancelled], [AuthLockedOut], etc.) para que la pantalla lo
  /// muestre. Si la clave quedó invalidada ([KeyInvalidated]), también devuelve `false`: ya se
  /// borró en `axonote_platform`, así que toca pedir la contraseña.
  Future<bool> unlockWithStoredKey({
    required String userId,
    required String prompt,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await _platform.loadMasterKey(userId: userId, prompt: prompt);
    } on NoStoredKey {
      return false;
    } on KeyInvalidated {
      return false;
    }
    _replaceVault(userId, SecretKeyBytes(bytes));
    _setSession(AxoSession.unlocked);
    _noteActivityNow();
    return true;
  }

  void _replaceVault(String userId, SecretKeyBytes masterKey) {
    _vault?.lock();
    final vault = Vault(userId: userId);
    vault.unlockWith(masterKey);
    _vault = vault;
  }

  /// Bloquea (manual, por tiempo o al salir): borra la clave maestra y las de elemento de la
  /// memoria. No cierra la sesión: los tokens y el `KeyBundle` siguen guardados, así que se puede
  /// volver a desbloquear con la contraseña o la biometría.
  void lock() {
    _vault?.lock();
    _stopTimer();
    _lastActiveAt = null;
    _setSession(AxoSession.locked);
  }

  /// Cierra la sesión: bloquea y borra además la clave maestra guardada en `axonote_platform`
  /// (A1: cerrar sesión o `device-revoked` borra las claves locales). No borra la base de datos
  /// local ni el resto de lo guardado en `flutter_secure_storage`: eso es de quien orqueste el
  /// cierre de sesión completo (fase 8), que también sabe si hay que olvidar la cuenta entera.
  Future<void> signOut() async {
    final userId = _vault?.userId;
    lock();
    _vault = null;
    if (userId != null) await _platform.deleteMasterKey(userId: userId);
    _setSession(AxoSession.noSession);
  }

  /// Llamar ante cualquier interacción de la persona con la pantalla (equivalente al
  /// `pointerdown` de la web): reinicia la cuenta de inactividad.
  void noteActivity() {
    if (!_isUnlocked) return;
    _noteActivityNow();
  }

  void _noteActivityNow() {
    _lastActiveAt = _clock.now();
    if (_isUnlocked) _rescheduleTimer();
  }

  /// La app pasó a segundo plano (`AppLifecycleState.paused` o `.hidden`).
  void appBackgrounded() {
    _inBackground = true;
    if (!_isUnlocked) return;
    if (_settings.lockOnExit || _settings.lockTimeout == LockTimeout.immediately) {
      lock();
      return;
    }
    // El tiempo en segundo plano se descuenta al volver (appResumed), con la hora de la última
    // actividad real ya guardada: no hace falta un temporizador mientras no hay pantalla.
    _stopTimer();
  }

  /// La app volvió a primer plano.
  void appResumed() {
    _inBackground = false;
    if (!_isUnlocked) return;
    final after = _settings.lockTimeout.after;
    final lastActiveAt = _lastActiveAt;
    if (after != null &&
        lastActiveAt != null &&
        _clock.now().difference(lastActiveAt) >= after) {
      lock();
      return;
    }
    _rescheduleTimer();
  }

  void _rescheduleTimer() {
    _stopTimer();
    if (_inBackground) return;
    final after = _settings.lockTimeout.after;
    final lastActiveAt = _lastActiveAt;
    if (after == null || lastActiveAt == null) return;
    final remaining = after - _clock.now().difference(lastActiveAt);
    if (remaining <= Duration.zero) {
      lock();
      return;
    }
    _timer = _timerFactory.schedule(remaining, lock);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _stopTimer();
    _vault?.lock();
  }
}

final vaultLockControllerProvider = Provider<VaultLockController>((ref) {
  final controller = VaultLockController(ref: ref);
  ref.onDispose(controller.dispose);
  return controller;
});
