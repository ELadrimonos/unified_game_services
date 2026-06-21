#!/usr/bin/env dart
// Interactive REAL login + integration playground for the GameJolt provider.
//
// Run:  dart run example/interactive_login.dart
//
// Credentials are read from the environment if set, otherwise prompted:
//   GAMEJOLT_GAME_ID, GAMEJOLT_PRIVATE_KEY  -> from your game's GameJolt
//                                              dashboard ("Game API").
//   GAMEJOLT_USERNAME, GAMEJOLT_USER_TOKEN  -> the player's username and
//                                              "Game Token" (gamejolt.com ->
//                                              profile menu -> Game Token).
//
// See example/README.md for step-by-step credential setup.

import 'dart:io';
import 'dart:typed_data';

import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

Future<void> main() async {
  stdout.writeln('=== GameJolt live integration ===\n');

  final gameId = _read('GAMEJOLT_GAME_ID', 'Game ID');
  final privateKey = _read('GAMEJOLT_PRIVATE_KEY', 'Private key', secret: true);
  final username = _read('GAMEJOLT_USERNAME', 'Username');
  final userToken = _read('GAMEJOLT_USER_TOKEN', 'Game Token', secret: true);

  final provider = GameJoltProvider(
    gameId: gameId,
    privateKey: privateKey,
    username: username,
    userToken: userToken,
  );

  try {
    stdout.write('\nSigning in… ');
    final PlayerProfile? player;
    try {
      player = await provider.signIn();
    } on GameServiceException catch (e) {
      stdout.writeln('FAILED\n$e');
      stdout.writeln('\nCheck the username + Game Token and game id/key.');
      exit(1);
    }
    stdout.writeln('OK');
    stdout.writeln('Logged in as: ${player?.displayName} (id ${player?.id})');
    if (player?.avatarUrl != null) stdout.writeln('Avatar: ${player!.avatarUrl}');

    await _menu(provider);
  } finally {
    await provider.dispose();
  }
}

Future<void> _menu(GameJoltProvider provider) async {
  while (true) {
    stdout.writeln('''

What do you want to test?
  1) List achievements (trophies)
  2) Unlock a trophy
  3) Submit a score
  4) View a leaderboard
  5) Cloud save round-trip
  6) List friends
  7) Session: open / check / close
  0) Quit''');
    stdout.write('> ');
    final choice = stdin.readLineSync()?.trim();

    try {
      switch (choice) {
        case '1':
          final list = await provider.getAchievements();
          stdout.writeln('${list.length} trophies:');
          for (final a in list) {
            stdout.writeln(
                '  [${a.isUnlocked ? 'x' : ' '}] ${a.id}  ${a.title}');
          }
        case '2':
          final id = _prompt('Trophy id');
          await provider.unlockAchievement(id);
          stdout.writeln('Unlocked $id.');
        case '3':
          final table = _prompt('Leaderboard (table) id');
          final value = int.tryParse(_prompt('Score (int)'));
          if (value == null) {
            stdout.writeln('Not a number.');
            break;
          }
          await provider.submitScore(leaderboardId: table, score: value);
          stdout.writeln('Submitted $value to $table.');
        case '4':
          final table = _prompt('Leaderboard (table) id');
          final board = await provider.getLeaderboard(table, maxResults: 10);
          stdout.writeln('Top ${board.entries.length}:');
          for (final e in board.entries) {
            stdout.writeln(
                '  #${e.rank} ${e.player.displayName}: ${e.displayScore}');
          }
        case '5':
          final payload = Uint8List.fromList(
              'hello-${DateTime.now().toIso8601String()}'.codeUnits);
          await provider.saveData('ugs_demo', payload);
          final loaded = await provider.loadData('ugs_demo');
          stdout.writeln('Saved ${payload.length} bytes, read back '
              '${loaded?.bytes.length} bytes: '
              '${String.fromCharCodes(loaded?.bytes ?? [])}');
          await provider.deleteSave('ugs_demo');
          stdout.writeln('Deleted test key.');
        case '6':
          final friends = await provider.getFriends();
          stdout.writeln('${friends.length} friends:');
          for (final f in friends) {
            stdout.writeln('  ${f.id}  ${f.displayName}');
          }
        case '7':
          await provider.openSession();
          stdout.writeln('Session open: ${await provider.isSessionOpen()}');
          await provider.closeSession();
          stdout.writeln('Session closed.');
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

/// Reads [envKey] from the environment, or prompts for [label] if unset.
String _read(String envKey, String label, {bool secret = false}) {
  final fromEnv = Platform.environment[envKey];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    stdout.writeln('$label: <from $envKey>');
    return fromEnv;
  }
  return _prompt(label, secret: secret);
}

String _prompt(String label, {bool secret = false}) {
  stdout.write('$label: ');
  if (secret) stdin.echoMode = false;
  final value = stdin.readLineSync()?.trim() ?? '';
  if (secret) {
    stdin.echoMode = true;
    stdout.writeln();
  }
  return value;
}
