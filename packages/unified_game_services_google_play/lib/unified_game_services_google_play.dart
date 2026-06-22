/// Auto-selecting Google Play Games provider for `unified_game_services`:
/// native Play Games SDK on Android, REST elsewhere. Pure Dart, no Flutter.
///
/// See [GooglePlayGames]. Concrete provider types and auth strategies are
/// re-exported so `getInstance<GooglePlayGamesProvider>()` /
/// `getInstance<GooglePlayAndroidProvider>()` and the REST auth strategies stay
/// reachable.
library;

export 'package:unified_game_services_google_play_android/unified_game_services_google_play_android.dart';
export 'package:unified_game_services_google_play_rest/unified_game_services_google_play_rest.dart';

export 'src/google_play_games.dart';
