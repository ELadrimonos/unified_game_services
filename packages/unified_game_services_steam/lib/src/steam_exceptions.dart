import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Thrown when Steam asks this process to shut down because the game was not
/// launched through the Steam client (`SteamAPI_RestartAppIfNecessary`
/// returned true). Steam is already relaunching the game itself.
///
/// Provider-specific: not part of the unified interface. It extends
/// [SignInFailedException] so callers that only know the facade still see a
/// failed sign-in. The provider never calls `exit()` itself — the app should
/// catch this, flush its state, then exit:
///
/// ```dart
/// try {
///   await services.signIn();
/// } on SteamRestartRequiredException {
///   exit(0);
/// }
/// ```
class SteamRestartRequiredException extends SignInFailedException {
  const SteamRestartRequiredException([
    super.message = 'Steam is relaunching the app; this process must exit.',
    super.cause,
  ]);
}
