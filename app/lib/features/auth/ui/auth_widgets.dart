import 'package:flutter/material.dart';

import '../../../ui/app_icon.dart';
import '../../../ui/tokens.dart';

/// Logo de AxoNote: cuadrado redondeado en `accent` con la inicial. Sustituye al logotipo de
/// Penpot (el archivo se llama «Apunte», pero el producto es AxoNote; misma forma y color).
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.size = 48, this.letter = 'A'});

  final double size;
  final String letter;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accentDefault,
        // Medido en los tableros: logo de 96 radio 24 (bienvenida), de 48 radio 14 (tarjeta).
        borderRadius: BorderRadius.circular(size >= 80 ? 24 : AxoRadii.xl),
      ),
      child: Text(
        letter,
        style: AxoType.screenTitle.copyWith(
          color: c.accentOn,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Botón de volver del diseño (icono `arrow-left` en un objetivo de 44).
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Semantics(
      button: true,
      label: 'Volver',
      child: InkResponse(
        onTap: onPressed,
        radius: 24,
        child: SizedBox(
          width: AxoSizes.tapTarget,
          height: AxoSizes.tapTarget,
          child: Center(
            child: AppIcon('arrow-left', size: 24, color: c.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Enlace de texto en `accent` (el «Inicia sesión», «Volver a iniciar sesión», etc. del diseño).
class AuthLink extends StatelessWidget {
  const AuthLink({
    super.key,
    required this.text,
    this.onTap,
    this.textAlign = TextAlign.left,
    this.textStyle,
  });

  final String text;
  final VoidCallback? onTap;
  final TextAlign textAlign;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AxoRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AxoSpacing.sm),
          child: Text(
            text,
            textAlign: textAlign,
            style:
                textStyle ??
                AxoType.bodySmall.copyWith(
                  color: c.accentDefault,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

/// Fila de pie «¿Ya tienes cuenta? Inicia sesión».
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    super.key,
    required this.prompt,
    required this.action,
    this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: AxoType.bodySmall.copyWith(color: c.textSecondary)),
        const SizedBox(width: 6),
        AuthLink(text: action, onTap: onTap),
      ],
    );
  }
}

/// Icono grande en un círculo (cabeceras de verificación y estados). [background] y [foreground]
/// son tokens; por defecto, tinte de acento suave.
class AuthIconBadge extends StatelessWidget {
  const AuthIconBadge({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
    this.size = 56,
  });

  final String icon;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? c.bgSelected,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: AppIcon(
          icon,
          size: size * 0.46,
          color: foreground ?? c.accentDefault,
        ),
      ),
    );
  }
}

/// Contenido de una pantalla de autenticación: fondo `bgApp`, ancho cómodo y desplazable.
class AuthBody extends StatelessWidget {
  const AuthBody({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding:
            padding ??
            const EdgeInsets.symmetric(
              horizontal: AxoSpacing.xxl,
              vertical: AxoSpacing.lg,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Tarjeta de autenticación del diseño (tableros «Registro» e «Inicio de sesión»): 372 de ancho,
/// radio 28, fondo `bgEditor`, relleno 24. Se usa de borde a borde con 20 de margen lateral.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 372),
        child: Container(
          padding: const EdgeInsets.all(AxoSpacing.xxl),
          decoration: BoxDecoration(
            color: c.bgEditor,
            borderRadius: BorderRadius.circular(AxoRadii.card),
            boxShadow: AxoShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Resplandor decorativo del fondo de Registro e «Inicio de sesión» (tres elipses difuminadas:
/// `accent` 20 %, plum 14 % y amber 12 %). Se pinta detrás de la tarjeta, solo en modo claro (los
/// tableros oscuros no lo llevan).
class AuthGlows extends StatelessWidget {
  const AuthGlows({super.key});

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          children: [
            _glow(-49, 165, 391, AxoGlow.accent),
            _glow(239, -110, 350, AxoGlow.plum),
            _glow(144, 567, 288, AxoGlow.amber),
          ],
        ),
      ),
    );
  }

  Widget _glow(double x, double y, double size, Color color) => Positioned(
    left: x,
    top: y,
    width: size,
    height: size,
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withAlpha(0)]),
      ),
    ),
  );
}
