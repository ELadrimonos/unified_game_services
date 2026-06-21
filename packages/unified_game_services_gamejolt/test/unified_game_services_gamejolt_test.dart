import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Wraps a path->json handler in a [MockClient] and records the URIs hit.
({MockClient client, List<Uri> calls}) mock(Map<String, Object> byPath) {
  final calls = <Uri>[];
  final client = MockClient((req) async {
    calls.add(req.url);
    final body = byPath[req.url.path];
    if (body == null) {
      return http.Response(
        jsonEncode({
          'response': {'success': 'false', 'message': 'no stub'},
        }),
        200,
      );
    }
    return http.Response(jsonEncode(body), 200);
  });
  return (client: client, calls: calls);
}

GameJoltProvider providerWith(MockClient client) => GameJoltProvider.withClient(
  client: GameJoltClient(gameId: '1', privateKey: 'secret', httpClient: client),
  username: 'ada',
  userToken: 'tok',
);

const _ok = {
  'response': {'success': 'true'},
};

void main() {
  group('GameJoltClient.signedUri', () {
    final client = GameJoltClient(gameId: '42', privateKey: 'priv');

    test('includes game_id, format and a correct md5 signature', () {
      final uri = client.signedUri('/users/', {'username': 'ada'});
      expect(uri.queryParameters['game_id'], '42');
      expect(uri.queryParameters['username'], 'ada');
      expect(uri.queryParameters['format'], 'json');

      final signature = uri.queryParameters['signature']!;
      final base = uri.toString().split('&signature=').first;
      final expected = md5.convert(utf8.encode('${base}priv')).toString();
      expect(signature, expected);
    });

    test('drops null params', () {
      final uri = client.signedUri('/scores/', {'table_id': null});
      expect(uri.queryParameters.containsKey('table_id'), isFalse);
    });
  });

  group('GameJoltClient errors', () {
    test('throws on success:false with the API message', () async {
      final m = mock({
        '/api/game/v1_2/users/auth/': {
          'response': {'success': 'false', 'message': 'bad token'},
        },
      });
      final client = GameJoltClient(
        gameId: '1',
        privateKey: 's',
        httpClient: m.client,
      );
      expect(
        () => client.get('/users/auth/', {}),
        throwsA(isA<PlatformOperationException>()),
      );
    });

    test('throws NetworkException on non-200', () async {
      final client = GameJoltClient(
        gameId: '1',
        privateKey: 's',
        httpClient: MockClient((_) async => http.Response('nope', 500)),
      );
      expect(() => client.get('/users/', {}), throwsA(isA<NetworkException>()));
    });
  });

  group('GameJoltProvider', () {
    test('declares its capabilities', () {
      final p = providerWith(mock(const {}).client);
      expect(p.capabilities, {
        GameCapability.achievements,
        GameCapability.leaderboards,
        GameCapability.cloudSave,
        GameCapability.friends,
      });
      expect(p.supports(GameCapability.stats), isFalse);
      expect(p.supports(GameCapability.presence), isFalse);
    });

    test('signIn authenticates then loads the profile', () async {
      final m = mock({
        '/api/game/v1_2/users/auth/': _ok,
        '/api/game/v1_2/users/': {
          'response': {
            'success': 'true',
            'users': [
              {'id': 7, 'username': 'ada', 'avatar_url': 'http://a/x.png'},
            ],
          },
        },
      });
      final p = providerWith(m.client);
      final profile = await p.signIn();
      expect(await p.isSignedIn(), isTrue);
      expect(profile?.id, '7');
      expect(profile?.displayName, 'ada');
      expect(m.calls.first.path, '/api/game/v1_2/users/auth/');
    });

    test('getAchievements maps trophies and achieved state', () async {
      final m = mock({
        '/api/game/v1_2/trophies/': {
          'response': {
            'success': 'true',
            'trophies': [
              {
                'id': 1,
                'title': 'First',
                'description': 'd',
                'achieved': false,
              },
              {'id': 2, 'title': 'Won', 'achieved': '2 days ago'},
            ],
          },
        },
      });
      final list = await providerWith(m.client).getAchievements();
      expect(list, hasLength(2));
      expect(list[0].isUnlocked, isFalse);
      expect(list[1].isUnlocked, isTrue);
      expect(list[1].title, 'Won');
    });

    test('submitScore sends table_id, score and sort', () async {
      final m = mock({'/api/game/v1_2/scores/add/': _ok});
      await providerWith(
        m.client,
      ).submitScore(leaderboardId: 'tbl', score: 1500);
      final q = m.calls.single.queryParameters;
      expect(q['table_id'], 'tbl');
      expect(q['score'], '1500');
      expect(q['sort'], '1500');
      expect(q['username'], 'ada');
    });

    test(
      'submitScore translates a unified leaderboard id to the native one',
      () async {
        final m = mock({'/api/game/v1_2/scores/add/': _ok});
        final provider = GameJoltProvider.withClient(
          client: GameJoltClient(
            gameId: '1',
            privateKey: 'secret',
            httpClient: m.client,
          ),
          username: 'ada',
          userToken: 'tok',
          leaderboardIds: const {'global': '12345'},
        );
        await provider.submitScore(leaderboardId: 'global', score: 10);
        // The unified key 'global' is mapped to GameJolt's native table_id.
        expect(m.calls.single.queryParameters['table_id'], '12345');
      },
    );

    test(
      'unlockAchievement translates a unified id; unmapped ids pass through',
      () async {
        final m = mock({'/api/game/v1_2/trophies/add-achieved/': _ok});
        final provider = GameJoltProvider.withClient(
          client: GameJoltClient(
            gameId: '1',
            privateKey: 'secret',
            httpClient: m.client,
          ),
          username: 'ada',
          userToken: 'tok',
          achievementIds: const {'first_win': '999'},
        );
        await provider.unlockAchievement('first_win');
        expect(m.calls.single.queryParameters['trophy_id'], '999');

        await provider.unlockAchievement('unmapped');
        expect(m.calls.last.queryParameters['trophy_id'], 'unmapped');
      },
    );

    test('getLeaderboard ranks entries and distinguishes guests', () async {
      final m = mock({
        '/api/game/v1_2/scores/': {
          'response': {
            'success': 'true',
            'scores': [
              {
                'score': '1,500 pts',
                'sort': '1500',
                'user': 'ada',
                'user_id': 7,
              },
              {
                'score': '900 pts',
                'sort': '900',
                'guest': 'Anon',
                'user_id': 0,
              },
            ],
          },
        },
      });
      final board = await providerWith(m.client).getLeaderboard('tbl');
      expect(board.entries[0].rank, 1);
      expect(board.entries[0].score, 1500);
      expect(board.entries[0].displayScore, '1,500 pts');
      expect(board.entries[0].player.id, '7');
      expect(board.entries[1].player.id, 'guest');
      expect(board.entries[1].player.displayName, 'Anon');
    });

    test('cloud save round-trips bytes through base64', () async {
      Uint8List? stored;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/data-store/set/')) {
          stored = base64Decode(req.url.queryParameters['data']!);
          return http.Response(jsonEncode(_ok), 200);
        }
        if (req.url.path.endsWith('/data-store/')) {
          return http.Response(
            jsonEncode({
              'response': {'success': 'true', 'data': base64Encode(stored!)},
            }),
            200,
          );
        }
        return http.Response(jsonEncode(_ok), 200);
      });
      final p = providerWith(client);
      final data = Uint8List.fromList([1, 2, 3, 250]);
      await p.saveData('slot', data);
      final loaded = await p.loadData('slot');
      expect(loaded?.bytes, data);
    });

    test('loadData returns null for a missing key', () async {
      final m = mock({
        '/api/game/v1_2/data-store/': {
          'response': {'success': 'false', 'message': 'No item with that key.'},
        },
      });
      expect(await providerWith(m.client).loadData('missing'), isNull);
    });

    test('getFriends resolves ids to profiles in a second call', () async {
      final m = mock({
        '/api/game/v1_2/friends/': {
          'response': {
            'success': 'true',
            'friends': [
              {'friend_id': 11},
              {'friend_id': 22},
            ],
          },
        },
        '/api/game/v1_2/users/': {
          'response': {
            'success': 'true',
            'users': [
              {'id': 11, 'username': 'bob'},
              {'id': 22, 'username': 'cy'},
            ],
          },
        },
      });
      final friends = await providerWith(m.client).getFriends();
      expect(friends.map((f) => f.id), ['11', '22']);
      expect(friends.every((f) => f.isFriend == true), isTrue);
      expect(m.calls.last.queryParameters['user_id'], '11,22');
    });

    test('incrementAchievement is unsupported', () {
      final p = providerWith(mock(const {}).client);
      expect(
        () => p.incrementAchievement('1', 1),
        throwsA(isA<CapabilityNotSupportedException>()),
      );
    });
  });

  group('GameJoltProvider sessions (provider-specific)', () {
    test('open/ping/close hit the session endpoints', () async {
      final m = mock({
        '/api/game/v1_2/sessions/open/': _ok,
        '/api/game/v1_2/sessions/ping/': _ok,
        '/api/game/v1_2/sessions/close/': _ok,
      });
      final p = providerWith(m.client);
      await p.openSession();
      await p.pingSession(idle: true);
      await p.closeSession();
      expect(m.calls.map((u) => u.path), [
        '/api/game/v1_2/sessions/open/',
        '/api/game/v1_2/sessions/ping/',
        '/api/game/v1_2/sessions/close/',
      ]);
      expect(m.calls[1].queryParameters['status'], 'idle');
    });

    test(
      'isSessionOpen returns false on success:false without throwing',
      () async {
        final m = mock({
          '/api/game/v1_2/sessions/check/': {
            'response': {'success': 'false'},
          },
        });
        expect(await providerWith(m.client).isSessionOpen(), isFalse);
      },
    );

    test('isSessionOpen returns true when a session is open', () async {
      final m = mock({'/api/game/v1_2/sessions/check/': _ok});
      expect(await providerWith(m.client).isSessionOpen(), isTrue);
    });
  });
}
