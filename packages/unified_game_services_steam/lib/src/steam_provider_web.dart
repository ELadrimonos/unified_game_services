import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'steam_auth_ticket.dart';

export 'steam_auth_ticket.dart';

const String _kWebError =
    'SteamProvider is desktop-only (Steamworks via dart:ffi) and is not '
    'available on web. Do not register it in a web build — the facade should '
    'only be given Steam on Windows/macOS/Linux. See the package README.';

/// The web stub of the desktop [SteamProvider].
///
/// The real provider uses `dart:ffi` and cannot compile to JavaScript, so the
/// package entry point exports this stub when `dart.library.io` is
/// unavailable. It mirrors the constructor and the Steam-specific extras so
/// code that references [SteamProvider] still type-checks on web.
/// The constructor and every member throw [UnsupportedError] because Steam
/// cannot run there. Register Steam only on Windows, macOS and Linux.
class SteamProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'steam';

  /// Whether Steam is supported on the current platform.
  ///
  /// Always `false` on web.
  static bool get isSupported => false;

  /// Always throws [UnsupportedError] — Steam is desktop-only.
  SteamProvider({this.appId}) {
    throw UnsupportedError(_kWebError);
  }

  /// The Steam application id; unused on web.
  final int? appId;

  /// Always throws [UnsupportedError] — Steam is desktop-only.
  @override
  Future<void> dispose() => throw UnsupportedError(_kWebError);

  /// Always throws [UnsupportedError]; Steam-specific, not part of the unified
  /// interface.
  Future<void> clearAchievement(String achievementId) =>
      throw UnsupportedError(_kWebError);

  /// Always throws [UnsupportedError]; Steam-specific, not part of the unified
  /// interface.
  Future<void> resetAllStats({bool includeAchievements = false}) =>
      throw UnsupportedError(_kWebError);

  /// Always throws [UnsupportedError]; Steam-specific, not part of the unified
  /// interface.
  int getSteamId64() => throw UnsupportedError(_kWebError);

  /// Always throws [UnsupportedError]; Steam-specific, not part of the unified
  /// interface.
  Future<SteamAuthTicket> getWebApiAuthTicket({String? identity}) =>
      throw UnsupportedError(_kWebError);

  /// Always throws [UnsupportedError]; Steam-specific, not part of the unified
  /// interface.
  void cancelAuthTicket(int handle) => throw UnsupportedError(_kWebError);
}
