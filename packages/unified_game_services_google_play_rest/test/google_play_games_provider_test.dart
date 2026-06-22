import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:unified_game_services_google_play_rest/unified_game_services_google_play_rest.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import '_fakes.dart';

const _base = 'https://games.googleapis.com/games/v1';

/// Wraps a `"METHOD /path"` → json handler in a [MockClient], recording calls.
({MockClient client, List<http.Request> calls}) mock(
  Map<String, Object> byKey,
) {
  final calls = <http.Request>[];
  final client = MockClient((req) async {
    calls.add(req);
    final key = '${req.method} ${req.url.path.replaceFirst('/games/v1', '')}';
    final body = byKey[key];
    if (body == null) return http.Response('', 404);
    return http.Response(jsonEncode(body), 200);
  });
  return (client: client, calls: calls);
}

GooglePlayGamesProvider providerWith(
  MockClient client, {
  Map<String, String>? leaderboardIds,
  Map<String, String>? achievementIds,
}) {
  final auth = FakeAuthStrategy();
  return GooglePlayGamesProvider.withClient(
    auth: auth,
    client: GamesRestClient(auth: auth, httpClient: client, baseUrl: _base),
    leaderboardIds: leaderboardIds,
    achievementIds: achievementIds,
  );
}

void main() {
  group('GooglePlayGamesProvider', () {
    test('declares achievements + leaderboards only', () {
      final p = providerWith(mock(const {}).client);
      expect(p.capabilities, {
        GameCapability.achievements,
        GameCapability.leaderboards,
      });
      expect(p.supports(GameCapability.stats), isFalse);
      expect(p.supports(GameCapability.cloudSave), isFalse);
      expect(p.supports(GameCapability.friends), isFalse);
    });

    test('signIn loads players/me and emits a sign-in event', () async {
      final m = mock({
        'GET /players/me': {'playerId': '7', 'displayName': 'Ada'},
      });
      final p = providerWith(m.client);
      final events = <GameServiceEvent>[];
      p.events.listen(events.add);
      final profile = await p.signIn();
      expect(profile?.id, '7');
      expect(profile?.displayName, 'Ada');
      await Future<void>.delayed(Duration.zero);
      expect(events.single, isA<UserSignedInEvent>());
    });

    test('getAchievements joins definitions with player progress', () async {
      final m = mock({
        'GET /achievements': {
          'items': [
            {
              'id': 'a1',
              'name': 'First Win',
              'description': 'Win once',
              'achievementType': 'STANDARD',
              'initialState': 'REVEALED',
              'revealedIconUrl': 'r1',
              'unlockedIconUrl': 'u1',
            },
            {
              'id': 'a2',
              'name': 'Marathon',
              'achievementType': 'INCREMENTAL',
              'totalSteps': 100,
              'initialState': 'HIDDEN',
            },
          ],
        },
        'GET /players/me/achievements': {
          'items': [
            {'id': 'a1', 'achievementState': 'UNLOCKED'},
            {'id': 'a2', 'achievementState': 'REVEALED', 'currentSteps': 40},
          ],
        },
      });
      final list = await providerWith(m.client).getAchievements();
      expect(list, hasLength(2));

      final first = list.firstWhere((a) => a.id == 'a1');
      expect(first.isUnlocked, isTrue);
      expect(first.iconUrl, 'u1'); // unlocked icon
      expect(first.isIncremental, isFalse);

      final marathon = list.firstWhere((a) => a.id == 'a2');
      expect(marathon.isUnlocked, isFalse);
      expect(marathon.isIncremental, isTrue);
      expect(marathon.currentSteps, 40);
      expect(marathon.totalSteps, 100);
    });

    test('unlockAchievement resolves the id and emits an event', () async {
      final m = mock({'POST /achievements/CgkI999/unlock': <String, Object>{}});
      final p = providerWith(
        m.client,
        achievementIds: {'first_win': 'CgkI999'},
      );
      final events = <GameServiceEvent>[];
      p.events.listen(events.add);
      await p.unlockAchievement('first_win');
      expect(m.calls.single.url.path, '/games/v1/achievements/CgkI999/unlock');
      await Future<void>.delayed(Duration.zero);
      expect(events.single, isA<AchievementUnlockedEvent>());
    });

    test(
      'incrementAchievement sends steps and an idempotency requestId',
      () async {
        final m = mock({'POST /achievements/a2/increment': <String, Object>{}});
        await providerWith(m.client).incrementAchievement('a2', 5);
        final q = m.calls.single.url.queryParameters;
        expect(q['stepsToIncrement'], '5');
        expect(q['requestId'], isNotEmpty);
      },
    );

    test(
      'submitScore resolves the id, posts the score, emits an event',
      () async {
        final m = mock({
          'POST /leaderboards/CgkI42/scores': <String, Object>{},
        });
        final p = providerWith(m.client, leaderboardIds: {'global': 'CgkI42'});
        final events = <GameServiceEvent>[];
        p.events.listen(events.add);
        await p.submitScore(leaderboardId: 'global', score: 1500);
        final call = m.calls.single;
        expect(call.url.path, '/games/v1/leaderboards/CgkI42/scores');
        expect(call.url.queryParameters['score'], '1500');
        await Future<void>.delayed(Duration.zero);
        expect(events.single, isA<ScoreSubmittedEvent>());
      },
    );

    test('getLeaderboard maps collection/timeSpan and parses scores', () async {
      final m = mock({
        'GET /leaderboards/lb/scores/SOCIAL': {
          'items': [
            {
              'player': {'playerId': '7', 'displayName': 'Ada'},
              'scoreValue': '1500',
              'scoreRank': '1',
              'formattedScore': '1,500',
            },
            {
              'player': {'playerId': '9', 'displayName': 'Bo'},
              'scoreValue': '900',
            },
          ],
        },
      });
      final board = await providerWith(m.client).getLeaderboard(
        'lb',
        collection: LeaderboardCollection.friends,
        timeScope: LeaderboardTimeScope.weekly,
      );
      expect(m.calls.single.url.queryParameters['timeSpan'], 'WEEKLY');
      expect(board.collection, LeaderboardCollection.friends);
      expect(board.entries[0].rank, 1);
      expect(board.entries[0].score, 1500);
      expect(board.entries[0].displayScore, '1,500');
      expect(board.entries[0].player.id, '7');
      // Second row has no scoreRank → falls back to 1-based index.
      expect(board.entries[1].rank, 2);
      expect(board.entries[1].score, 900);
    });

    test('getPlayerScore returns null when the player has no score', () async {
      final m = mock({
        'GET /players/me/leaderboards/lb/scores/ALL_TIME': {
          'items': <Object>[],
        },
      });
      expect(await providerWith(m.client).getPlayerScore('lb'), isNull);
    });

    test('getPlayerScore maps the player\'s own entry when present', () async {
      final m = mock({
        'GET /players/me/leaderboards/lb/scores/ALL_TIME': {
          'items': [
            {
              'player': {'playerId': '7', 'displayName': 'Ada'},
              'scoreValue': '4242',
              'scoreRank': '3',
            },
          ],
        },
      });
      final entry = await providerWith(m.client).getPlayerScore('lb');
      expect(entry?.score, 4242);
      expect(entry?.rank, 3);
    });

    test('signOut clears auth and emits a sign-out event', () async {
      final p = providerWith(mock(const {}).client);
      final events = <GameServiceEvent>[];
      p.events.listen(events.add);
      await p.signOut();
      expect(await p.isSignedIn(), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(events.single, isA<UserSignedOutEvent>());
    });
  });
}
