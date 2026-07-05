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
  SteamProvider({this.appId, super.leaderboardIds, super.achievementIds}) {
    throw UnsupportedError(_kWebError);
  }

  final int? appId;

  static void registerWith({
    int? appId,
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) => throw UnsupportedError(_kWebError);

  @override
  Future<void> dispose() => throw UnsupportedError(_kWebError);

  Future<void> clearAchievement(String achievementId) =>
      throw UnsupportedError(_kWebError);

  Future<void> resetAllStats({bool includeAchievements = false}) =>
      throw UnsupportedError(_kWebError);

  Future<SteamAuthTicket> getWebApiAuthTicket({String? identity}) =>
      throw UnsupportedError(_kWebError);

  void cancelAuthTicket(int handle) => throw UnsupportedError(_kWebError);
}
