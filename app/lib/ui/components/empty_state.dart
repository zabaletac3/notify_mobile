import 'package:flutter/material.dart';

import '../app_icon.dart';
import '../tokens.dart';

/// Estado vacío del diseño (tableros «Android — Primera vez (vacío)», «Carpeta vacía», «Búsqueda
/// sin resultados», «Error de servidor»): ilustración circular, título 20/700, subtítulo 14/400 y un
/// botón opcional.
///
/// Dos formas de ilustración: [logo] (cuadro `accent` de 88 con radios 22 y una letra) o el icono
/// de 80 en círculo. [danger] pinta el círculo en `statusDangerBg` con el icono `statusDanger` y, si
/// se pasa [illustrationText], lo dibuja como carácter (p. ej. «!»).
class AxoEmptyState extends StatelessWidget {
  const AxoEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.illustrationText,
    this.danger = false,
    this.logo = false,
    this.footer,
  });

  final String title;
  final String subtitle;

  /// Icono Lucide de la ilustración circular (80) o del cuadro de logo (88).
  final String? icon;

  /// Carácter de la ilustración (el «A» del logo o el «!» del error).
  final String? illustrationText;
  final bool danger;
  final bool logo;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final size = logo ? 88.0 : AxoSizes.illustration;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: AxoSpacing.xxxl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: danger
                  ? c.statusDangerBg
                  : logo
                  ? c.accentDefault
                  : c.bgSelected,
              borderRadius: logo ? BorderRadius.circular(22) : null,
              shape: logo ? BoxShape.rectangle : BoxShape.circle,
            ),
            child: Center(
              child: illustrationText != null
                  ? Text(
                      illustrationText!,
                      style: TextStyle(
                        fontFamily: AxoType.family,
                        fontSize: logo ? 40 : 40,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: danger
                            ? c.statusDanger
                            : logo
                            ? c.accentOn
                            : c.textPrimary,
                      ),
                    )
                  : icon != null
                  ? AppIcon(
                      icon!,
                      size: logo ? 40 : 34,
                      color: danger
                          ? c.statusDanger
                          : logo
                          ? c.accentOn
                          : c.accentDefault,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AxoSpacing.xxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AxoSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AxoType.bodySmall.copyWith(color: c.textSecondary),
          ),
          if (footer != null) ...[
            const SizedBox(height: AxoSpacing.xxl),
            footer!,
          ],
        ],
      ),
    );
  }
}
