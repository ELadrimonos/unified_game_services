#!/usr/bin/env dart
// Interactive REAL integration playground for the Steam provider, using the
// Spacewar test app (appId 480).
//
// Run:  dart run example/interactive_login.dart
//
// Requirements (see example/README.md):
//   - The Steam client running and logged in.
//   - The Steamworks native lib beside the executable (steam_api64.dll /
//     libsteam_api.so / libsteam_api.dylib). `melos run steam:gen` copies it.
//   - A steam_appid.txt containing 480 in the working directory (or rely on the
//     APP_ID passed below).
//
// Steam has no username/password login: the identity is whoever is signed into
// the Steam client. signIn() warms the player's stats and returns that profile.

import 'dart:io';

import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

/// Spacewar (480) ships these for testing.
const _spacewarAchievements = [
  'ACH_WIN_ONE_GAME',
  'ACH_WIN_100_GAMES',
  'ACH_TRAVEL_FAR_ACCUM',
  'ACH_TRAVEL_FAR_SINGLE',
];
const _spacewarLeaderboards = ['Feet Traveled', 'Quickest Win'];

Future<void> main() async {
  stdout.writeln('=== Steam (Spacewar 480) live integration ===\n');

  SteamProvider.registerWith(appId: 480);
  final steam = UnifiedGameServicesPlatform.getInstance<SteamProvider>();

  stdout.write('Initializing Steam… ');
  final PlayerProfile? player;
  try {
    player = await steam.signIn();
  } on GameServiceException catch (e) {
    stdout.writeln('FAILED\n$e');
    stdout.writeln('\nIs the Steam client running, the native lib present, and '
        'steam_appid.txt set to 480?');
    exit(1);
  }
  stdout.writeln('OK');
  stdout.writeln('Player: ${player?.displayName} (id ${player?.id})');

  try {
    await _menu(steam);
  } finally {
    await steam.dispose();
  }
}

Future<void> _menu(SteamProvider steam) async {
  while (true) {
    stdout.writeln('''

Spacewar achievements: ${_spacewarAchievements.join(', ')}
Spacewar leaderboards: ${_spacewarLeaderboards.join(', ')}

  1) List achievements
  2) Unlock an achievement
  3) Clear an achievement (Steam-specific)
  4) Submit a score
  5) View a leaderboard
  6) List friends
  7) Reset all stats (+achievements) (Steam-specific)
  0) Quit''');
    stdout.write('> ');
    final choice = stdin.readLineSync()?.trim();

    try {
      switch (choice) {
        case '1':
          final list = await steam.getAchievements();
          stdout.writeln('${list.length} achievements:');
          for (final a in list) {
            stdout.writeln(
                '  [${a.isUnlocked ? 'x' : ' '}] ${a.id}  ${a.title}');
          }
        case '2':
          await steam.unlockAchievement(_prompt('Achievement id'));
          stdout.writeln('Unlocked.');
        case '3':
          await steam.clearAchievement(_prompt('Achievement id'));
          stdout.writeln('Cleared.');
        case '4':
          final id = _prompt('Leaderboard name');
          final value = int.tryParse(_prompt('Score (int)'));
          if (value == null) {
            stdout.writeln('Not a number.');
            break;
          }
          await steam.submitScore(leaderboardId: id, score: value);
          stdout.writeln('Submitted.');
        case '5':
          final board =
              await steam.getLeaderboard(_prompt('Leaderboard name'));
          stdout.writeln('Top ${board.entries.length}:');
          for (final e in board.entries) {
            stdout.writeln(
                '  #${e.rank} ${e.player.displayName}: ${e.displayScore}');
          }
        case '6':
          final friends = await steam.getFriends();
          stdout.writeln('${friends.length} friends:');
          for (final f in friends) {
            stdout.writeln('  ${f.id}  ${f.displayName}'
                '${f.isOnline == true ? ' (online)' : ''}');
          }
        case '7':
          await steam.resetAllStats(includeAchievements: true);
          stdout.writeln('Reset done.');
        case '0':
        case null:
          return;
        default:
          stdout.writeln('Unknown option.');
      }
    } on GameServiceException catch (e) {
      stdout.writeln('Error: $e');
    }
  }
}

String _prompt(String label) {
  stdout.write('$label: ');
  return stdin.readLineSync()?.trim() ?? '';
}
