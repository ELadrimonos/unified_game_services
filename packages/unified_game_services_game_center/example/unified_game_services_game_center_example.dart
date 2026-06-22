// Game Center example. Runs only on macOS/iOS, and only inside a signed app
// bundle with a pumped main run loop (see GameCenterProvider docs). From a bare
// `dart run` GameKit will refuse to authenticate.
import 'package:unified_game_services_game_center/unified_game_services_game_center.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

Future<void> main() async {
  GameCenterProvider.registerWith(
    // Optional: map your unified keys to Game Center's native ids.
    leaderboardIds: {'global': 'com.example.game.highscores'},
    achievementIds: {'first_win': 'com.example.game.firstwin'},
  );
  final services = UnifiedGameServicesPlatform.instance;

  final player = await services.signIn();
  if (player == null) {
    print('Not signed in to Game Center.');
    return;
  }
  print('Signed in as ${player.displayName} (${player.id})');

  await services.unlockAchievement('first_win');
  await services.submitScore(leaderboardId: 'global', score: 4200);

  final board = await services.getLeaderboard('global', maxResults: 10);
  for (final entry in board.entries) {
    print('#${entry.rank} ${entry.player.displayName} — ${entry.displayScore}');
  }
}
