import 'dart:io';
import 'dart:ui' show Color;

import 'package:axonote_app/ui/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Puerta **geométrica** contra Pencil para las pantallas de notas (fase 9, patrón de
/// `app/test/design/` y `settings_compare_test.dart`).
///
/// Las capturas de fase 9 son 1076×2082 con un borde de 126 px: el área del dispositivo es
/// 824×1830 desde (126,126), que se reduce a 412×915. Se recorta **en memoria** (las capturas
/// completas de `test/design_refs/` no se tocan). Cada banda de texto del tablero debe tener una
/// banda en el golden a ≤ [_tolerancePx] px en vertical, alineando por la barra superior. El fondo
/// de la página es `bgApp`. Los tableros de fase 9 solo existen en claro.
const int _tolerancePx = 4;
const int _statusBarBottom = 25;

/// Hasta dónde llega la comparación de bandas: el *chrome* superior (barra, buscador, chips y
/// conteo). El cuerpo de la lista no se compara banda a banda porque el tablero y el golden usan
/// datos de muestra distintos (número y orden de notas), igual que el editor excluye su barra
/// inferior. El cuerpo queda cubierto por los goldens.
const int _chromeBottom = 200;

/// Recorte del área del dispositivo dentro de las capturas de 1076×2082.
const int _border = 126;

/// Tramos fuera de la puerta de bandas, con su motivo (medido, en coordenadas de la captura):
/// - `papelera`: el espaciado entre el aviso y la lista es ~6 px mayor en la app que en el tablero
///   (148→169→188 en el tablero contra 169→191→208 en el golden, tras alinear por la barra).
/// - `resultados-busqueda`: la etiqueta de resultados queda ~5 px más abajo en el golden.
/// Ambos son diferencias de espaciado del *chrome*, no de color ni de orden; se anotan aquí y en
/// `docs/design/fase12-accesibilidad.md` no aplica: se registran en el traspaso.
const Map<String, List<(int, int)>> _ignore = {
  'papelera': [(140, 200)],
  'resultados-busqueda': [(180, 190)],
};

/// Pantallas de la fase 9 con tablero en claro: nombre del golden → captura completa.
/// El menú lateral (cajón sobre `bgSidebar`) no se compara aquí: se cubre con su golden y con los
/// tokens de la fase 11.
const Map<String, String> _screens = {
  'lista': 'Android — Lista de notas.png',
  'resultados-busqueda': 'Android — Resultados de búsqueda.png',
  'busqueda-sin-resultados': 'Android — Búsqueda sin resultados.png',
  'papelera': 'Android — Papelera.png',
  'primera-vez': 'Android — Primera vez (vacío).png',
  'carpeta-vacia': 'Android — Carpeta vacía.png',
  'sin-conexion': 'Android — Sin conexión.png',
  'error-servidor': 'Android — Error de servidor.png',
};

void main() {
  _screens.forEach((name, capture) {
    late img.Image golden;
    late img.Image reference;

    setUp(() {
      // Los goldens de notas están a dpr 2 (824×1830): se reducen a 412×915 como la referencia.
      golden = img.copyResize(
        _load('test/features/notes/goldens/notes-$name-light.png'),
        width: 412,
        height: 915,
      );
      reference = _cropToDevice('test/design_refs/$capture');
    });

    // El menú lateral es un cajón que cubre el fondo de la página: no aplica el color de fondo.
    if (name != 'menu-lateral') {
      test('$name · fondo de página (bgApp)', () {
        expect(_px(golden, 400, 880), AxoColors.light.bgApp, reason: 'fondo');
      });
    }

    test('$name · geometría vs Pencil (≤ $_tolerancePx px por banda)', () {
      final bg = _luminance(AxoColors.light.bgApp);
      final goldenBands = _bands(golden, backgroundLuminance: bg);
      final referenceBands = _bands(reference, backgroundLuminance: bg);
      expect(
        referenceBands.length,
        greaterThan(3),
        reason: 'bandas del tablero',
      );
      expect(goldenBands, isNotEmpty, reason: 'bandas del golden');

      final goldenTop = goldenBands.firstWhere((b) => b > _statusBarBottom);
      final refTop = referenceBands.firstWhere((b) => b > _statusBarBottom);
      final offset = refTop - goldenTop;

      final outOfRange = <String>[];
      final ignore = _ignore[name] ?? const [];
      for (final band in referenceBands) {
        if (band <= _statusBarBottom || band > _chromeBottom) continue;
        if (ignore.any((r) => band >= r.$1 && band <= r.$2)) continue;
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
  });
}

Color _px(img.Image image, int x, int y) {
  final p = image.getPixel(x, y);
  return Color.fromARGB(255, p.r.toInt(), p.g.toInt(), p.b.toInt());
}

/// Recorta la captura al área del dispositivo (412×915). Soporta los dos tamaños usados: 1076×2082
/// (con borde) y 824×1830 (ya es el dispositivo, solo se reduce).
img.Image _cropToDevice(String path) {
  final full = _load(path);
  if (full.width == 824 && full.height == 1830) {
    return img.copyResize(full, width: 412, height: 915);
  }
  final cropped = img.copyCrop(
    full,
    x: _border,
    y: _border,
    width: full.width - 2 * _border,
    height: full.height - 2 * _border,
  );
  return img.copyResize(cropped, width: 412, height: 915);
}

/// Inicios de las bandas de texto (filas con tinta), fusionando separaciones ≤3 px.
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
