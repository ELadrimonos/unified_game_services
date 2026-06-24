/// Auto-selecting Google Play Games provider for `unified_game_services`:
/// native Play Games SDK on Android, REST elsewhere (incl. **web**). Pure Dart,
/// no Flutter.
///
/// See [GooglePlayGames]. Concrete provider types and auth strategies are
/// re-exported so `getInstance<GooglePlayGamesProvider>()` /
/// `getInstance<GooglePlayAndroidProvider>()` and the REST auth strategies stay
/// reachable. The native `GooglePlayAndroidProvider` export is
/// `dart.library.io`-gated — it depends on `package:jni` (FFI, no web), so on
/// web only the REST API surface is exported.
library;

export 'package:unified_game_services_google_play_rest/unified_game_services_google_play_rest.dart';

// Native provider re-export, excluded from the web build (package:jni has no
// web support).
export 'src/native_export_web.dart'
    if (dart.library.io) 'src/native_export_io.dart';
export 'src/google_play_games.dart';
