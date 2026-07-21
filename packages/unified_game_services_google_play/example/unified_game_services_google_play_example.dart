// Auto-selecting Google Play Games demo.
//
// `GooglePlayGames.create` picks the right provider for the platform it runs
// on: native Play Games v2 SDK on Android, REST everywhere else (desktop,
// CLI, server, web). This CLI can only exercise the REST side (there's no
// Android `Activity` to hand it outside an app), so it runs the loopback
// OAuth flow and treats `auth` as the only required input — on Android you'd
// instead pass `activityResolver` (see
// `unified_game_services_google_play_flutter` for a Flutter host that wires
// that for you automatically).
//
// Prerequisites:
//   * A Google Cloud OAuth client of type "Desktop app" → its client id.
//   * A Play Console game with the Games API enabled and your account added
//     as a tester (while the game is unpublished).
//
// Usage:
//   dart run example/unified_game_services_google_play_example.dart \
//     --client-id <DESKTOP_CLIENT_ID> \
//     [--achievement <unified_id> --achievement-native <CgkI...>]
import 'package:args/args.dart';
import 'package:unified_game_services_google_play/unified_game_services_google_play.dart';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('client-id', help: 'Desktop OAuth client id (required).')
    ..addOption(
      'client-secret',
      help: 'Client secret, if your client needs one.',
    )
    ..addOption('achievement', help: 'Unified achievement key to unlock.')
    ..addOption('achievement-native', help: 'Native id for --achievement.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(argv);
  if (args['help'] as bool || args['client-id'] == null) {
    print(
      'Sign in via GooglePlayGames.create (auto-selecting REST off Android).\n',
    );
    print(parser.usage);
    return;
  }

  print(
    'GooglePlayGames.usesNative on this platform: ${GooglePlayGames.usesNative}',
  );

  final achievement = args['achievement'] as String?;
  final provider = GooglePlayGames.create(
    // Ignored on this platform (usesNative is always false off Android), but
    // this is where a Flutter/native Android host would pass a resolver for
    // the current `Activity` instead of `auth`.
    auth: LoopbackOAuthStrategy(
      clientId: args['client-id'] as String,
      clientSecret: args['client-secret'] as String?,
    ),
    achievementIds: {
      if (achievement != null && args['achievement-native'] != null)
        achievement: args['achievement-native'] as String,
    },
  );

  try {
    final profile = await provider.signIn();
    print('Signed in as ${profile?.displayName} (${profile?.id})');

    if (achievement != null) {
      await provider.unlockAchievement(achievement);
      print('Unlocked achievement "$achievement".');
    }
  } finally {
    await provider.dispose();
  }
}
