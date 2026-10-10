import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tema de AxoNote (claro y oscuro) a partir de los tokens del diseño.
abstract final class AxoTheme {
  static ThemeData light() => _build(AxoColors.light, Brightness.light);

  static ThemeData dark() => _build(AxoColors.dark, Brightness.dark);

  static ThemeData _build(AxoColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accentDefault,
      onPrimary: c.accentOn,
      secondary: c.bgHover,
      onSecondary: c.textPrimary,
      error: c.statusDanger,
      onError: c.accentOn,
      surface: c.bgEditor,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.bgApp,
      outline: c.borderDefault,
    );

    final textTheme = TextTheme(
      titleLarge: AxoType.title.copyWith(color: c.textPrimary),
      headlineSmall: AxoType.heading.copyWith(color: c.textPrimary),
      titleMedium: AxoType.heading.copyWith(color: c.textPrimary),
      bodyMedium: AxoType.body.copyWith(color: c.textPrimary),
      bodySmall: AxoType.caption.copyWith(color: c.textSecondary),
      labelMedium: AxoType.label.copyWith(color: c.textPrimary),
      labelSmall: AxoType.caption.copyWith(color: c.textTertiary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AxoType.family,
      scaffoldBackgroundColor: c.bgApp,
      canvasColor: c.bgEditor,
      dividerColor: c.borderDefault,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkSplash.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }
}
