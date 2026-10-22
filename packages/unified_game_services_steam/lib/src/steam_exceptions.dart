import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Thrown when Steam asks this process to exit because the game was not
/// launched through the Steam client.
///
/// Steam signals this with `SteamAPI_RestartAppIfNecessary` returning true and
/// is already relaunching the game itself. `SteamProvider.signIn` throws this
/// when it initializes the SDK.
///
/// This is a Steam-specific type, not part of the unified interface. It extends
/// [SignInFailedException], so callers that only know the facade still see a
/// failed sign-in. The provider never calls `exit()`; the app should catch this
/// exception, flush its state and then exit:
///
/// ```dart
/// try {
///   await services.signIn();
/// } on SteamRestartRequiredException {
///   exit(0);
/// }
/// ```
class SteamRestartRequiredException extends SignInFailedException {
  /// Creates the exception with a default [message] and an optional [cause].
  const SteamRestartRequiredException([
    super.message = 'Steam is relaunching the app; this process must exit.',
    super.cause,
  ]);
}
