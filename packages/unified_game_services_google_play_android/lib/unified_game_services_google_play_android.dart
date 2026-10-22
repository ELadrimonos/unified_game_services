/// Native Google Play Games provider for `unified_game_services`, backed by the
/// Play Games v2 Java SDK over `package:jni`.
///
/// Android only. [GooglePlayAndroidProvider] performs achievement and
/// leaderboard writes through the on-device Play Games client, so they fire
/// the native toasts, and opens the native achievements and leaderboards
/// screens. Reads are not implemented yet; pair it with
/// `unified_game_services_google_play_rest` for those.
///
/// The generated JNI bindings live in `src/playgames_bindings.dart`
/// (regenerate with `tool/regenerate_bindings.sh`).
///
/// @docImport 'src/google_play_android_provider.dart';
library;

export 'src/google_play_android_provider.dart';
