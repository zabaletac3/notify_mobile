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

/// Escala tipográfica (Inter), con los roles que usa Penpot. Conviven tamaños/interlineados distintos por
/// contexto (título de auth 28/34; título de pantalla 24 o 22; cuerpo de lectura 15/22 y texto de interfaz
/// 15/1.2). Ver la tabla «rol → … → usos» en `docs/design/penpot-measurements.md`.
abstract final class AxoType {
  static const String family = 'Inter';

  /// Título de autenticación (p. ej. «Verifica tu correo»). 28/700, int. 34/28, ls 0 (medido en
  /// el tablero).
  static const TextStyle title = TextStyle(
    fontFamily: family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
  );

  /// Marca en la bienvenida («Apunte»/«AxoNote»). 34/700, int. 1.2, ls 0.
  static const TextStyle brand = TextStyle(
    fontFamily: family,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Etiqueta de botón. 16/600, ls 0 (medido en los tableros).
  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Texto de lectura grande (eslogan de la bienvenida). 16/400, int. 1.5.
  static const TextStyle bodyReading = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Texto de apoyo (subtítulos de auth, cuerpo de estados). 14/400, int. 1.5.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Etiqueta de casilla / términos. 13/400, int. 1.2 (medido en el tablero).
  static const TextStyle bodyLabel = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  /// Título de pantalla (p. ej. «Crea tu cuenta»). 24/700, int. 1.2.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: family,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Título superior de la lista / selector de carpeta. 22/700, ls -0.44.
  static const TextStyle topTitle = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.44,
  );

  /// Título de diálogo. 20/700.
  static const TextStyle dialogTitle = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Título de hoja inferior. 17/600.
  static const TextStyle sheetTitle = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Encabezado de sección. 18/600.
  static const TextStyle heading = TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Título de nota en la lista. 14/600.
  static const TextStyle noteTitle = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Cuerpo de lectura (texto largo). 15/400, int. 22.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
  );

  /// Texto de interfaz (campos, botones, opciones). 15/400, int. 1.2.
  static const TextStyle bodyUi = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  /// Etiqueta. 13/500.
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Pie/caption. 12/400.
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  /// Texto del buscador. 16/400 (tablero «Android — Lista de notas», «Search bar»).
  static const TextStyle search = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  /// Etiqueta de chip de carpeta. 14/500 (tablero «Android — Lista de notas», «Chip»).
  static const TextStyle chip = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Chip de carpeta activo / drawer activo. 14/600 (mismo tablero).
  static const TextStyle chipActive = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Elemento del menú lateral. 14/500 (tablero «Android — Menú lateral», «SidebarItem»).
  static const TextStyle navItem = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Cabecera de grupo de la lista. 13/600 (tablero «Android — Lista de notas», «Group»).
  static const TextStyle groupHeader = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Opción de hoja inferior. 15/500 (tablero «Android — Menú contextual de nota», «Opción»).
  static const TextStyle option = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Encabezado de sección del drawer, en mayúsculas. 11/600 (tablero «Android — Menú lateral»).
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Etiqueta de 11 (carpeta en la tarjeta de nota). 11/500 (tablero «Android — Lista de notas»).
  static const TextStyle meta11 = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Fecha de la tarjeta de nota. 12/500 (tablero «Android — Lista de notas», «Date»).
  static const TextStyle meta12med = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Etiqueta de botón secundario de diálogo y del FAB. 15/600 (tableros «Confirmar eliminación»,
  /// «Modal mover nota», «FAB · Nueva nota»).
  static const TextStyle buttonSm = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Etiqueta de etiqueta (#parcial) del editor. 12/600 (tablero «Android — Editor», «Tag»).
  static const TextStyle tagLabel = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // ── Cuerpo del documento del editor (§«Movil v2» + `notify_web/src/lib/styles/prose.css`) ──

  /// Título de la nota en el editor. 28/700, int. 1.214, ls -0.56 (tablero «Android — Editor»).
  static const TextStyle editorTitle = TextStyle(
    fontFamily: family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    letterSpacing: -0.56,
  );

  /// Encabezado h1–h3 del cuerpo, en móvil. 19/700, int. 1.368, ls -0.19 (`prose.css` a ≤767px).
  static const TextStyle editorHeading = TextStyle(
    fontFamily: family,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    height: 26 / 19,
    letterSpacing: -0.19,
  );

  /// Cuerpo del documento, en móvil. 16/400, int. 1.5625 (`prose.css` a ≤767px).
  static const TextStyle editorBody = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 25 / 16,
  );

  /// Fecha del documento. 12/500 (tablero «Android — Editor»).
  static const TextStyle editorDate = meta12med;

  /// Estilo de párrafo de la barra de formato («Aa»). 14/600.
  static const TextStyle formatStyleLabel = chipActive;

  // ── Ajustes (tableros «Android — Ajustes…, Mi cuenta, …») ──

  /// Etiqueta de una fila de ajustes. 15/500.
  static const TextStyle settingsRowLabel = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Descripción de una fila de ajustes. 13/400.
  static const TextStyle settingsRowDescription = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
  );

  /// Valor de una fila de ajustes. 14/500.
  static const TextStyle settingsRowValue = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Acción de una fila de ajustes («Cambiar», «Quitar»). 14/600.
  static const TextStyle settingsRowAction = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Encabezado de sección de Ajustes, en mayúsculas. 11/600 con ls 0.66 (tableros «Android —
  /// Ajustes…»).
  static const TextStyle settingsSectionLabel = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.66,
  );
}

