// Re-exports the native Android provider's public API — only where
// `dart.library.io` exists. On web the conditional export resolves to
// `native_export_web.dart` (empty), keeping `package:jni` out of the web build.
export 'package:unified_game_services_google_play_android/unified_game_services_google_play_android.dart';
