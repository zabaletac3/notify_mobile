/// Tokens de diseño de AxoNote (ver `docs/screens.md` y §10 del plan).
///
/// - Colores: sets claro y oscuro del diseño (`Apunte/Color/Light` y `Apunte/Color oscuro/Dark`),
///   con los mismos valores que `notify_web/docs/design-tokens.md`.
/// - Tipografía: **Inter** (empaquetada en `assets/fonts`).
/// - Radios y medidas: del sistema validado en `notify_web/docs/components.md`.
library;

import 'package:flutter/material.dart';

/// Colores del tema, en claro y oscuro. Se expone como `ThemeExtension` para poder leerlo desde los
/// componentes con `Theme.of(context).extension<AxoColors>()`.
@immutable
class AxoColors extends ThemeExtension<AxoColors> {
  const AxoColors({
    required this.bgEditor,
    required this.bgApp,
    required this.bgSidebar,
    required this.bgSelected,
    required this.bgHover,
    required this.bgInput,
    required this.borderDefault,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentDefault,
    required this.accentOn,
    required this.tagAmber,
    required this.tagPlum,
    required this.statusDanger,
    required this.statusDangerBg,
    required this.statusSuccess,
  });

  final Color bgEditor;
  final Color bgApp;
  final Color bgSidebar;
  final Color bgSelected;
  final Color bgHover;
  final Color bgInput;
  final Color borderDefault;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accentDefault;
  final Color accentOn;
  final Color tagAmber;
  final Color tagPlum;
  final Color statusDanger;
  final Color statusDangerBg;
  final Color statusSuccess;

  static const AxoColors light = AxoColors(
    bgEditor: Color(0xFFFFFDF8),
    bgApp: Color(0xFFF6F2EA),
    bgSidebar: Color(0xFFEDE7DC),
    bgSelected: Color(0xFFDCE7F5),
    bgHover: Color(0xFFE6DFD3),
    bgInput: Color(0xFFEAE4D9),
    borderDefault: Color(0xFFE2DACD),
    textPrimary: Color(0xFF1F1D1A),
    textSecondary: Color(0xFF57514A),
    textTertiary: Color(0xFF675F55),
    accentDefault: Color(0xFF2A5DB0),
    accentOn: Color(0xFFFFFFFF),
    tagAmber: Color(0xFF8A590C),
    tagPlum: Color(0xFF7B4B8A),
    statusDanger: Color(0xFFB3382C),
    statusDangerBg: Color(0xFFF8E3E0),
    statusSuccess: Color(0xFF2F7D5C),
  );

  static const AxoColors dark = AxoColors(
    bgEditor: Color(0xFF262522),
    bgApp: Color(0xFF1B1A18),
    bgSidebar: Color(0xFF222120),
    bgSelected: Color(0xFF26364D),
    bgHover: Color(0xFF2E2C29),
    bgInput: Color(0xFF2A2826),
    borderDefault: Color(0xFF3A3733),
    textPrimary: Color(0xFFF1EDE6),
    textSecondary: Color(0xFFBAB3A8),
    textTertiary: Color(0xFFA09990),
    accentDefault: Color(0xFF7BA7E6),
    accentOn: Color(0xFF0F1E36),
    tagAmber: Color(0xFFE3B062),
    tagPlum: Color(0xFFC49AD3),
    statusDanger: Color(0xFFE88A7E),
    statusDangerBg: Color(0xFF3B2421),
    statusSuccess: Color(0xFF6CC79C),
  );

  @override
  AxoColors copyWith({
    Color? bgEditor,
    Color? bgApp,
    Color? bgSidebar,
    Color? bgSelected,
    Color? bgHover,
    Color? bgInput,
    Color? borderDefault,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accentDefault,
    Color? accentOn,
    Color? tagAmber,
    Color? tagPlum,
    Color? statusDanger,
    Color? statusDangerBg,
    Color? statusSuccess,
  }) {
    return AxoColors(
      bgEditor: bgEditor ?? this.bgEditor,
      bgApp: bgApp ?? this.bgApp,
      bgSidebar: bgSidebar ?? this.bgSidebar,
      bgSelected: bgSelected ?? this.bgSelected,
      bgHover: bgHover ?? this.bgHover,
      bgInput: bgInput ?? this.bgInput,
      borderDefault: borderDefault ?? this.borderDefault,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accentDefault: accentDefault ?? this.accentDefault,
      accentOn: accentOn ?? this.accentOn,
      tagAmber: tagAmber ?? this.tagAmber,
      tagPlum: tagPlum ?? this.tagPlum,
      statusDanger: statusDanger ?? this.statusDanger,
      statusDangerBg: statusDangerBg ?? this.statusDangerBg,
      statusSuccess: statusSuccess ?? this.statusSuccess,
    );
  }

  @override
  AxoColors lerp(AxoColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AxoColors(
      bgEditor: c(bgEditor, other.bgEditor),
      bgApp: c(bgApp, other.bgApp),
      bgSidebar: c(bgSidebar, other.bgSidebar),
      bgSelected: c(bgSelected, other.bgSelected),
      bgHover: c(bgHover, other.bgHover),
      bgInput: c(bgInput, other.bgInput),
      borderDefault: c(borderDefault, other.borderDefault),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      accentDefault: c(accentDefault, other.accentDefault),
      accentOn: c(accentOn, other.accentOn),
      tagAmber: c(tagAmber, other.tagAmber),
      tagPlum: c(tagPlum, other.tagPlum),
      statusDanger: c(statusDanger, other.statusDanger),
      statusDangerBg: c(statusDangerBg, other.statusDangerBg),
      statusSuccess: c(statusSuccess, other.statusSuccess),
    );
  }
}

/// Escala tipográfica (Inter). Los tamaños son punto/interlínea del diseño.
abstract final class AxoType {
  static const String family = 'Inter';

  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
  );
  static const TextStyle heading = TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
  );
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
  );
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );
}

/// Radios del diseño.
abstract final class AxoRadii {
  static const double sm = 8;
  static const double lg = 12;
  static const double xl = 14;
  static const double xxl = 20;
  static const double sheet = 24;
}

/// Escala de espaciado (múltiplos de 4).
abstract final class AxoSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Medidas de los componentes base (px), del diseño.
abstract final class AxoSizes {
  static const double buttonSm = 36;
  static const double button = 46;
  static const double buttonLg = 54;
  static const double input = 52;
  static const double switchWidth = 44;
  static const double switchHeight = 26;
  static const double checkbox = 20;
  static const double otpWidth = 48;
  static const double otpHeight = 60;
  static const double noteCard = 80;
  static const double menuItem = 38;
  static const double toast = 380;
  static const double tapTarget = 44;
}
