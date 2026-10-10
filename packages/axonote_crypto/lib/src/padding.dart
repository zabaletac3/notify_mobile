import 'dart:typed_data';

import 'bytes.dart';

/// Rellena con espacios (0x20) hasta el siguiente múltiplo de [block], para no revelar el
/// tamaño exacto.
Uint8List pad(Uint8List bytes, {int block = 256}) {
  final blocks = (bytes.length / block).ceil();
  final size = (blocks < 1 ? 1 : blocks) * block;
  final out = Uint8List(size)..fillRange(0, size, 0x20);
  out.setRange(0, bytes.length, bytes);
  return out;
}

/// Quita el relleno de un JSON (que nunca termina en espacio).
String unpadJson(Uint8List bytes) => fromUtf8(bytes).trimRight();
