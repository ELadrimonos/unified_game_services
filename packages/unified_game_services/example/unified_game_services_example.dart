import 'package:unified_game_services/unified_game_services.dart';

// In a real app you'd import provider packages and construct them, e.g.:
//   import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';
//   import 'package:unified_game_services_steam/unified_game_services_steam.dart';

Future<void> main() async {
  // Pass one or more providers; writes fan out to every capable provider,
  // reads come from the first (primary).
  final services = UnifiedGameServices(providers: [
    // GameJoltProvider(gameId: '…', privateKey: '…', username: '…', userToken: '…'),
    // SteamProvider(appId: 480),
  ]);

  await services.signIn();

  if (services.supports(GameCapability.achievements)) {
    await services.unlockAchievement('first_win'); // every capable provider
  }
  if (services.supports(GameCapability.leaderboards)) {
    await services.submitScore(leaderboardId: 'global', score: 1500);
  }

  final achievements = await services.getAchievements(); // primary only
  print('${achievements.length} achievements on ${services.primary}');
}
