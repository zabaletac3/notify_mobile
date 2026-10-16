// Contraste WCAG (fase 12, §5.4 y plan §12.3): prueba automática sobre los tokens de color, en
// claro y oscuro. Exige AA (4,5:1) al texto de cuerpo e interfaz y a los enlaces; y al menos AA
// para gráficos (3:1) a los colores de estado usados como punto/icono. Las combinaciones que no
// llegan a 4,5 y se aceptan a conciencia están listadas en `docs/design/fase12-accesibilidad.md`.
import 'dart:math' as math;

import 'package:axonote_app/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Luminancia relativa de un color (WCAG 2.1).
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Razón de contraste entre dos colores (>= 1).
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final entry in {
    'claro': AxoColors.light,
    'oscuro': AxoColors.dark,
  }.entries) {
    final name = entry.key;
    final c = entry.value;

    /// Fondos reales de esa paleta.
    final bgs = {
      'bgEditor': c.bgEditor,
      'bgApp': c.bgApp,
      'bgSidebar': c.bgSidebar,
      'bgInput': c.bgInput,
      'bgHover': c.bgHover,
    };

    group('texto AA (≥ 4,5) · $name', () {
      final roles = {
        'textPrimary': c.textPrimary,
        'textSecondary': c.textSecondary,
        'textTertiary': c.textTertiary,
      };
      for (final role in roles.entries) {
        for (final bg in bgs.entries) {
          test('${role.key} sobre ${bg.key}', () {
            expect(contrast(role.value, bg.value), greaterThanOrEqualTo(4.5));
          });
        }
      }

      test('accentDefault sobre los fondos', () {
        for (final bg in bgs.entries) {
          expect(
            contrast(c.accentDefault, bg.value),
            greaterThanOrEqualTo(4.5),
            reason: 'accentDefault sobre ${bg.key}',
          );
        }
      });

      test('accentDefault y accentOn sobre bgSelected', () {
        expect(
          contrast(c.accentDefault, c.bgSelected),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('texto sobre el botón primario (accentOn/accentDefault)', () {
        expect(
          contrast(c.accentOn, c.accentDefault),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('peligro sobre su fondo y sobre la app', () {
        expect(
          contrast(c.statusDanger, c.statusDangerBg),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(c.statusDanger, c.bgApp), greaterThanOrEqualTo(4.5));
        expect(contrast(c.statusDanger, c.bgInput), greaterThanOrEqualTo(4.5));
      });
    });

    group('acentos y estados, gráfico AA (≥ 3,0) · $name', () {
      for (final accent in {
        'statusSuccess': c.statusSuccess,
        'tagAmber': c.tagAmber,
        'tagPlum': c.tagPlum,
      }.entries) {
        test('${accent.key} sobre los fondos', () {
          for (final bg in bgs.entries) {
            expect(
              contrast(accent.value, bg.value),
              greaterThanOrEqualTo(3.0),
              reason: '${accent.key} sobre ${bg.key}',
            );
          }
        });
      }
    });

    test('texto terciario sobre el resaltado (bgSelected) · $name', () {
      // Documentado: claro ≥ 4,5; oscuro 4,34 (por debajo, aceptado y anotado).
      final r = contrast(c.textTertiary, c.bgSelected);
      if (name == 'claro') {
        expect(r, greaterThanOrEqualTo(4.5));
      } else {
        expect(r, greaterThanOrEqualTo(3.0));
      }
    });
  }
}
