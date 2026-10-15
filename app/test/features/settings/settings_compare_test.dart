import 'dart:io';
import 'dart:ui' show Color;

import 'package:axonote_app/ui/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Comparación de las pantallas de Ajustes contra las capturas de Pencil recortadas al área del
/// dispositivo (`test/design_refs/crop/settings-<sección>-claro.png`).
///
/// Puerta **geométrica**: cada banda de texto del tablero debe tener una banda en el golden a
/// ≤ [_tolerancePx] px en vertical (alineando por la barra superior), y los colores clave (fondo de
/// la página `bgEditor` y tarjeta `bgApp`) deben coincidir con los tokens. Los tableros de Ajustes
/// solo existen en claro; el modo oscuro se cubre con goldens (sin tablero).
const int _tolerancePx = 4;

/// Tramos de la captura que quedan fuera de la puerta de bandas, por sección (en coordenadas de la
/// captura), con su motivo:
/// - `cuenta`: la tarjeta de perfil; el avatar azul se difumina en la captura (rasterizado) y su
///   banda empieza más abajo que en el render nítido.
/// - `eliminar-cuenta`: la confirmación y los botones; el tablero pide escribir "ELIMINAR" y la app
///   pide la **contraseña** (contrato `POST /me/delete`, prueba `authKey`), así que el contenido —no
///   la maquetación— difiere.
const Map<String, List<(int, int)>> _ignore = {
  'cuenta': [(100, 205)],
  'eliminar-cuenta': [(240, 470)],
  // La app añade «Clave de recuperación» al grupo «Datos» (lo pide el plan/web): el tablero no la
  // trae, así que el grupo «Datos» y el «Cuenta» de debajo quedan fuera de la puerta de bandas.
  'privacidad': [(210, 860)],
};

/// Nombre del golden y de la captura por sección.
const List<String> _sections = [
  'general',
  'cuenta',
  'sync',
  'privacidad',
  'almacenamiento',
  'eliminar-cuenta',
  'acerca',
];

/// Fila (y) del borde superior de la primera tarjeta y su color, por sección: las tarjetas del
/// diseño llevan un trazo de 1 px (`borderDefault`), y la de peligro `statusDanger`. Comprueba que
/// el trazo se dibuja (no solo el relleno).
final Map<String, (int, Color)> _cardBorder = {
  'general': (120, AxoColors.light.borderDefault),
  'cuenta': (99, AxoColors.light.borderDefault),
  'sync': (211, AxoColors.light.borderDefault),
  'privacidad': (120, AxoColors.light.borderDefault),
  'almacenamiento': (99, AxoColors.light.borderDefault),
  'eliminar-cuenta': (99, AxoColors.light.statusDanger),
  'acerca': (266, AxoColors.light.borderDefault),
};

void main() {
  for (final section in _sections) {
    late img.Image golden;
    late img.Image reference;

    setUp(() {
      golden = _load(
        'test/features/settings/goldens/settings-$section-claro.png',
      );
      reference = _load('test/design_refs/crop/settings-$section-claro.png');
    });

    test('$section · colores clave', () {
      // Fondo de la página en una zona vacía (debajo del contenido).
      expect(_px(golden, 400, 820), AxoColors.light.bgEditor, reason: 'fondo');
    });

    test('$section · borde de la primera tarjeta', () {
      final (y, expected) = _cardBorder[section]!;
      var found = false;
      for (var dy = -3; dy <= 3 && !found; dy++) {
        if (_px(golden, 200, y + dy) == expected) found = true;
      }
      expect(found, isTrue, reason: 'trazo de tarjeta en y≈$y');
    });

    if (section == 'cuenta') {
      test('$section · avatar (círculo claro con iniciales en acento)', () {
        expect(_px(golden, 44, 127), AxoColors.light.bgSelected);
        var accent = 0;
        for (var y = 99; y < 155; y++) {
          for (var x = 16; x < 72; x++) {
            if (_px(golden, x, y) == AxoColors.light.accentDefault) accent++;
          }
        }
        expect(accent, greaterThan(40), reason: 'iniciales en acento');
      });
    }

    test('$section · geometría vs Pencil (≤ $_tolerancePx px por banda)', () {
      final goldenBands = _bands(
        golden,
        backgroundLuminance: _luminance(AxoColors.light.bgEditor),
      );
      final referenceBands = _bands(
        reference,
        backgroundLuminance: _luminance(AxoColors.light.bgEditor),
      );
      expect(
        referenceBands.length,
        greaterThan(3),
        reason: 'bandas del tablero',
      );
      expect(goldenBands, isNotEmpty, reason: 'bandas del golden');

      // Offset por la barra de estado y el borde superior de la captura (la app los deja a
      // Android): se alinea por la primera banda por debajo de la barra de estado (la barra
      // superior).
      const statusBarBottom = 25;
      final goldenTop = goldenBands.firstWhere((b) => b > statusBarBottom);
      final refTop = referenceBands.firstWhere((b) => b > statusBarBottom);
      final offset = refTop - goldenTop;

      final outOfRange = <String>[];
      final ignore = _ignore[section] ?? const [];
      for (final band in referenceBands) {
        if (band <= statusBarBottom || band > 860) {
          continue; // estado/borde y gestos
        }
        if (ignore.any((r) => band >= r.$1 && band <= r.$2)) {
          continue;
        }
        final target = band - offset;
        final nearest = goldenBands.reduce(
          (a, b) => (a - target).abs() <= (b - target).abs() ? a : b,
        );
        final delta = nearest - target;
        if (delta.abs() > _tolerancePx) {
          outOfRange.add('tablero $band → golden $nearest ($delta)');
        }
      }
      expect(outOfRange, isEmpty, reason: 'bandas fuera de ±$_tolerancePx px');
    });
  }
}

Color _px(img.Image image, int x, int y) {
  final p = image.getPixel(x, y);
  return Color.fromARGB(255, p.r.toInt(), p.g.toInt(), p.b.toInt());
}

/// Inicios de las bandas de texto (filas con tinta), fusionando separaciones ≤3 px. La «tinta» es
/// todo píxel cuya luminancia se aleja de la del fondo.
List<int> _bands(img.Image image, {required int backgroundLuminance}) {
  final starts = <int>[];
  final ends = <int>[];
  var inBand = false;
  for (var y = 0; y < image.height; y++) {
    var ink = 0;
    for (var x = 20; x < 392; x++) {
      final p = image.getPixel(x, y);
      final lum = ((p.r + p.g + p.b) / 3).round();
      if ((lum - backgroundLuminance).abs() > 80) ink++;
    }
    if (!inBand && ink > 2) {
      starts.add(y);
      inBand = true;
    } else if (inBand && ink <= 2) {
      ends.add(y - 1);
      inBand = false;
    }
  }
  final merged = <int>[];
  for (var i = 0; i < starts.length; i++) {
    if (merged.isNotEmpty && starts[i] - ends[i - 1] <= 3) continue;
    merged.add(starts[i]);
  }
  return merged;
}

int _luminance(Color color) =>
    ((color.r * 255 + color.g * 255 + color.b * 255) / 3).round();

img.Image _load(String path) {
  final bytes = File(path).readAsBytesSync();
  final decoded = img.decodePng(bytes);
  if (decoded == null) throw StateError('No se pudo decodificar $path');
  return decoded;
}
