import 'dart:typed_data';

import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Replace the credentials with your game's id/key (GameJolt dashboard) and the
/// player's username + Game Token.
Future<void> main() async {
  GameJoltProvider.registerWith(
    gameId: 'YOUR_GAME_ID',
    privateKey: 'YOUR_PRIVATE_KEY',
    username: 'player_name',
    userToken: 'player_game_token',
  );
  final services = UnifiedGameServicesPlatform.instance;

  final player = await services.signIn();
  print('Signed in as: ${player?.displayName}');

  if (services.supports(GameCapability.achievements)) {
    await services.unlockAchievement('123456'); // trophy id
  }

  if (services.supports(GameCapability.leaderboards)) {
    await services.submitScore(leaderboardId: '654321', score: 1500);
    final board = await services.getLeaderboard('654321');
    for (final e in board.entries) {
      print('#${e.rank} ${e.player.displayName}: ${e.displayScore}');
    }
  }

  if (services.supports(GameCapability.cloudSave)) {
    await services.saveData('profile', Uint8List.fromList([1, 2, 3]));
    final save = await services.loadData('profile');
    print('Loaded ${save?.bytes.length} bytes');
  }
}
