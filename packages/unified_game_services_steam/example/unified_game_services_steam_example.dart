import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

/// Requires the Steam client running, the Steamworks native lib beside the
/// executable, and a `steam_appid.txt` (or pass appId to registerWith).
Future<void> main() async {
  SteamProvider.registerWith(appId: 480); // 480 = Spacewar test app id.
  final services = UnifiedGameServicesPlatform.instance;

  final player = await services.signIn();
  print('Signed in as: ${player?.displayName}');

  if (services.supports(GameCapability.achievements)) {
    await services.unlockAchievement('ACH_WIN_ONE_GAME');
  }

  if (services.supports(GameCapability.leaderboards)) {
    await services.submitScore(leaderboardId: 'Feet Traveled', score: 1500);
    final board = await services.getLeaderboard('Feet Traveled');
    for (final entry in board.entries) {
      print('#${entry.rank} ${entry.player.displayName}: ${entry.score}');
    }
  }
}
