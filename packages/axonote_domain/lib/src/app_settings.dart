/// Preferencias de la app por cuenta (las que la web guarda en el dispositivo, no sincronizadas).
/// Ver `notify_web/src/lib/domain/settings.ts` (`DEFAULT_SETTINGS`).
enum ThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const ThemePreference(this.wire);

  final String wire;
}

enum TextSize {
  small('small'),
  medium('medium'),
  large('large');

  const TextSize(this.wire);

  final String wire;
}

enum NoteOrder {
  updated('updated'),
  created('created'),
  title('title');

  const NoteOrder(this.wire);

  final String wire;
}

/// Preferencias locales de la app (tema, tamaño, orden, vista previa…). Los ajustes de bloqueo
/// viven en [LockSettings] y los de sincronización en `SyncSettings` (base local).
class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.textSize = TextSize.medium,
    this.noteOrder = NoteOrder.updated,
    this.openWithNewNote = false,
    this.showPreview = true,
    this.language = 'es',
  });

  final ThemePreference theme;
  final TextSize textSize;
  final NoteOrder noteOrder;
  final bool openWithNewNote;
  final bool showPreview;
  final String language;

  AppSettings copyWith({
    ThemePreference? theme,
    TextSize? textSize,
    NoteOrder? noteOrder,
    bool? openWithNewNote,
    bool? showPreview,
    String? language,
  }) => AppSettings(
    theme: theme ?? this.theme,
    textSize: textSize ?? this.textSize,
    noteOrder: noteOrder ?? this.noteOrder,
    openWithNewNote: openWithNewNote ?? this.openWithNewNote,
    showPreview: showPreview ?? this.showPreview,
    language: language ?? this.language,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.theme == theme &&
      other.textSize == textSize &&
      other.noteOrder == noteOrder &&
      other.openWithNewNote == openWithNewNote &&
      other.showPreview == showPreview &&
      other.language == language;

  @override
  int get hashCode => Object.hash(
    theme,
    textSize,
    noteOrder,
    openWithNewNote,
    showPreview,
    language,
  );
}
