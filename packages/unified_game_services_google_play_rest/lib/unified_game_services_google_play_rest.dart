/// Google Play Games provider for `unified_game_services`, backed by the REST
/// Games API v1 (pure Dart, no Flutter).
///
/// [GooglePlayGamesProvider] advertises achievements and leaderboards and runs
/// on every Dart platform, including web. Sign-in is pluggable through an
/// [AuthStrategy]: [LoopbackOAuthStrategy] (desktop and CLI),
/// [StoredCredentialStrategy] (servers and brokered tokens) and
/// [NativeSilentTokenStrategy] (a token brokered by an Android host).
///
/// Use `unified_game_services_google_play_android` for native Play Games UI
/// on Android, or `unified_game_services_google_play` to pick between the two
/// automatically.
///
/// @docImport 'src/auth/auth_strategy.dart';
/// @docImport 'src/auth/loopback_oauth_strategy.dart';
/// @docImport 'src/auth/native_silent_token_strategy.dart';
/// @docImport 'src/auth/stored_credential_strategy.dart';
/// @docImport 'src/google_play_games_provider.dart';
library;

export 'src/auth/auth_strategy.dart';
export 'src/auth/loopback_oauth_strategy.dart';
export 'src/auth/native_silent_token_strategy.dart';
export 'src/auth/pkce.dart';
export 'src/auth/stored_credential_strategy.dart';
export 'src/auth/token_refresher.dart' show TokenResponse;
export 'src/games_rest_client.dart';
export 'src/google_play_games_provider.dart';
