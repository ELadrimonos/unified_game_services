import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'auth_strategy.dart';

/// A token obtained from a platform-native sign-in (e.g. Android Play
/// Services / Credential Manager).
class NativeToken {
  /// The OAuth 2.0 access token authorized for the requested scopes.
  final String accessToken;

  /// When the token expires, if the platform reports it.
  final DateTime? expiry;

  /// A refresh token, if the platform brokered one (usually it does not — it
  /// re-issues access tokens silently instead).
  final String? refreshToken;

  const NativeToken({
    required this.accessToken,
    this.expiry,
    this.refreshToken,
  });
}

/// Implemented by the **host** (game engine / app) to broker an OAuth token
/// from the platform's native account system.
///
/// This package deliberately contains **no** native or JNI code: on Android the
/// host performs the silent sign-in (e.g. via `GamesSignInClient` /
/// `CredentialManager` through `package:jni`) and returns the token here. The
/// REST data plane then proceeds unchanged with that token.
abstract interface class NativeTokenProvider {
  /// Returns a token authorized for [scopes], signing the player in silently
  /// when possible. Should throw a [GameServiceException]
  /// ([SignInFailedException] / [NotSignedInException]) when no token can be
  /// produced.
  Future<NativeToken> requestToken({required List<String> scopes});
}

/// [AuthStrategy] backed by a host-supplied [NativeTokenProvider].
///
/// On expiry or a `401` it simply re-asks the native provider for a fresh
/// token; there is no Google token-endpoint refresh because the platform owns
/// renewal.
class NativeSilentTokenStrategy implements AuthStrategy {
  NativeSilentTokenStrategy(
    this._native, {
    this.scopes = const ['https://www.googleapis.com/auth/games'],
  });

  final NativeTokenProvider _native;

  /// Scopes requested from the native provider.
  final List<String> scopes;

  NativeToken? _token;

  @override
  bool get isAuthenticated => _token != null;

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    final current = _token;
    final expired =
        current?.expiry != null &&
        DateTime.now().isAfter(
          current!.expiry!.subtract(const Duration(seconds: 60)),
        );
    if (!forceRefresh && current != null && !expired) {
      return current.accessToken;
    }
    final fresh = await _native.requestToken(scopes: scopes);
    _token = fresh;
    return fresh.accessToken;
  }

  @override
  Future<void> signOut() async {
    _token = null;
  }
}
