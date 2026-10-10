import 'package:axonote_crypto/axonote_crypto.dart';

/// Qué cifra la clave de un elemento (igual que `ItemEntity` de `notify_web/.../crypto/vault.ts`).
enum ItemEntity { note, folder }

/// El cofre está bloqueado: no hay clave maestra en memoria. Quien llame debe desbloquear antes
/// (contraseña o biometría) o mostrar la pantalla de bloqueo.
class VaultLockedError implements Exception {
  const VaultLockedError();

  @override
  String toString() => 'VaultLockedError: el cofre está bloqueado';
}

/// Cofre de claves de la sesión (plan §5, referencia de comportamiento:
/// `notify_web/src/lib/data/crypto/vault.ts`): guarda la clave maestra **solo en memoria** y
/// reparte las claves de cada nota y carpeta, con caché. Al bloquear olvida todo (borra los
/// `SecretKeyBytes`, no solo la referencia). No sabe nada de pantallas ni de ajustes: eso lo
/// gestiona el gestor de bloqueo (`features/vault/state`).
class Vault {
  Vault({required this.userId});

  final String userId;

  SecretKeyBytes? _master;
  final Map<String, SecretKeyBytes> _cache = {};

  bool get isUnlocked => _master != null;

  /// Datos asociados (AAD) del contenido de un elemento: lo ligan a su cuenta, tipo e id.
  String dataAad(ItemEntity entity, String id) =>
      'apunte/v1/data/$userId/${entity.name}/$id';

  /// Datos asociados de la clave de un elemento.
  String keyAad(ItemEntity entity, String id) =>
      'apunte/v1/key/$userId/${entity.name}/$id';

  /// Pone la clave maestra en memoria (ya obtenida por quien llama: contraseña o biometría). Si ya
  /// había una, la borra antes.
  void unlockWith(SecretKeyBytes masterKey) {
    _master?.dispose();
    _master = masterKey;
  }

  /// Olvida la clave maestra y todas las de elementos: sobrescribe sus bytes y vacía la caché
  /// (plan §5.3: "bloqueo que borra todo de memoria").
  void lock() {
    _master?.dispose();
    _master = null;
    for (final key in _cache.values) {
      key.dispose();
    }
    _cache.clear();
  }

  /// La clave maestra, si el cofre está desbloqueado. Lanza [VaultLockedError] si no.
  SecretKeyBytes requireKey() {
    final master = _master;
    if (master == null) throw const VaultLockedError();
    return master;
  }

  /// Clave de la base de datos local, derivada de la clave maestra (A1, A2 del plan). Sin clave
  /// maestra no se puede derivar: con el cofre bloqueado esto lanza [VaultLockedError], así que la
  /// base nunca se abre bloqueada.
  Future<SecretKeyBytes> localDbKey() => deriveLocalDbKey(requireKey(), userId);

  /// Clave nueva para un elemento, ya cifrada con la maestra.
  ///
  /// El [SecretKeyBytes] de [NewItemKey.key] es **la misma instancia** que queda en la caché
  /// interna, no una copia: quien la reciba no debe llamar a `dispose()` sobre ella (seguiría
  /// usándose desde la caché hasta el próximo [lock]). Es [lock] quien la borra, junto con el
  /// resto de la caché.
  Future<NewItemKey> newItemKey(ItemEntity entity, String id) async {
    final master = requireKey();
    final key = generateKeyBytes();
    final wrapped = await wrap(master, key, keyAad(entity, id));
    _cache[_cacheKey(entity, id, wrapped)] = key;
    return NewItemKey(key: key, wrapped: wrapped);
  }

  /// Clave de un elemento a partir de la que guarda el servidor. Se recuerda en caché mientras
  /// esté desbloqueado.
  ///
  /// Igual que en [newItemKey]: el [SecretKeyBytes] devuelto es el de la caché, no una copia; no
  /// se debe llamar a `dispose()` sobre él. Se borra solo al bloquear ([lock]).
  Future<SecretKeyBytes> itemKey(
    ItemEntity entity,
    String id,
    Sealed wrapped,
  ) async {
    final master = requireKey();
    final cacheKey = _cacheKey(entity, id, wrapped);
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    final key = await unwrap(master, wrapped, keyAad(entity, id));
    _cache[cacheKey] = key;
    return key;
  }

  /// Cambia la clave de un elemento (al revocar un enlace público, o al duplicar). Mismo aviso que
  /// [newItemKey]: no hay que borrar la clave devuelta a mano.
  Future<NewItemKey> rotateItemKey(ItemEntity entity, String id) =>
      newItemKey(entity, id);

  String _cacheKey(ItemEntity entity, String id, Sealed wrapped) =>
      '${entity.name}:$id:$wrapped';
}

/// Clave nueva de un elemento junto con su versión cifrada con la clave maestra. [key] es la
/// misma instancia que guarda el [Vault] en su caché (ver [Vault.newItemKey]): no se debe llamar
/// a `dispose()` sobre ella; el [Vault] la borra al bloquear.
class NewItemKey {
  const NewItemKey({required this.key, required this.wrapped});

  final SecretKeyBytes key;
  final Sealed wrapped;
}
