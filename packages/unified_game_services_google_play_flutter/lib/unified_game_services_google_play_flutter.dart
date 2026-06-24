/// Flutter adapter for the `unified_game_services` Google Play Games family.
///
/// The provider packages are pure Dart and need the host to supply the Android
/// `Activity` jobject. This adapter is the **only** package in the family that
/// depends on Flutter: it resolves that activity from the running Flutter engine
/// (via `jni_flutter`) so app developers get plug-and-play registration without
/// touching `jni_flutter` / `PlatformDispatcher` themselves.
///
/// ```dart
/// void main() {
///   GooglePlayGamesFlutter.registerWith(
///     achievementIds: {'firstWin': 'CgkI...'},
///     leaderboardIds: {'highScores': 'CgkI...'},
///   );
///   runApp(const MyApp());
/// }
/// ```
///
/// On Android it wires the native Play Games provider; elsewhere — including
/// **web** — it falls back to the REST provider, which requires an
/// [AuthStrategy] (`auth`).
library;

import 'package:unified_game_services_google_play/unified_game_services_google_play.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

// Android activity resolution lives behind a conditional import: the native
// half pulls jni_flutter / package:jni (no web support), the web half is a
// stub — so this package compiles and runs on Flutter web (REST path).
import 'src/activity_resolver_web.dart'
    if (dart.library.io) 'src/activity_resolver_io.dart';

// Re-export the family's public API so a Flutter app needs only this import:
// the facade types, concrete providers, and REST auth strategies.
export 'package:unified_game_services_google_play/unified_game_services_google_play.dart';

/// Flutter entry point for the Google Play Games family, mirroring the core
/// [GooglePlayGames] facade so registration follows the same
/// `<Type>.registerWith(...)` idiom as every other provider — it just
/// auto-resolves the Android `Activity` so app developers never pass an
/// `activityResolver`.
abstract final class GooglePlayGamesFlutter {
  /// Builds the platform-appropriate Google Play Games provider, auto-resolving
  /// the Android `Activity` on Android.
  ///
  /// Off Android the REST provider is used and [auth] is required (an
  /// [ArgumentError] is thrown otherwise, matching [GooglePlayGames.create]).
  static UnifiedGameServicesPlatform create({
    AuthStrategy? auth,
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) {
    if (GooglePlayGames.usesNative) {
      return GooglePlayGames.create(
        activityResolver: flutterActivityResolver(),
        leaderboardIds: leaderboardIds,
        achievementIds: achievementIds,
      );
    }
    return GooglePlayGames.create(
      auth: auth,
      leaderboardIds: leaderboardIds,
      achievementIds: achievementIds,
    );
  }

  /// Creates the platform-appropriate provider and registers it as the active
  /// [UnifiedGameServicesPlatform.instance] — the plug-and-play entry point.
  static void registerWith({
    AuthStrategy? auth,
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) {
    UnifiedGameServicesPlatform.instance = create(
      auth: auth,
      leaderboardIds: leaderboardIds,
      achievementIds: achievementIds,
    );
  }
}
