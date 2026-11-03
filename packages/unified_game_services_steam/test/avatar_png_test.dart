import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:unified_game_services_steam/src/avatar_png.dart';

void main() {
  test('encodes RGBA pixels as a valid PNG', () {
    // 2x1: opaque red, half-transparent blue.
    final rgba = Uint8List.fromList([255, 0, 0, 255, 0, 0, 255, 128]);
    final png = encodeRgbaPng(rgba, 2, 1);
    final data = ByteData.sublistView(png);

    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    expect(String.fromCharCodes(png.sublist(12, 16)), 'IHDR');
    expect(data.getUint32(16), 2);
    expect(data.getUint32(20), 1);
    expect(png[24], 8); // bit depth
    expect(png[25], 6); // RGBA
    final idatLen = data.getUint32(33);
    expect(String.fromCharCodes(png.sublist(37, 41)), 'IDAT');
    final raw = ZLibDecoder().convert(png.sublist(41, 41 + idatLen));
    expect(raw, [0, ...rgba]);
    expect(
      String.fromCharCodes(png.sublist(png.length - 8, png.length - 4)),
      'IEND',
    );
  });

  test('rejects a buffer of the wrong size', () {
    expect(() => encodeRgbaPng(Uint8List(3), 1, 1), throwsArgumentError);
  });
}
