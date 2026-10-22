import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'auth_strategy.dart';
import 'token_refresher.dart';

/// Non-interactive [AuthStrategy] for servers, CLIs, and hosts that already
/// hold credentials.
///
/// Use it when a token was obtained elsewhere:
/// - **refresh-token-driven**: pass a `refreshToken` with the OAuth client id
///   and secret; the strategy mints and renews access tokens against Google's
///   token endpoint.
/// - **access-token-only (brokered)**: pass just an `accessToken` (and
///   optionally its `expiry`). With no refresh token there is nothing to
///   renew, so a token rejected with a `401` surfaces as
///   [NotSignedInException] for the host to re-broker.
///
/// Works on every platform, including web.
class StoredCredentialStrategy implements AuthStrategy {
  /// Creates a strategy from credentials the host already holds.
  ///
  /// At least one of [accessToken] and [refreshToken] is required (checked by
  /// an assertion). A missing [expiry] is treated as already expired, so a
  /// refresh token, when present, is used before the first request. The
  /// [clientId] and [clientSecret] must belong to the OAuth client that issued
  /// the refresh token. [httpClient] is used for token requests.
  StoredCredentialStrategy({
    String? accessToken,
    DateTime? expiry,
    this.refreshToken,
    String clientId = '',
    String? clientSecret,
    http.Client? httpClient,
  }) : assert(
         accessToken != null || refreshToken != null,
         'Provide at least an accessToken or a refreshToken.',
       ),
       _refresher = TokenRefresher(
         clientId: clientId,
         clientSecret: clientSecret,
         httpClient: httpClient,
       ),
       _token = accessToken == null
           ? null
           : TokenResponse(
               accessToken: accessToken,
               refreshToken: refreshToken,
               // Unknown expiry → treat as already expired so the first use
               // refreshes (if possible) rather than sending a stale token.
               expiry: expiry ?? DateTime.fromMillisecondsSinceEpoch(0),
             );

  /// A long-lived refresh token, if the host has one.
  final String? refreshToken;

  final TokenRefresher _refresher;
  TokenResponse? _token;

  @override
  bool get isAuthenticated => _token != null || refreshToken != null;

  /// Returns a valid access token.
  ///
  /// Renews it from the refresh token when the held token is expired or
  /// [forceRefresh] is `true`, throwing [SignInFailedException] if Google
  /// rejects the refresh. Without a refresh token, an access token of unknown
  /// or elapsed expiry is returned as is, and [NotSignedInException] is thrown
  /// only when [forceRefresh] is `true` or no token is held.
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    final current = _token;
    if (!forceRefresh && current != null && !current.isExpired()) {
      return current.accessToken;
    }
    final token = refreshToken ?? current?.refreshToken;
    if (token != null) {
      final refreshed = await _refresher.refresh(token);
      _token = TokenResponse(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken ?? token,
        expiry: refreshed.expiry,
      );
      return _token!.accessToken;
    }
    if (current != null && !forceRefresh) {
      // Brokered access token with no refresh token and unknown expiry: hand it
      // over and let the REST client surface a 401 if it is stale.
      return current.accessToken;
    }
    throw const NotSignedInException(
      'No valid access token and no refresh token to renew it.',
    );
  }

  /// Discards the cached access token.
  ///
  /// [refreshToken] is final, so the strategy can still mint a new token
  /// afterwards.
  @override
  Future<void> signOut() async {
    _token = null;
  }
}
