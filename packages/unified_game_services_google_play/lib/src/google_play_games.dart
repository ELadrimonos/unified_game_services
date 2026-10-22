import 'package:unified_game_services_google_play_rest/unified_game_services_google_play_rest.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

// Native (Android, package:jni) vs web/REST halves are swapped at compile time
// so package:jni (FFI, no web) never enters a web build.
import 'native_provider_web.dart'
    if (dart.library.io) 'native_provider_io.dart';

/// Auto-selecting Google Play Games entry point: the **native** Play Games SDK
/// provider on Android (native toasts and overlay, no OAuth), the **REST**
/// provider everywhere else (desktop, CLI, server, **web**).
///
/// The selection is made per platform. On web, `package:jni` is excluded from
/// the build entirely (it has no web support), so only the REST path exists.
/// On native platforms a runtime `Platform.isAndroid` check picks the native
/// provider on Android and REST otherwise. Pass the input each side needs to
/// [create]:
/// - `activityResolver`: returns the Android `Activity` (a `jni` `JObject`),
///   fetched fresh before each native call. Required on Android. It is typed
///   `Object` so this API carries no `jni` types and stays web-compilable. On
///   Flutter, prefer `unified_game_services_google_play_flutter`, which wires
///   it for you.
/// - `auth`: an [AuthStrategy] for the REST path. Required off Android.
///
/// The two tiers differ in capability. Both advertise achievements and
/// leaderboards, but the native provider currently implements only the writes
/// and sign-in, not reads; see `GooglePlayAndroidProvider`.
abstract final class GooglePlayGames {
  /// Whether Google Play Games is supported on the current platform.
  ///
  /// Always `true`: the REST tier covers every platform.
  static bool get isSupported => true;

  /// Whether [create] returns the native provider on the current platform.
  ///
  /// `true` only on Android; always `false` on web.
  static bool get usesNative => usesNativeProvider;

  /// Creates the provider appropriate for the current platform.
  ///
  /// Returns a `GooglePlayAndroidProvider` (`providerId` `google_play_android`)
  /// on Android and a [GooglePlayGamesProvider] (`google_play_rest`)
  /// elsewhere. The argument for the other tier is ignored.
  ///
  /// Throws [ArgumentError] when the argument required for the selected
  /// platform is missing: [activityResolver] on Android, [auth] elsewhere.
  static UnifiedGameServicesPlatform create({
    Object Function()? activityResolver,
    AuthStrategy? auth,
  }) {
    if (usesNativeProvider) {
      if (activityResolver == null) {
        throw ArgumentError.notNull('activityResolver');
      }
      return createNativeProvider(activityResolver: activityResolver);
    }
    if (auth == null) {
      throw ArgumentError.notNull('auth');
    }
    return GooglePlayGamesProvider(auth: auth);
  }
}
