import 'dart:io';

import 'package:jni/jni.dart';
import 'package:unified_game_services_google_play_android/unified_game_services_google_play_android.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Native (`dart:io` + `package:jni`) half of the facade. Selected by
/// conditional import only where `dart.library.io` exists; the web build gets
/// `native_provider_web.dart` instead, so `package:jni` (FFI, no web) never
/// enters the web compile graph.

/// Whether the current platform uses the native Play Games provider.
bool get usesNativeProvider => Platform.isAndroid;

/// Builds the native Android provider. [activityResolver] returns the host
/// Android `Activity` (a `jni` `JObject`) fresh on each call; it is typed
/// `Object` here so the facade's public API stays free of `jni` types (and thus
/// web-compilable).
UnifiedGameServicesPlatform createNativeProvider({
  required Object Function() activityResolver,
  Map<String, String>? leaderboardIds,
  Map<String, String>? achievementIds,
}) {
  return GooglePlayAndroidProvider(
    activityResolver: () => activityResolver() as JObject,
    leaderboardIds: leaderboardIds,
    achievementIds: achievementIds,
  );
}
