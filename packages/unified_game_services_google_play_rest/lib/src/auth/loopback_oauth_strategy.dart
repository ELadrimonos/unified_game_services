import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'auth_strategy.dart';
// dart:io-backed loopback transport on native; a throwing stub on web (the
// loopback flow needs a localhost server a browser can't host).
import 'loopback_transport_web.dart'
    if (dart.library.io) 'loopback_transport_io.dart';
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
  ///
  /// The loopback server + redirect capture live in the platform transport
  /// ([captureAuthorizationCode]); on web that stub throws — loopback needs a
  /// localhost server a browser can't host.
  Future<TokenResponse> _authorize() async {
    final pkce = PkcePair.generate(_random);
    final result = await captureAuthorizationCode(
      authUrlFor: (redirectUri) => Uri.parse(authorizationEndpoint).replace(
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
      ),
      launch: _launch,
    );
    return _refresher.exchangeCode(
      code: result.code,
      codeVerifier: pkce.verifier,
      redirectUri: result.redirectUri,
    );
  }

  /// The default [UrlLauncher]: print the URL and try the OS opener (a no-op on
  /// web — the printed URL is the fallback).
  static Future<void> defaultLauncher(Uri url) async {
    // ignore: avoid_print
    print('Open this URL to sign in:\n$url');
    await openInBrowser(url);
  }
}
