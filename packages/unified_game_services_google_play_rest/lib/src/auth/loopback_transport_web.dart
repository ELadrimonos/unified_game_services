import 'dart:async';

/// Web stub of the loopback OAuth transport — the **default** import, replaced
/// by `loopback_transport_io.dart` when `dart.library.io` is available.
///
/// The loopback authorization-code flow needs a localhost HTTP server, which a
/// browser can't host, so it is unavailable on the web. The rest of the package
/// (REST client + [StoredCredentialStrategy] / [NativeSilentTokenStrategy])
/// still works on web — this stub only keeps the package compilable there.
Future<({String code, String redirectUri})> captureAuthorizationCode({
  required Uri Function(String redirectUri) authUrlFor,
  required FutureOr<void> Function(Uri url) launch,
}) {
  throw UnsupportedError(
    'LoopbackOAuthStrategy needs a localhost loopback server and is not '
    'available on the web. Use StoredCredentialStrategy or '
    'NativeSilentTokenStrategy, or a redirect-based web OAuth flow that hands '
    'the package a token.',
  );
}

/// No-op on web: there is no OS process opener. The caller already prints the
/// consent URL as a fallback.
Future<void> openInBrowser(Uri url) async {}
