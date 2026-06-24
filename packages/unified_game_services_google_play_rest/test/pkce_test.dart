import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:unified_game_services_google_play_rest/unified_game_services_google_play_rest.dart';

void main() {
  group('PkcePair', () {
    test('challenge is the base64url-unpadded SHA-256 of the verifier', () {
      final pair = PkcePair.generate();
      final expected = base64Url
          .encode(sha256.convert(ascii.encode(pair.verifier)).bytes)
          .replaceAll('=', '');
      expect(pair.challenge, expected);
      expect(pair.challenge, isNot(contains('=')));
      expect(PkcePair.method, 'S256');
    });

    test('verifier length is within the RFC 7636 43–128 range', () {
      final pair = PkcePair.generate();
      expect(pair.verifier.length, inInclusiveRange(43, 128));
    });

    test('matches the RFC 7636 Appendix B test vector', () {
      // The RFC fixes the challenge for this exact verifier.
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      final challenge = base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');
      expect(challenge, 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    });
  });
}
