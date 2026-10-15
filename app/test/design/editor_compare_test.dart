import 'dart:io';
import 'dart:ui' show Color;

import 'package:axonote_app/ui/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Comparación del estado «Normal» del editor contra la captura de Pencil recortada al área del
/// dispositivo (`test/design_refs/crop/`), en claro y oscuro.
///
/// Puerta **geométrica**: cada banda de texto del tablero debe tener una banda en el golden a
/// ≤ [_tolerancePx] px en vertical (alineando por la barra superior), y los colores clave (fondo del
/// editor y resguardo de tarea marcada) deben coincidir con los tokens.
///
/// El **% de píxeles distintos** se mide y se imprime como referencia, pero **no** es la puerta: el
/// export de Pencil (2×→1× con LANCZOS) y un render nítido a 1× tienen rasterizados distintos (el
/// tablero trae ~2× los píxeles de tinta), así que un umbral de píxeles «pequeño» es inalcanzable
/// por construcción. Ver `docs/design/fase10-comparacion.md`.
const int _tolerancePx = 4;
const int _statusBarSkip = 21; // alineación por la banda de la barra superior
const int _edgeMarginPx = 6;

void main() {
  for (final (mode, colors) in [
    ('claro', AxoColors.light),
    ('oscuro', AxoColors.dark),
  ]) {
    late img.Image golden;
    late img.Image reference;

    setUp(() {
      golden = _load('test/design/goldens/editor-normal-$mode.png');
      reference = _load('test/design_refs/crop/editor-normal-$mode.png');
    });

    test('$mode · colores clave', () {
      // Fondo del editor en una zona vacía (debajo de las etiquetas).
      expect(_px(golden, 400, 700), colors.bgEditor, reason: 'fondo');

      // Resguardo de las tareas marcadas: debe haber píxeles `bg/selected` en la zona de tareas.
      var highlight = 0;
      for (var y = 380; y < 620; y++) {
        for (var x = 24; x < 388; x++) {
          if (_px(golden, x, y) == colors.bgSelected) highlight++;
        }
      }
      expect(highlight, greaterThan(50), reason: 'resguardo de tarea marcada');
    });

    test('$mode · geometría vs Pencil (≤ $_tolerancePx px por banda)', () {
      final goldenBands = _bands(
        golden,
        backgroundLuminance: _luminance(colors.bgEditor),
      );
      final referenceBands = _bands(
        reference,
        backgroundLuminance: _luminance(colors.bgEditor),
      );
      expect(
        referenceBands.length,
        greaterThan(3),
        reason: 'bandas del tablero',
      );

      // Offset por la barra superior (la captura trae la barra de estado como primera banda).
      final offset = referenceBands[1] - goldenBands[0];

      final outOfRange = <String>[];
      for (final band in referenceBands.skip(1)) {
        if (band > 800) {
          continue; // la barra de formato va pegada abajo: fuera de la puerta
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

    test('$mode · % de píxeles distintos (medida, no puerta)', () {
      var different = 0;
      var total = 0;
      for (var y = 0; y < golden.height - _statusBarSkip - 24; y++) {
        for (var x = _edgeMarginPx; x < golden.width - _edgeMarginPx; x++) {
          total++;
          final a = golden.getPixel(x, y);
          final b = reference.getPixel(x, y + _statusBarSkip);
          if ((a.r - b.r).abs() > 24 ||
              (a.g - b.g).abs() > 24 ||
              (a.b - b.b).abs() > 24) {
            different++;
          }
        }
      }
      final percent = 100 * different / total;
      // ignore: avoid_print
      print(
        'comparación $mode: ${percent.toStringAsFixed(2)}% de píxeles distintos',
      );
    });
  }
}

Color _px(img.Image image, int x, int y) {
  final p = image.getPixel(x, y);
  return Color.fromARGB(255, p.r.toInt(), p.g.toInt(), p.b.toInt());
}

/// Inicios de las bandas de texto (filas con tinta), fusionando separaciones ≤3 px. La «tinta» es
/// todo píxel cuya luminancia se aleja de la del fondo (sirve en claro y en oscuro).
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
  // Fusiona bandas muy juntas (la detección parte una línea por el hueco entre x-height y colas).
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
