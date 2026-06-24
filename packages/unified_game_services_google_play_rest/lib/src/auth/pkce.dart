import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A PKCE (RFC 7636) verifier/challenge pair for an OAuth authorization-code
/// flow.
///
/// The [verifier] is a high-entropy random string kept locally; the [challenge]
/// is its SHA-256 digest, base64url-encoded without padding, sent on the
/// authorization request. Only the S256 method is produced — the deprecated
/// `plain` method is intentionally unsupported.
class PkcePair {
  /// The code verifier (sent on the token exchange).
  final String verifier;

  /// The S256 code challenge (sent on the authorization request).
  final String challenge;

  const PkcePair({required this.verifier, required this.challenge});

  /// The challenge method, always `S256`.
  static const String method = 'S256';

  /// Generates a fresh pair using [random] (defaults to [Random.secure]).
  factory PkcePair.generate([Random? random]) {
    final rng = random ?? Random.secure();
    // 32 random bytes → 43-char base64url verifier (within the 43–128 range).
    final verifierBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final verifier = _base64UrlNoPad(verifierBytes);
    final challenge = _base64UrlNoPad(
      sha256.convert(ascii.encode(verifier)).bytes,
    );
    return PkcePair(verifier: verifier, challenge: challenge);
  }

  static String _base64UrlNoPad(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}
