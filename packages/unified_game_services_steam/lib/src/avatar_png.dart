import 'dart:io' show ZLibEncoder;
import 'dart:typed_data';

/// Encodes straight (non-premultiplied) 8-bit [rgba] pixels as a PNG image.
///
/// [rgba] holds `width * height * 4` bytes, row by row from the top left.
/// Steam avatars come back from `ISteamUtils::GetImageRGBA` in exactly this
/// layout. Pure Dart apart from the zlib codec in `dart:io`.
Uint8List encodeRgbaPng(Uint8List rgba, int width, int height) {
  if (rgba.length != width * height * 4) {
    throw ArgumentError.value(
      rgba.length,
      'rgba.length',
      'expected ${width * height * 4} bytes for ${width}x$height',
    );
  }
  // Each scanline is prefixed with filter type 0 (none).
  final stride = width * 4;
  final raw = Uint8List(height * (stride + 1));
  for (var y = 0; y < height; y++) {
    final out = y * (stride + 1);
    raw[out] = 0;
    raw.setRange(out + 1, out + 1 + stride, rgba, y * stride);
  }

  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6); // colour type: RGBA

  final out = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _writeChunk(out, 'IHDR', ihdr.buffer.asUint8List());
  _writeChunk(out, 'IDAT', Uint8List.fromList(ZLibEncoder().convert(raw)));
  _writeChunk(out, 'IEND', Uint8List(0));
  return out.takeBytes();
}

void _writeChunk(BytesBuilder out, String type, Uint8List data) {
  final body = Uint8List(4 + data.length)
    ..setRange(0, 4, type.codeUnits)
    ..setRange(4, 4 + data.length, data);
  final header = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32(body));
  out
    ..add(header.buffer.asUint8List())
    ..add(body)
    ..add(crc.buffer.asUint8List());
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
}, growable: false);

int _crc32(Uint8List bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
