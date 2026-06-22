import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'auth_strategy.dart';
import 'pkce.dart';
import 'token_refresher.dart';

/// Opens [url] in the user's environment so they can grant consent.
///
/// The default ([LoopbackOAuthStrategy.defaultLauncher]) prints the URL and
/// tries the OS opener (`open`/`xdg-open`/`start`). Override it in headless or
/// embedded hosts (e.g. to surface the URL in the game UI).
typedef UrlLauncher = FutureOr<void> Function(Uri url);

/// Default OAuth scope: read/write the player's Play Games data.
const String gamesScope = 'https://www.googleapis.com/auth/games';

/// Interactive OAuth 2.0 **authorization-code + PKCE** flow with a localhost
/// loopback redirect.
///
/// Suitable for desktop and CLI: it binds an ephemeral `127.0.0.1` port, opens
/// the system browser to Google's consent screen, captures the redirect, and
/// exchanges the code for tokens. Refresh tokens are requested
/// (`access_type=offline` + `prompt=consent`) so later token renewals need no
/// browser.
///
/// Requires an OAuth client of type **Desktop app** in the Google Cloud
/// Console (desktop clients permit the loopback redirect).
class LoopbackOAuthStrategy implements AuthStrategy {
  LoopbackOAuthStrategy({
    required this.clientId,
    String? clientSecret,
    this.scopes = const [gamesScope],
    UrlLauncher? launchUrl,
    http.Client? httpClient,
    this.authorizationEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth',
    Random? random,
  }) : _launch = launchUrl ?? defaultLauncher,
       // ignore: prefer_initializing_formals
       _random = random,
       _refresher = TokenRefresher(
         clientId: clientId,
         clientSecret: clientSecret,
         httpClient: httpClient,
       );

  /// Desktop OAuth client id.
  final String clientId;

  /// Scopes to request. Defaults to [gamesScope].
  final List<String> scopes;

  /// Google's authorization endpoint.
  final String authorizationEndpoint;

  final UrlLauncher _launch;
  final TokenRefresher _refresher;
  final Random? _random;

  TokenResponse? _token;

  @override
  bool get isAuthenticated => _token != null;

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    final current = _token;
    if (!forceRefresh && current != null && !current.isExpired()) {
      return current.accessToken;
    }
    // Try a silent refresh before falling back to an interactive sign-in.
    final refreshToken = current?.refreshToken;
    if (refreshToken != null) {
      try {
        final refreshed = await _refresher.refresh(refreshToken);
        _token = TokenResponse(
          accessToken: refreshed.accessToken,
          // Google omits the refresh token on renewal; keep the old one.
          refreshToken: refreshed.refreshToken ?? refreshToken,
          expiry: refreshed.expiry,
        );
        return _token!.accessToken;
      } on SignInFailedException {
        // Refresh token revoked/expired — fall through to interactive sign-in.
      }
    }
    _token = await _authorize();
    return _token!.accessToken;
  }

  @override
  Future<void> signOut() async {
    _token = null;
  }

  /// Runs the full interactive authorization-code flow once.
  Future<TokenResponse> _authorize() async {
    final pkce = PkcePair.generate(_random);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final redirectUri = 'http://127.0.0.1:${server.port}';
      final authUrl = Uri.parse(authorizationEndpoint).replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'scope': scopes.join(' '),
          'code_challenge': pkce.challenge,
          'code_challenge_method': PkcePair.method,
          'access_type': 'offline',
          'prompt': 'consent',
        },
      );

      await _launch(authUrl);

      final code = await _awaitRedirect(server);
      return _refresher.exchangeCode(
        code: code,
        codeVerifier: pkce.verifier,
        redirectUri: redirectUri,
      );
    } finally {
      await server.close(force: true);
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

  /// The default [UrlLauncher]: print the URL and try the OS opener.
  static Future<void> defaultLauncher(Uri url) async {
    // ignore: avoid_print
    print('Open this URL to sign in:\n$url');
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

  static const String _donePage =
      '<!doctype html><meta charset="utf-8"><title>Signed in</title>'
      '<body style="font-family:sans-serif;text-align:center;padding-top:3rem">'
      '<h2>Signed in</h2><p>You can close this tab and return to the game.</p>';
}
