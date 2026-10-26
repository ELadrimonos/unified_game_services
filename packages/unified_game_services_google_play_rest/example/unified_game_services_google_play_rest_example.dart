import 'package:unified_game_services_google_play_rest/unified_game_services_google_play_rest.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Replace the client id with a "Desktop app" OAuth client from Google Cloud and
/// the native ids with the ones from your Play Console game.
///
/// For a runnable interactive version see `login_demo.dart`.
Future<void> main() async {
  // A provider can be used directly, or handed to
  // GameServices.initialize(providers: [...]) from `unified_game_services`.
  final provider =
      GooglePlayGamesProvider(
        auth: LoopbackOAuthStrategy(clientId: 'YOUR_DESKTOP_CLIENT_ID'),
      )..registerMappings(
        // Unified id -> native Play Games id.
        achievementIds: {'first_win': 'CgkI_achievement_id'},
        leaderboardIds: {'high_score': 'CgkI_leaderboard_id'},
      );

  try {
    // Opens the browser for the OAuth consent screen.
    final player = await provider.signIn();
    print('Signed in as: ${player?.displayName}');

    if (provider.supports(GameCapability.achievements)) {
      await provider.unlockAchievement('first_win');
      final achievements = await provider.getAchievements();
      print('${achievements.length} achievements');
    }

    if (provider.supports(GameCapability.leaderboards)) {
      await provider.submitScore(leaderboardId: 'high_score', score: 1500);
      final board = await provider.getLeaderboard('high_score', maxResults: 10);
      for (final e in board.entries) {
        print('#${e.rank} ${e.player.displayName}: ${e.displayScore}');
      }
    }
  } finally {
    await provider.dispose();
  }
}
