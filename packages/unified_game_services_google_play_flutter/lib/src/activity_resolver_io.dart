import 'dart:ui' show PlatformDispatcher;

import 'package:jni_flutter/jni_flutter.dart' show androidActivity;

/// Native (`dart.library.io`) half of the Flutter adapter: resolves the Android
/// `Activity` from the running Flutter engine via `jni_flutter`. Selected by
/// conditional import only where `dart.library.io` exists; the web build gets
/// `activity_resolver_web.dart` instead, keeping `jni_flutter` / `package:jni`
/// (no web support) out of the web compile graph.
///
/// Returns a resolver that fetches the current Activity fresh on each call. The
/// result is volatile (stale after rotation / backgrounding), so the native
/// provider invokes this immediately before each JNI call rather than caching
/// it. The return type is `Object` so the facade API carries no `jni` types.
Object Function() flutterActivityResolver() {
  return () {
    final activity = androidActivity(PlatformDispatcher.instance.engineId!);
    if (activity == null) {
      throw StateError(
        'No Android Activity available. Call Google Play Games operations on '
        'the platform thread while the app is foregrounded.',
      );
    }
    return activity;
  };
}
