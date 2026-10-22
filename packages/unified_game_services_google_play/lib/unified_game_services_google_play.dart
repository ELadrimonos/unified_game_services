/// Auto-selecting Google Play Games provider for `unified_game_services`:
/// native Play Games SDK on Android, REST elsewhere (including **web**). Pure
/// Dart, no Flutter.
///
/// [GooglePlayGames.create] returns the provider for the current platform. The
/// concrete provider types and the REST auth strategies are re-exported, so
/// `GameServices.provider<GooglePlayGamesProvider>()` and
/// `GameServices.provider<GooglePlayAndroidProvider>()` stay reachable.
///
/// The native `GooglePlayAndroidProvider` export is gated on `dart.library.io`
/// because it depends on `package:jni` (FFI, no web support). On web only the
/// REST API surface is exported.
///
/// @docImport 'src/google_play_games.dart';
library;

export 'package:unified_game_services_google_play_rest/unified_game_services_google_play_rest.dart';

// Native provider re-export, excluded from the web build (package:jni has no
// web support).
export 'src/native_export_web.dart'
    if (dart.library.io) 'src/native_export_io.dart';
export 'src/google_play_games.dart';
