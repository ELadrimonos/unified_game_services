import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// A token plus the moment it stops being valid.
class TokenResponse {
  /// The OAuth 2.0 access token (the bearer value sent to the Games API).
  final String accessToken;

  /// A refresh token, when the authorization server issued one. Only present
  /// on the first consent of an offline-access flow.
  final String? refreshToken;

  /// Absolute time after which [accessToken] must be refreshed.
  final DateTime expiry;

  const TokenResponse({
    required this.accessToken,
    required this.expiry,
    this.refreshToken,
  });

  /// Whether the token is at or past [expiry] (with a small safety margin
  /// applied by the caller).
  bool isExpired({Duration leeway = const Duration(seconds: 60)}) =>
      DateTime.now().isAfter(expiry.subtract(leeway));
}

/// Talks to Google's OAuth 2.0 token endpoint to mint and refresh tokens.
///
/// Shared by every [AuthStrategy] that exchanges an authorization code or a
/// refresh token. Pure transport — it holds no token state of its own.
class TokenRefresher {
  TokenRefresher({
    required this.clientId,
    this.clientSecret,
    http.Client? httpClient,
    this.tokenEndpoint = 'https://oauth2.googleapis.com/token',
  }) : _http = httpClient ?? http.Client();

  /// OAuth 2.0 client id (a "Desktop app" client for the loopback flow).
  final String clientId;

  /// Client secret, if the client type requires one. For desktop clients this
  /// is not truly secret; PKCE protects the exchange.
  final String? clientSecret;

  /// Google's token endpoint.
  final String tokenEndpoint;

  final http.Client _http;

  /// Exchanges an authorization [code] (with its PKCE [codeVerifier] and the
  /// exact [redirectUri] used on the authorization request) for tokens.
  Future<TokenResponse> exchangeCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) {
    return _post({
      'grant_type': 'authorization_code',
      'code': code,
      'code_verifier': codeVerifier,
      'redirect_uri': redirectUri,
      'client_id': clientId,
      'client_secret': ?clientSecret,
    });
  }

  /// Mints a new access token from a long-lived [refreshToken].
  ///
  /// The response usually omits a refresh token; the caller keeps the existing
  /// one in that case.
  Future<TokenResponse> refresh(String refreshToken) {
    return _post({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': clientId,
      'client_secret': ?clientSecret,
    });
  }

  Future<TokenResponse> _post(Map<String, String> body) async {
    final http.Response res;
    try {
      res = await _http.post(Uri.parse(tokenEndpoint), body: body);
    } catch (e) {
      throw NetworkException('OAuth token request failed.', e);
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw PlatformOperationException(
        'OAuth token endpoint returned a non-JSON body (HTTP ${res.statusCode}).',
        code: '${res.statusCode}',
      );
    }
    if (res.statusCode != 200) {
      // Google reports OAuth failures as {error, error_description}.
      final err = json['error_description'] ?? json['error'] ?? 'unknown_error';
      throw SignInFailedException('OAuth token request rejected: $err');
    }
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    return TokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiry: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  /// Closes the underlying HTTP client.
  void close() => _http.close();
}
