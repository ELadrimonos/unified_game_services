import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

const String _kWebError =
    'GameCenterProvider is macOS/iOS-only (GameKit via Objective-C FFI) and is not '
    'available on web. Do not register it in a web build. See the package README.';

/// Web stub of [GameCenterProvider].
class GameCenterProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'game_center';

  /// Whether Game Center is supported on the current platform (always `false` on web).
  static bool get isSupported => false;

  /// Always throws [UnsupportedError] — Game Center is macOS/iOS-only.
  GameCenterProvider() {
    throw UnsupportedError(_kWebError);
  }

  @override
  Future<void> dispose() => throw UnsupportedError(_kWebError);
}