/// Radios del diseño (Penpot incluye el del marco del dispositivo, 28, y el de las tarjetas/buscador).
abstract final class AxoRadii {
  static const double sm = 8;
  static const double lg = 12;
  static const double xl = 14;
  static const double xxl = 20;
  static const double sheet = 24;
  static const double card = 28;

  /// Chip de carpeta y tarjeta de nota. 10 (tablero «Android — Lista de notas»).
  static const double chip = 10;

  /// FAB «Nueva nota». 18 (tablero «Android — Lista de notas», «FAB · Nueva nota»).
  static const double fab = 18;

  /// Casilla de tarea del editor: círculo. 11 sobre 22 (tablero «Android — Editor», «Checkbox»).
  static const double editorTask = 11;

  /// Cita del editor (`prose.css`: 0.625rem).
  static const double quote = 10;

  /// Código en línea (`prose.css`: 0.375rem).
  static const double inlineCode = 6;

  /// Círculo perfecto (casillas, puntos).
  static const double pill = 999;
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

/// Medidas de los componentes base (px), medidas en Penpot.
abstract final class AxoSizes {
  static const double buttonSm = 36;
  static const double button = 46;
  static const double buttonLg = 54;
  static const double input = 52;
  static const double switchWidth = 44;
  static const double switchHeight = 26;
  static const double checkbox = 20;
  static const double otpWidth = 53;
  static const double otpHeight = 60;
  static const double noteCard = 80;
  static const double menuItem = 48;
  static const double toast = 388;
  static const double tapTarget = 44;

  /// Buscador de la lista. 48 (tablero «Android — Lista de notas», «Search bar»).
  static const double searchBar = 48;

  /// Chip de carpeta. 33 (tablero «Android — Lista de notas», «Chip»).
  static const double chip = 33;

  /// Cabecera de grupo. 38 (tablero «Android — Lista de notas», «Group»).
  static const double groupHeader = 38;

  /// Elemento del menú lateral. 34 (tablero «Android — Menú lateral», «SidebarItem»).
  static const double sidebarItem = 34;

  /// Ancho del menú lateral. 304 (tablero «Android — Menú lateral», «Drawer»).
  static const double drawer = 304;

  /// Esqueleto de nota (carga). 92 (tablero «Android — Cargando (skeletons)»).
  static const double noteSkeleton = 92;

  /// Ilustración circular de los estados vacíos y de error. 80 (tableros de estado).
  static const double illustration = 80;

  /// Opción de una hoja inferior. 48 (tablero «Android — Menú contextual de nota»).
  static const double optionRow = 48;

  // ── Editor (tablero «Android — Editor») ──

  /// Casilla de tarea. 22 (círculo, «Checklist» → «Checkbox»).
  static const double editorTask = 22;

  /// Punto de viñeta. 6 (tablero «Android — Editor», «Bullets» → «Ellipse»).
  static const double editorBulletDot = 6;

  /// Marca izquierda de la cita. 3 (`prose.css`: border-left 3px).
  static const double editorQuoteBorder = 3;

  /// Botón de la barra de formato. 40×40 (tablero «Android — Editor», «ToolbarButton»).
  static const double formatBarButton = 40;

  /// Icono de la barra de formato. 18 (tablero «Android — Editor», «Icon»).
  static const double formatBarIcon = 18;

  /// Alto de la barra de formato. 52 (barra 40 + 2×6 de relleno).
  static const double formatBar = 52;

  // ── Ajustes (tableros «Android — Ajustes…») ──

  /// Fila de ajustes. 52.
  static const double settingsRow = 52;

  /// Fila de ajustes con interruptor. 54.
  static const double settingsRowSwitch = 54;

  /// Fila de ajustes solo con acción (o de peligro). 46.
  static const double settingsRowCompact = 46;

  /// Fila de ajustes con descripción. 66.
  static const double settingsRowTall = 66;

  /// Avatar del perfil en «Mi cuenta». 56.
  static const double settingsAvatar = 56;

  /// Logotipo de «Acerca de». 72.
  static const double settingsLogo = 72;

  /// Barra de uso de almacenamiento. 8.
  static const double settingsProgress = 8;
}

/// Colores del resplandor decorativo de las pantallas de autenticación (medidos en el tablero
/// «Registro»: tres elipses difuminadas). Son tokens propios porque el diseño los usa; no se
/// derivan de otros. Solo aparecen en los tableros claros.
abstract final class AxoGlow {
  /// `#2a5db0` al 20 %.
  static const Color accent = Color(0x332A5DB0);

  /// `#7b4b8a` al 14 %.
  static const Color plum = Color(0x247B4B8A);

  /// `#b7791f` al 12 %.
  static const Color amber = Color(0x1FB7791F);
}

/// Sombras del diseño. La de tarjeta es la de los tableros «Registro» e «Inicio de sesión»
/// (`#1f1a14` al 10 %, blur 64, desplazada 24 abajo, spread -8).
abstract final class AxoShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x1A1F1A14),
      blurRadius: 64,
      offset: Offset(0, 24),
      spreadRadius: -8,
    ),
  ];
}
