// Cross-provider demo: one unified call fans out to BOTH GameJolt and Steam,
// even though each platform names the same trophy/leaderboard differently.
//
// The trick is per-provider id aliasing (see SteamProvider/GameJoltProvider
// constructors): you submit against a single *unified* key like 'high_score'
// and each provider translates it to its own native id before the call.
//
// Run (live) with your own credentials:
//   GAMEJOLT_GAME_ID=... GAMEJOLT_PRIVATE_KEY=... \
//   GAMEJOLT_USERNAME=... GAMEJOLT_GAME_TOKEN=... \
//   STEAM_APP_ID=480 \
//   dart run example/unified_game_services_example.dart
//
// Steam also needs its native lib + a running Steam client; see the steam
// package README. With no env vars set the demo just explains what it would do.

import 'dart:io';

import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

// Unified keys the *app* uses. They mean nothing to any single platform — each
// provider maps them to its own native id below.
const kFirstWin = 'first_win';
const kHighScore = 'high_score';

Future<void> main() async {
  final env = Platform.environment;
  final providers = <UnifiedGameServicesPlatform>[];

  // ── GameJolt ──────────────────────────────────────────────────────────────
  // GameJolt names trophies by numeric trophy_id and leaderboards by table_id.
  final gjGameId = env['GAMEJOLT_GAME_ID'];
  if (gjGameId != null) {
    providers.add(
      GameJoltProvider(
        gameId: gjGameId,
        privateKey: env['GAMEJOLT_PRIVATE_KEY']!,
        username: env['GAMEJOLT_USERNAME']!,
        userToken: env['GAMEJOLT_GAME_TOKEN']!,
        achievementIds: {kFirstWin: env['GAMEJOLT_FIRST_WIN_ID'] ?? '123456'},
        leaderboardIds: {
          kHighScore: env['GAMEJOLT_HIGH_SCORE_TABLE'] ?? '654321',
        },
      ),
    );
  }

  // ── Steam ───────────────────────────────────────────────────────────────
  // Steam names achievements and leaderboards by API-name strings. Spacewar
  // (appId 480) ships the ACH_WIN_ONE_GAME achievement + a "Feet Traveled" /
  // "Quickest Win" board, handy for testing.
  final steamAppId = int.tryParse(env['STEAM_APP_ID'] ?? '');
  if (steamAppId != null) {
    providers.add(
      SteamProvider(
        appId: steamAppId,
        achievementIds: {
          kFirstWin: env['STEAM_FIRST_WIN'] ?? 'ACH_WIN_ONE_GAME',
        },
        leaderboardIds: {kHighScore: env['STEAM_HIGH_SCORE'] ?? 'Quickest Win'},
      ),
    );
  }

  if (providers.isEmpty) {
    stdout.writeln(
      'No providers configured. Set GAMEJOLT_* and/or STEAM_APP_ID '
      'to run live.\n\nWhat this demo does once configured:\n'
      '  services.unlockAchievement("$kFirstWin")\n'
      '    → GameJolt trophy_id 123456 AND Steam ACH_WIN_ONE_GAME\n'
      '  services.submitScore(leaderboardId: "$kHighScore", score: 1500)\n'
      '    → GameJolt table 654321 AND Steam "Quickest Win"\n'
      'One unified call, each provider hits its own native id.',
    );
    return;
  }

  final services = UnifiedGameServices(providers: providers);
  stdout.writeln(
    'Providers: '
    '${providers.map((p) => p.runtimeType).join(', ')}\n',
  );

  await services.signIn();

  // ── Unified write: fans out to EVERY capable provider ──────────────────────
  if (services.supports(GameCapability.achievements)) {
    await services.unlockAchievement(kFirstWin);
    stdout.writeln('Unlocked "$kFirstWin" on all capable providers.');
  }
  if (services.supports(GameCapability.leaderboards)) {
    await services.submitScore(leaderboardId: kHighScore, score: 1500);
    stdout.writeln('Submitted 1500 to "$kHighScore" on all capable providers.');
  }

  // ── Read back per provider to prove each resolved its own native id ────────
  for (final p in providers) {
    stdout.writeln('\n── ${p.runtimeType} ──');
    try {
      final achievements = await services.getAchievements(from: p);
      final unlocked = achievements.where((a) => a.isUnlocked).length;
      stdout.writeln(
        'Achievements: ${achievements.length} '
        '($unlocked unlocked)',
      );

      final board = await services.getLeaderboard(kHighScore, from: p);
      stdout.writeln(
        'Leaderboard "${board.id}": '
        '${board.entries.length} entries',
      );
      for (final e in board.entries.take(3)) {
        stdout.writeln(
          '  #${e.rank} ${e.player.displayName}: '
          '${e.displayScore}',
        );
      }
    } on GameServiceException catch (e) {
      stdout.writeln('  (read failed: $e)');
    }
  }
}
