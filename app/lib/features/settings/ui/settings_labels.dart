// Textos de las opciones de Ajustes (de `notify_web/src/lib/domain/settings.ts`) y datos de
// muestra para las vistas previas/goldens (nombre y versión).

String settingsThemeLabel(String value) => switch (value) {
  'light' => 'Claro',
  'dark' => 'Oscuro',
  _ => 'Sistema',
};

String settingsTextSizeLabel(String value) => switch (value) {
  'small' => 'Pequeño',
  'large' => 'Grande',
  _ => 'Mediano',
};

String settingsNoteOrderLabel(String value) => switch (value) {
  'created' => 'Fecha de creación',
  'title' => 'Título',
  _ => 'Fecha de edición',
};

String settingsLanguageLabel(String value) => switch (value) {
  'es' => 'Español',
  _ => value,
};

String settingsLockTimeoutLabel(String value) => switch (value) {
  'immediately' => 'Inmediatamente',
  '5m' => '5 minutos',
  '15m' => '15 minutos',
  'never' => 'Nunca',
  _ => '1 minuto',
};

/// Nombre y correo de muestra para «Mi cuenta» cuando no hay sesión (vistas previas/goldens).
const String settingsSampleName = 'Nombre Apellido';
const String settingsSampleEmail = 'nombre@correo.com';
const String settingsSampleInitials = 'NA';

/// Versión mostrada en «Acerca de» (maqueta; en 11.6 saldrá del paquete).
const String settingsSampleVersion = '1.0.0';
const String settingsSampleBuild = '1';
