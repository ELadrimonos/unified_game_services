import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

const String _kWebError =
    'GameCenterProvider is macOS/iOS-only (GameKit via Objective-C FFI) and is not '
    'available on web. Do not register it in a web build. See the package README.';

/// The web stub of the macOS and iOS [GameCenterProvider].
///
/// The real provider uses GameKit through Objective-C FFI and cannot compile to
/// JavaScript, so the package entry point exports this stub when
/// `dart.library.io` is unavailable. The constructor and [dispose] throw
/// [UnsupportedError] because Game Center cannot run there. Register Game
/// Center only on macOS and iOS.
class GameCenterProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'game_center';

  /// Whether Game Center is supported on the current platform.
  ///
  /// Always `false` on web.
  static bool get isSupported => false;

  /// Always throws [UnsupportedError].
  GameCenterProvider() {
    throw UnsupportedError(_kWebError);
  }

  /// Always throws [UnsupportedError].
  @override
  Future<void> dispose() => throw UnsupportedError(_kWebError);
}
