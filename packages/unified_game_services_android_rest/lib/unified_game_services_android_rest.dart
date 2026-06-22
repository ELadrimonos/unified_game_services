/// Google Play Games provider for `unified_game_services`, backed by the REST
/// Games API v1 (pure Dart, no Flutter).
///
/// See [GooglePlayGamesProvider] for the provider and the `auth/` strategies
/// ([LoopbackOAuthStrategy], [StoredCredentialStrategy],
/// [NativeSilentTokenStrategy]) for the pluggable sign-in mechanisms.
library;

export 'src/auth/auth_strategy.dart';
export 'src/auth/loopback_oauth_strategy.dart';
export 'src/auth/native_silent_token_strategy.dart';
export 'src/auth/pkce.dart';
export 'src/auth/stored_credential_strategy.dart';
export 'src/auth/token_refresher.dart' show TokenResponse;
export 'src/games_rest_client.dart';
export 'src/google_play_games_provider.dart';
