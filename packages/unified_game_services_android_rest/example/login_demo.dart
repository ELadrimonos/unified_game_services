// Interactive end-to-end demo for the Google Play Games REST provider.
//
// Signs in via the loopback OAuth flow (opens a browser), then optionally
// unlocks an achievement, submits a score, and prints a leaderboard.
//
// Prerequisites:
//   * A Google Cloud OAuth client of type "Desktop app" → its client id.
//   * A Play Console game with the Games API enabled and your account added as
//     a tester (while the game is unpublished).
//
// Usage:
//   dart run example/login_demo.dart \
//     --client-id <DESKTOP_CLIENT_ID> \
//     [--achievement <unified_id> --achievement-native <CgkI...>] \
//     [--leaderboard <unified_id> --leaderboard-native <CgkI...> --score 1500]
import 'package:args/args.dart';
import 'package:unified_game_services_android_rest/unified_game_services_android_rest.dart';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('client-id', help: 'Desktop OAuth client id (required).')
    ..addOption(
      'client-secret',
      help: 'Client secret, if your client needs one.',
    )
    ..addOption('achievement', help: 'Unified achievement key to unlock.')
    ..addOption('achievement-native', help: 'Native id for --achievement.')
    ..addOption('leaderboard', help: 'Unified leaderboard key to use.')
    ..addOption('leaderboard-native', help: 'Native id for --leaderboard.')
    ..addOption('score', help: 'Score to submit to --leaderboard.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(argv);
  if (args['help'] as bool || args['client-id'] == null) {
    print('Sign in to Google Play Games and exercise the REST provider.\n');
    print(parser.usage);
    return;
  }

  final achievement = args['achievement'] as String?;
  final leaderboard = args['leaderboard'] as String?;

  final auth = LoopbackOAuthStrategy(
    clientId: args['client-id'] as String,
    clientSecret: args['client-secret'] as String?,
  );
  final provider = GooglePlayGamesProvider(
    auth: auth,
    achievementIds: {
      if (achievement != null && args['achievement-native'] != null)
        achievement: args['achievement-native'] as String,
    },
    leaderboardIds: {
      if (leaderboard != null && args['leaderboard-native'] != null)
        leaderboard: args['leaderboard-native'] as String,
    },
  );

  try {
    final profile = await provider.signIn();
    print('Signed in as ${profile?.displayName} (${profile?.id})');

    if (achievement != null) {
      await provider.unlockAchievement(achievement);
      print('Unlocked achievement "$achievement".');
    }

    if (leaderboard != null) {
      final score = int.tryParse('${args['score']}');
      if (score != null) {
        await provider.submitScore(leaderboardId: leaderboard, score: score);
        print('Submitted score $score to "$leaderboard".');
      }
      final board = await provider.getLeaderboard(leaderboard, maxResults: 10);
      print('Top of "$leaderboard":');
      for (final e in board.entries) {
        print('  #${e.rank}  ${e.player.displayName}  ${e.displayScore}');
      }
    }
  } finally {
    await provider.dispose();
  }
}
