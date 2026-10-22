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
/// Console (desktop clients permit the loopback redirect). Tokens are held in
/// memory only; they are not persisted across process restarts.
///
/// Not available on web: [getAccessToken] throws an [UnsupportedError] when
/// interactive sign-in is needed, because a browser cannot host the loopback
/// server. Use `StoredCredentialStrategy` there.
class LoopbackOAuthStrategy implements AuthStrategy {
  /// Creates a strategy for the OAuth client identified by [clientId].
  ///
  /// [clientSecret] is sent on token requests when the client has one (Google
  /// issues a non-confidential secret for Desktop clients). [scopes] defaults
  /// to [gamesScope]. [launchUrl] replaces [defaultLauncher] for presenting the
  /// consent URL, [httpClient] is used for token requests, and
  /// [authorizationEndpoint] overrides Google's consent endpoint. [random]
  /// seeds PKCE generation and exists for deterministic tests.
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

  /// The client id of the **Desktop app** OAuth client.
  final String clientId;

  /// Scopes to request. Defaults to [gamesScope].
  final List<String> scopes;

  /// The authorization endpoint the consent URL is built on.
  ///
  /// Defaults to Google's.
  final String authorizationEndpoint;

  final UrlLauncher _launch;
  final TokenRefresher _refresher;
  final Random? _random;

  TokenResponse? _token;

  @override
  bool get isAuthenticated => _token != null;

  /// Returns a valid access token.
  ///
  /// Reuses the cached token while it is unexpired. Otherwise renews it with
  /// the refresh token when one is held, and falls back to the interactive
  /// consent flow when there is none or Google rejects it. The interactive
  /// flow may throw [SignInFailedException] if consent is denied or the token
  /// exchange fails.
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

  /// Discards the in-memory tokens without revoking them at Google.
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
