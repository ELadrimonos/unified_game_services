import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'steam_auth_ticket.dart';

export 'steam_auth_ticket.dart';

const String _kWebError =
    'SteamProvider is desktop-only (Steamworks via dart:ffi) and is not '
    'available on web. Do not register it in a web build — the facade should '
    'only be given Steam on Windows/macOS/Linux. See the package README.';

/// Web stub of [SteamProvider].
///
/// The real provider is `dart:ffi` (Steamworks) and cannot compile to JS, so
/// the package entry point conditional-exports this stub on web
/// (`if (dart.library.io)` selects the real one). It mirrors the public surface
/// so consumer code that references [SteamProvider] still type-checks on web;
/// every member throws [UnsupportedError] because Steam cannot run there.
class SteamProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'steam';

  /// Always throws [UnsupportedError] — Steam is desktop-only.
  SteamProvider({this.appId, super.leaderboardIds, super.achievementIds}) {
    throw UnsupportedError(_kWebError);
  }

  /// Mirrors the real provider's `appId` field; unused on web.
  final int? appId;

  /// Always throws [UnsupportedError] — Steam is desktop-only.
  @override
  Future<void> dispose() => throw UnsupportedError(_kWebError);

  /// Always throws [UnsupportedError] — Steam is desktop-only.
  Future<void> clearAchievement(String achievementId) =>
      throw UnsupportedError(_kWebError);

  /// Always throws [UnsupportedError] — Steam is desktop-only.
  Future<void> resetAllStats({bool includeAchievements = false}) =>
      throw UnsupportedError(_kWebError);

  /// Always throws [UnsupportedError] — Steam is desktop-only.
  Future<SteamAuthTicket> getWebApiAuthTicket({String? identity}) =>
      throw UnsupportedError(_kWebError);

  /// Always throws [UnsupportedError] — Steam is desktop-only.
  void cancelAuthTicket(int handle) => throw UnsupportedError(_kWebError);
}
