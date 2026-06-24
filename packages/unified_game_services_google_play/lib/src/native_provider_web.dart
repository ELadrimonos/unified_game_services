import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Web (and any non-`dart:io`) half of the facade — the **default** import,
/// replaced by `native_provider_io.dart` where `dart.library.io` exists. Keeps
/// `package:jni` (FFI, no web) out of the web compile graph.

/// Web is never Android, so the facade always picks the REST provider.
bool get usesNativeProvider => false;

/// Unreachable on web (the facade never picks native when [usesNativeProvider]
/// is false); present only so the conditional import resolves.
UnifiedGameServicesPlatform createNativeProvider({
  required Object Function() activityResolver,
  Map<String, String>? leaderboardIds,
  Map<String, String>? achievementIds,
}) {
  throw UnsupportedError(
    'The native Play Games provider is Android-only; this platform uses the '
    'REST provider.',
  );
}
