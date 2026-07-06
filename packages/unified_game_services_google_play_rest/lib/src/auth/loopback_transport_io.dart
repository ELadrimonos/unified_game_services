import 'dart:async';
import 'dart:io';

import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Native (`dart:io`) implementation of the loopback OAuth transport. Selected
/// via conditional import on platforms that expose `dart.library.io`.
///
/// Binds an ephemeral `127.0.0.1` server, asks [authUrlFor] to build the
/// consent URL for the bound redirect URI, runs [launch], waits for the
/// redirect and returns the captured code together with the redirect URI used.
Future<({String code, String redirectUri})> captureAuthorizationCode({
  required Uri Function(String redirectUri) authUrlFor,
  required FutureOr<void> Function(Uri url) launch,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  try {
    final redirectUri = 'http://127.0.0.1:${server.port}';
    await launch(authUrlFor(redirectUri));
    final code = await _awaitRedirect(server);
    return (code: code, redirectUri: redirectUri);
  } finally {
    await server.close(force: true);
  }
}

/// Opens [url] with the OS browser opener (`open`/`start`/`xdg-open`). Best
/// effort: failures (headless hosts) are swallowed — the printed URL is the
/// fallback.
Future<void> openInBrowser(Uri url) async {
  final command = Platform.isMacOS
      ? 'open'
      : Platform.isWindows
      ? 'start'
      : 'xdg-open';
  try {
    await Process.run(command, [
      url.toString(),
    ], runInShell: Platform.isWindows);
  } catch (_) {
    // No opener available (headless) — the printed URL is the fallback.
  }
}

/// Serves loopback requests until the OAuth redirect arrives, extracts
/// `?code=`, and replies with a small "you can close this tab" page.
///
/// Requests carrying neither `code` nor `error` (e.g. the browser probing
/// `/favicon.ico` before the redirect lands) get a 404 and are ignored —
/// they must not abort the sign-in.
Future<String> _awaitRedirect(HttpServer server) async {
  await for (final request in server) {
    final params = request.uri.queryParameters;
    final code = params['code'];
    final error = params['error'];
    if (code == null && error == null) {
      request.response.statusCode = 404;
      await request.response.close();
      continue;
    }
    final response = request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html;
    response.write(_donePage);
    await response.close();
    if (code != null) return code;
    throw SignInFailedException('OAuth consent denied (error: $error).');
  }
  throw const SignInFailedException('OAuth redirect server closed early.');
}

const String _donePage =
    '<!doctype html><meta charset="utf-8"><title>Signed in</title>'
    '<body style="font-family:sans-serif;text-align:center;padding-top:3rem">'
    '<h2>Signed in</h2><p>You can close this tab and return to the game.</p>';
