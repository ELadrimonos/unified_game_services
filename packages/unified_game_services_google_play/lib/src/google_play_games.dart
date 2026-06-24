import 'package:unified_game_services_google_play_rest/unified_game_services_google_play_rest.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

// Native (Android, package:jni) vs web/REST halves are swapped at compile time
// so package:jni (FFI, no web) never enters a web build.
import 'native_provider_web.dart'
    if (dart.library.io) 'native_provider_io.dart';

/// Auto-selecting Google Play Games entry point: the **native** Play Games SDK
/// provider on Android (native toasts/overlay, no OAuth), the **REST** provider
/// everywhere else (desktop, CLI, server, **web**).
///
/// A developer uses this and forgets platform compatibility. The selection is a
/// compile-time-safe platform check: on web `package:jni` is excluded entirely
/// (it has no web support), so only the REST path is built; on native the
/// runtime `Platform.isAndroid` check picks native on Android, REST otherwise.
///
/// Provide the inputs each side needs:
/// - [activityResolver]: returns the Android `Activity` (a `jni` `JObject`),
///   fetched fresh before each native call (required for the native path). It
///   is typed `Object` so this API carries no `jni` types and stays
///   web-compilable. On Flutter, prefer
///   `unified_game_services_google_play_flutter` which wires this for you.
/// - [auth]: an [AuthStrategy] for the REST path (required off Android).
abstract final class GooglePlayGames {
  /// Whether the current platform uses the native provider (always `false` on
  /// web).
  static bool get usesNative => usesNativeProvider;

  /// Creates the provider appropriate for the current platform.
  ///
  /// Throws [ArgumentError] when the input required for the selected platform
  /// is missing.
  static UnifiedGameServicesPlatform create({
    Object Function()? activityResolver,
    AuthStrategy? auth,
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) {
    if (usesNativeProvider) {
      if (activityResolver == null) {
        throw ArgumentError.notNull('activityResolver');
      }
      return createNativeProvider(
        activityResolver: activityResolver,
        leaderboardIds: leaderboardIds,
        achievementIds: achievementIds,
      );
    }
    if (auth == null) {
      throw ArgumentError.notNull('auth');
    }
    return GooglePlayGamesProvider(
      auth: auth,
      leaderboardIds: leaderboardIds,
      achievementIds: achievementIds,
    );
  }

  /// Creates the platform-appropriate provider and registers it as the active
  /// [UnifiedGameServicesPlatform.instance].
  static void registerWith({
    Object Function()? activityResolver,
    AuthStrategy? auth,
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) {
    UnifiedGameServicesPlatform.instance = create(
      activityResolver: activityResolver,
      auth: auth,
      leaderboardIds: leaderboardIds,
      achievementIds: achievementIds,
    );
  }
}
