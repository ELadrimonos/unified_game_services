import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

/// Requires the Steam client running, the Steamworks native lib beside the
/// executable, and a `steam_appid.txt` (or pass appId to the constructor).
Future<void> main() async {
  // 480 = Spacewar test app id. A provider can be used directly, or handed to
  // GameServices.initialize(providers: [...]) from `unified_game_services`.
  final services = SteamProvider(appId: 480);

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
