import '../json.dart';
import 'common.dart';

/// Dispositivo con sesión activa.
class DeviceDto {
  const DeviceDto({
    required this.id,
    required this.name,
    required this.platform,
    required this.lastActiveAt,
    required this.current,
  });

  factory DeviceDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return DeviceDto(
      id: r.child('id').asString(),
      name: r.child('name').asString(),
      platform: enumFromWire(
        DevicePlatform.values,
        (value) => value.wire,
        r.child('platform').asString(),
        'device.platform',
      ),
      lastActiveAt: r.child('lastActiveAt').asDateTime(),
      current: r.child('current').asBool(),
    );
  }

  final String id;
  final String name;
  final DevicePlatform platform;
  final DateTime lastActiveAt;

  /// `true` en el dispositivo que usa la sesión actual.
  final bool current;
}

/// Lo que guarda el servidor de un enlace público.
class SharedNoteDto {
  const SharedNoteDto({
    required this.id,
    required this.noteId,
    required this.slug,
    required this.wrappedShareKey,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SharedNoteDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return SharedNoteDto(
      id: r.child('id').asString(),
      noteId: r.child('noteId').asString(),
      slug: r.child('slug').asString(),
      wrappedShareKey: r.child('wrappedShareKey').asString(),
      payload: r.child('payload').asString(),
      createdAt: r.child('createdAt').asDateTime(),
      updatedAt: r.child('updatedAt').asDateTime(),
    );
  }

  final String id;
  final String noteId;
  final String slug;

  /// Clave del enlace, cifrada con la clave maestra del dueño.
  final Sealed wrappedShareKey;

  /// `{ title, content }` rellenado y cifrado con la clave del enlace.
  final Sealed payload;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Cuerpo de `PUT /notes/{noteId}/share`.
class ShareInputDto {
  const ShareInputDto({
    required this.slug,
    required this.wrappedShareKey,
    required this.payload,
  });

  final String slug;
  final Sealed wrappedShareKey;
  final Sealed payload;

  Map<String, Object?> toJson() => <String, Object?>{
    'slug': slug,
    'wrappedShareKey': wrappedShareKey,
    'payload': payload,
  };
}

/// Lo que devuelve el servidor a quien abre un enlace público (sin sesión).
class PublicNoteDto {
  const PublicNoteDto({required this.payload, required this.updatedAt});

  factory PublicNoteDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return PublicNoteDto(
      payload: r.child('payload').asString(),
      updatedAt: r.child('updatedAt').asDateTime(),
    );
  }

  final Sealed payload;
  final DateTime updatedAt;
}

/// Espacio usado frente a la cuota.
class StorageUsageDto {
  const StorageUsageDto({
    required this.usedBytes,
    required this.quotaBytes,
    required this.notesBytes,
    required this.imagesBytes,
    required this.trashBytes,
  });

  factory StorageUsageDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return StorageUsageDto(
      usedBytes: r.child('usedBytes').asInt(),
      quotaBytes: r.child('quotaBytes').asInt(),
      notesBytes: r.child('notesBytes').asInt(),
      imagesBytes: r.child('imagesBytes').asInt(),
      trashBytes: r.child('trashBytes').asInt(),
    );
  }

  final int usedBytes;
  final int quotaBytes;
  final int notesBytes;
  final int imagesBytes;
  final int trashBytes;
}

/// Preferencias de la cuenta.
class AppSettingsDto {
  const AppSettingsDto({
    required this.theme,
    required this.textSize,
    required this.noteOrder,
    required this.openWithNewNote,
    required this.showPreview,
    required this.language,
    required this.autoSync,
    required this.wifiOnly,
    required this.biometricLock,
    required this.lockOnExit,
    required this.lockTimeout,
    required this.twoFactor,
  });

  factory AppSettingsDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return AppSettingsDto(
      theme: enumFromWire(
        ThemePreference.values,
        (value) => value.wire,
        r.child('theme').asString(),
        'settings.theme',
      ),
      textSize: enumFromWire(
        TextSize.values,
        (value) => value.wire,
        r.child('textSize').asString(),
        'settings.textSize',
      ),
      noteOrder: enumFromWire(
        NoteOrder.values,
        (value) => value.wire,
        r.child('noteOrder').asString(),
        'settings.noteOrder',
      ),
      openWithNewNote: r.child('openWithNewNote').asBool(),
      showPreview: r.child('showPreview').asBool(),
      language: r.child('language').asString(),
      autoSync: r.child('autoSync').asBool(),
      wifiOnly: r.child('wifiOnly').asBool(),
      biometricLock: r.child('biometricLock').asBool(),
      lockOnExit: r.child('lockOnExit').asBool(),
      lockTimeout: enumFromWire(
        LockTimeout.values,
        (value) => value.wire,
        r.child('lockTimeout').asString(),
        'settings.lockTimeout',
      ),
      twoFactor: r.child('twoFactor').asBool(),
    );
  }

  final ThemePreference theme;
  final TextSize textSize;
  final NoteOrder noteOrder;
  final bool openWithNewNote;
  final bool showPreview;
  final String language;
  final bool autoSync;
  final bool wifiOnly;
  final bool biometricLock;
  final bool lockOnExit;
  final LockTimeout lockTimeout;
  final bool twoFactor;
}

/// Cuerpo de `PATCH /settings`: cualquier subconjunto de [AppSettingsDto] (salvo `twoFactor`, que es
/// de solo lectura y el servidor rechaza).
class AppSettingsPatchDto {
  const AppSettingsPatchDto({
    this.theme,
    this.textSize,
    this.noteOrder,
    this.openWithNewNote,
    this.showPreview,
    this.language,
    this.autoSync,
    this.wifiOnly,
    this.biometricLock,
    this.lockOnExit,
    this.lockTimeout,
  });

  final ThemePreference? theme;
  final TextSize? textSize;
  final NoteOrder? noteOrder;
  final bool? openWithNewNote;
  final bool? showPreview;
  final String? language;
  final bool? autoSync;
  final bool? wifiOnly;
  final bool? biometricLock;
  final bool? lockOnExit;
  final LockTimeout? lockTimeout;

  bool get isEmpty =>
      theme == null &&
      textSize == null &&
      noteOrder == null &&
      openWithNewNote == null &&
      showPreview == null &&
      language == null &&
      autoSync == null &&
      wifiOnly == null &&
      biometricLock == null &&
      lockOnExit == null &&
      lockTimeout == null;

  Map<String, Object?> toJson() => <String, Object?>{
    if (theme != null) 'theme': theme!.wire,
    if (textSize != null) 'textSize': textSize!.wire,
    if (noteOrder != null) 'noteOrder': noteOrder!.wire,
    if (openWithNewNote != null) 'openWithNewNote': openWithNewNote,
    if (showPreview != null) 'showPreview': showPreview,
    if (language != null) 'language': language,
    if (autoSync != null) 'autoSync': autoSync,
    if (wifiOnly != null) 'wifiOnly': wifiOnly,
    if (biometricLock != null) 'biometricLock': biometricLock,
    if (lockOnExit != null) 'lockOnExit': lockOnExit,
    if (lockTimeout != null) 'lockTimeout': lockTimeout!.wire,
  };
}
