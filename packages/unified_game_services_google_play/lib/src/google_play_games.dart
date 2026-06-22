import 'dart:io';

import 'package:jni/jni.dart';
import 'package:unified_game_services_google_play_android/unified_game_services_google_play_android.dart';
import 'package:unified_game_services_google_play_rest/unified_game_services_google_play_rest.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Auto-selecting Google Play Games entry point: the **native** Play Games SDK
/// provider on Android (native toasts/overlay, no OAuth), the **REST** provider
/// everywhere else (desktop, CLI, server).
///
/// A developer uses this and forgets platform compatibility. The selection is a
/// runtime `Platform.isAndroid` check — Dart has no compile-time OS guard, so
/// the `jni` dependency is linked into every build but only executes on
/// Android.
///
/// Provide the inputs each side needs:
/// - [activity]: the Android `Activity` jobject (required for the native path).
/// - [auth]: an [AuthStrategy] for the REST path (required off Android).
abstract final class GooglePlayGames {
  /// Whether the current platform uses the native provider.
  static bool get usesNative => Platform.isAndroid;

  /// Creates the provider appropriate for the current platform.
  ///
  /// Throws [ArgumentError] when the input required for the selected platform
  /// is missing.
  static UnifiedGameServicesPlatform create({
    JObject? activity,
    AuthStrategy? auth,
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) {
    if (Platform.isAndroid) {
      if (activity == null) {
        throw ArgumentError.notNull('activity');
      }
      return GooglePlayAndroidProvider(
        activity: activity,
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
    JObject? activity,
    AuthStrategy? auth,
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) {
    UnifiedGameServicesPlatform.instance = create(
      activity: activity,
      auth: auth,
      leaderboardIds: leaderboardIds,
      achievementIds: achievementIds,
    );
  }
}
