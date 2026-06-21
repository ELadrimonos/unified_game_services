#!/usr/bin/env dart
// Live smoke test against the real GameJolt Game API. Reads credentials from
// the environment and exercises the provider end to end.
//
// Required env vars:
//   GAMEJOLT_GAME_ID       the game's public id
//   GAMEJOLT_PRIVATE_KEY   the game's private key
//   GAMEJOLT_USERNAME      a player's GameJolt username
//   GAMEJOLT_USER_TOKEN    that player's Game Token
//
// Read-only by default (auth, profile, achievements, friends). Side-effecting
// steps are opt-in:
//   --leaderboard <tableId>   fetch a leaderboard (read-only)
//   --unlock <trophyId>       unlock a trophy           (WRITE)
//   --score <tableId> <n>     submit a score            (WRITE)
//   --cloud                   data-store round-trip+delete on a test key (WRITE)
//   --session                 open/ping/check/close a session
//
// Usage:
//   dart run tool/smoke_test.dart
//   dart run tool/smoke_test.dart --cloud --session --leaderboard 654321
//   dart run tool/smoke_test.dart --unlock 123456 --score 654321 1500

import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';

const _testCloudKey = 'ugs_smoke_test';

int _failures = 0;

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('leaderboard', help: 'Leaderboard table id to fetch.')
    ..addOption('unlock', help: 'Trophy id to unlock (WRITE).')
    ..addMultiOption('score',
        help: 'Submit a score: --score <tableId> <value> (WRITE).')
    ..addFlag('cloud',
        help: 'Run a data-store round-trip on a test key (WRITE).',
        negatable: false)
    ..addFlag('session',
        help: 'Open/ping/check/close a session.', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exit(64);
  }
  if (args['help'] as bool) {
    stdout.writeln('GameJolt live smoke test.\n\n${parser.usage}');
    return;
  }

  final creds = _readCreds();
  final provider = GameJoltProvider(
    gameId: creds.gameId,
    privateKey: creds.privateKey,
    username: creds.username,
    userToken: creds.userToken,
  );

  try {
    await _step('signIn', () async {
      final player = await provider.signIn();
      _info('player: ${player?.displayName} (id ${player?.id})');
    });

    await _step('getCurrentPlayer', () async {
      final p = await provider.getCurrentPlayer();
      _info('avatar: ${p?.avatarUrl ?? '—'}');
    });

    await _step('getAchievements', () async {
      final list = await provider.getAchievements();
      final unlocked = list.where((a) => a.isUnlocked).length;
      _info('${list.length} trophies, $unlocked unlocked');
      for (final a in list.take(5)) {
        _info('  [${a.isUnlocked ? 'x' : ' '}] ${a.id} ${a.title}');
      }
    });

    await _step('getFriends', () async {
      final friends = await provider.getFriends();
      _info('${friends.length} friends');
    });

    final leaderboard = args['leaderboard'] as String?;
    if (leaderboard != null) {
      await _step('getLeaderboard($leaderboard)', () async {
        final board = await provider.getLeaderboard(leaderboard, maxResults: 5);
        for (final e in board.entries) {
          _info('  #${e.rank} ${e.player.displayName}: ${e.displayScore}');
        }
      });
    }

    final unlock = args['unlock'] as String?;
    if (unlock != null) {
      await _step('unlockAchievement($unlock)',
          () => provider.unlockAchievement(unlock));
    }

    final score = args['score'] as List<String>;
    if (score.isNotEmpty) {
      if (score.length != 2 || int.tryParse(score[1]) == null) {
        _fail('--score expects <tableId> <intValue>');
      } else {
        await _step('submitScore(${score[0]}, ${score[1]})',
            () => provider.submitScore(
                leaderboardId: score[0], score: int.parse(score[1])));
      }
    }

    if (args['cloud'] as bool) {
      await _step('cloud round-trip', () async {
        final payload =
            Uint8List.fromList(List.generate(16, (i) => (i * 17) & 0xff));
        await provider.saveData(_testCloudKey, payload);
        final loaded = await provider.loadData(_testCloudKey);
        if (loaded == null || !_bytesEqual(loaded.bytes, payload)) {
          throw StateError('cloud payload mismatch');
        }
        await provider.deleteSave(_testCloudKey);
        final gone = await provider.loadData(_testCloudKey);
        if (gone != null) throw StateError('key not deleted');
        _info('save/load/delete OK on "$_testCloudKey"');
      });
    }

    if (args['session'] as bool) {
      await _step('session open/ping/check/close', () async {
        await provider.openSession();
        await provider.pingSession();
        _info('session open: ${await provider.isSessionOpen()}');
        await provider.closeSession();
      });
    }
  } finally {
    await provider.dispose();
  }

  stdout.writeln(
      _failures == 0 ? '\nAll steps passed.' : '\n$_failures step(s) FAILED.');
  exit(_failures == 0 ? 0 : 1);
}

({String gameId, String privateKey, String username, String userToken})
    _readCreds() {
  final env = Platform.environment;
  String require(String key) {
    final v = env[key];
    if (v == null || v.isEmpty) {
      _fail('Missing env var $key. Set GAMEJOLT_GAME_ID, GAMEJOLT_PRIVATE_KEY, '
          'GAMEJOLT_USERNAME and GAMEJOLT_USER_TOKEN.');
    }
    return v;
  }

  return (
    gameId: require('GAMEJOLT_GAME_ID'),
    privateKey: require('GAMEJOLT_PRIVATE_KEY'),
    username: require('GAMEJOLT_USERNAME'),
    userToken: require('GAMEJOLT_USER_TOKEN'),
  );
}

Future<void> _step(String name, Future<void> Function() body) async {
  try {
    await body();
    stdout.writeln('✓ $name');
  } catch (e) {
    _failures++;
    stdout.writeln('✗ $name — $e');
  }
}

void _info(String msg) => stdout.writeln('  $msg');

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Never _fail(String msg) {
  stderr.writeln('error: $msg');
  exit(64);
}
