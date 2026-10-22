/// Flutter adapter for the `unified_game_services` Google Play Games family.
///
/// The provider packages are pure Dart and need the host to supply the Android
/// `Activity` jobject. This adapter is the **only** package in the family that
/// depends on Flutter: it resolves that activity from the running Flutter
/// engine (via `jni_flutter`), so app developers get plug-and-play setup
/// without touching `jni_flutter` or `PlatformDispatcher` themselves.
///
/// ```dart
/// void main() {
///   GameServices.initialize(providers: [
///     GooglePlayGamesFlutter.create(auth: myRestAuthStrategy),
///   ]);
///   runApp(const MyApp());
/// }
/// ```
///
/// On Android [GooglePlayGamesFlutter.create] returns the native Play Games
/// provider and ignores `auth`. Elsewhere, including **web**, it returns the
/// REST provider, which requires an [AuthStrategy]. Unified achievement and
/// leaderboard ids are mapped through `GameServices.initialize`, not here.
///
/// This package re-exports the whole `unified_game_services_google_play` API.
///
/// @docImport 'package:unified_game_services_google_play_rest/unified_game_services_google_play_rest.dart';
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

/// Flutter entry point for the Google Play Games family.
///
/// Mirrors the [GooglePlayGames] factory, but resolves the Android `Activity`
/// from the Flutter engine so callers never pass an `activityResolver`. Hand
/// the result to `GameServices.initialize(providers: [...])`.
abstract final class GooglePlayGamesFlutter {
  /// Whether Google Play Games is supported on the current platform.
  ///
  /// Always `true`: the REST tier covers every platform.
  static bool get isSupported => true;

  /// Builds the platform-appropriate Google Play Games provider.
  ///
  /// On Android this returns the native provider, with the `Activity` resolved
  /// fresh from the running Flutter engine before each native call (it must be
  /// used on the platform thread while the app is foregrounded) and [auth]
  /// ignored. Elsewhere, including web, it returns the REST provider and [auth]
  /// is required.
  ///
  /// Throws [ArgumentError] if [auth] is missing off Android, matching
  /// [GooglePlayGames.create].
  static UnifiedGameServicesPlatform create({AuthStrategy? auth}) {
    if (GooglePlayGames.usesNative) {
      return GooglePlayGames.create(
        activityResolver: flutterActivityResolver(),
      );
    }
    return GooglePlayGames.create(auth: auth);
  }
}
