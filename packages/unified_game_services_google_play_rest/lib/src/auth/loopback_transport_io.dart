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

/// Serves the first loopback request, extracts `?code=`, and replies with a
/// small "you can close this tab" page.
Future<String> _awaitRedirect(HttpServer server) async {
  await for (final request in server) {
    final params = request.uri.queryParameters;
    final code = params['code'];
    final error = params['error'];
    final response = request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html;
    if (code != null) {
      response.write(_donePage);
      await response.close();
      return code;
    }
    response.write(_donePage);
    await response.close();
    throw SignInFailedException(
      'OAuth consent did not return a code${error != null ? ' (error: $error)' : ''}.',
    );
  }
  throw const SignInFailedException('OAuth redirect server closed early.');
}

const String _donePage =
    '<!doctype html><meta charset="utf-8"><title>Signed in</title>'
    '<body style="font-family:sans-serif;text-align:center;padding-top:3rem">'
    '<h2>Signed in</h2><p>You can close this tab and return to the game.</p>';
