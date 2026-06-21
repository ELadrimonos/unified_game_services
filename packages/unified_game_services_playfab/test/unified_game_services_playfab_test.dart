import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';
import 'package:unified_game_services_playfab/unified_game_services_playfab.dart';

/// Wraps a path->data handler in a [MockClient], recording the requests hit.
/// Each handler value becomes the `data` of a PlayFab `{code,status,data}`
/// envelope.
({MockClient client, List<({Uri uri, Map<String, dynamic> body})> calls}) mock(
  Map<String, Object> byPath,
) {
  final calls = <({Uri uri, Map<String, dynamic> body})>[];
  final client = MockClient((req) async {
    calls.add((
      uri: req.url,
      body: (jsonDecode(req.body) as Map).cast<String, dynamic>(),
    ));
    final data = byPath[req.url.path];
    if (data == null) {
      return http.Response(
        jsonEncode({
          'code': 400,
          'status': 'BadRequest',
          'errorMessage': 'no stub',
        }),
        400,
      );
    }
    return http.Response(
      jsonEncode({'code': 200, 'status': 'OK', 'data': data}),
      200,
    );
  });
  return (client: client, calls: calls);
}

PlayFabProvider providerWith(MockClient client) => PlayFabProvider.withClient(
  client: PlayFabClient(titleId: 'ABCD', httpClient: client),
  customId: 'player-1',
);

void main() {
  group('capabilities', () {
    test(
      'advertises stats/leaderboards/cloudSave/friends, not achievements',
      () {
        final p = providerWith(mock(const {}).client);
        expect(p.supports(GameCapability.leaderboards), isTrue);
        expect(p.supports(GameCapability.stats), isTrue);
        expect(p.supports(GameCapability.cloudSave), isTrue);
        expect(p.supports(GameCapability.friends), isTrue);
        expect(p.supports(GameCapability.achievements), isFalse);
        expect(p.supports(GameCapability.presence), isFalse);
      },
    );

    test('achievement ops throw UnimplementedError (base default)', () {
      final p = providerWith(mock(const {}).client);
      expect(
        () => p.unlockAchievement('x'),
        throwsA(isA<UnimplementedError>()),
      );
      expect(() => p.getAchievements(), throwsA(isA<UnimplementedError>()));
    });
  });

  group('auth', () {
    test('signIn stores ticket and resolves profile', () async {
      final m = mock({
        '/Client/LoginWithCustomID': {
          'SessionTicket': 'ticket-xyz',
          'PlayFabId': 'PF1',
        },
        '/Client/GetAccountInfo': {
          'AccountInfo': {
            'PlayFabId': 'PF1',
            'TitleInfo': {'DisplayName': 'Ada', 'AvatarUrl': 'http://a/b.png'},
          },
        },
      });
      final p = providerWith(m.client);

      expect(await p.isSignedIn(), isFalse);
      final profile = await p.signIn();
      expect(await p.isSignedIn(), isTrue);
      expect(profile?.id, 'PF1');
      expect(profile?.displayName, 'Ada');

      final login = m.calls.first;
      expect(login.body['TitleId'], 'ABCD');
      expect(login.body['CustomId'], 'player-1');
      expect(login.body['CreateAccount'], isTrue);
      // Authenticated calls carry the ticket.
      expect(await p.isSignedIn(), isTrue);
    });

    test('authenticated call without sign-in throws NotSignedIn', () {
      final p = providerWith(mock(const {}).client);
      expect(p.getStats(), throwsA(isA<NotSignedInException>()));
    });

    test('failed login throws SignInFailed', () {
      final p = providerWith(mock(const {}).client); // no login stub -> 400
      expect(p.signIn(), throwsA(isA<SignInFailedException>()));
    });
  });

  group('leaderboards & stats', () {
    Future<PlayFabProvider> signedIn(MockClient client) async {
      final p = providerWith(client);
      await p.signIn();
      return p;
    }

    test('submitScore writes the statistic', () async {
      final m = mock({
        '/Client/LoginWithCustomID': {'SessionTicket': 't', 'PlayFabId': 'PF1'},
        '/Client/GetAccountInfo': {
          'AccountInfo': {'PlayFabId': 'PF1'},
        },
        '/Client/UpdatePlayerStatistics': const {},
      });
      final p = await signedIn(m.client);
      await p.submitScore(leaderboardId: 'high', score: 4200);

      final call = m.calls.last;
      expect(call.uri.path, '/Client/UpdatePlayerStatistics');
      final stat = (call.body['Statistics'] as List).first as Map;
      expect(stat['StatisticName'], 'high');
      expect(stat['Value'], 4200);
    });

    test('getLeaderboard maps rows to 1-based ranks', () async {
      final m = mock({
        '/Client/LoginWithCustomID': {'SessionTicket': 't', 'PlayFabId': 'PF1'},
        '/Client/GetAccountInfo': {
          'AccountInfo': {'PlayFabId': 'PF1'},
        },
        '/Client/GetLeaderboard': {
          'Leaderboard': [
            {
              'PlayFabId': 'PF1',
              'DisplayName': 'Ada',
              'StatValue': 99,
              'Position': 0,
            },
            {
              'PlayFabId': 'PF2',
              'DisplayName': 'Bo',
              'StatValue': 50,
              'Position': 1,
            },
          ],
        },
      });
      final p = await signedIn(m.client);
      final lb = await p.getLeaderboard('high');
      expect(lb.entries, hasLength(2));
      expect(lb.entries.first.rank, 1);
      expect(lb.entries.first.score, 99);
      expect(lb.entries.first.player.displayName, 'Ada');
      expect(lb.entries.last.rank, 2);
    });

    test('incrementStat read-modify-writes', () async {
      final m = mock({
        '/Client/LoginWithCustomID': {'SessionTicket': 't', 'PlayFabId': 'PF1'},
        '/Client/GetAccountInfo': {
          'AccountInfo': {'PlayFabId': 'PF1'},
        },
        '/Client/GetPlayerStatistics': {
          'Statistics': [
            {'StatisticName': 'kills', 'Value': 10},
          ],
        },
        '/Client/UpdatePlayerStatistics': const {},
      });
      final p = await signedIn(m.client);
      await p.incrementStat('kills', by: 5);

      final call = m.calls.last;
      final stat = (call.body['Statistics'] as List).first as Map;
      expect(stat['StatisticName'], 'kills');
      expect(stat['Value'], 15);
    });
  });

  group('cloud save', () {
    Future<PlayFabProvider> signedIn(MockClient client) async {
      final p = providerWith(client);
      await p.signIn();
      return p;
    }

    test('saveData base64-encodes and loadData round-trips', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final m = mock({
        '/Client/LoginWithCustomID': {'SessionTicket': 't', 'PlayFabId': 'PF1'},
        '/Client/GetAccountInfo': {
          'AccountInfo': {'PlayFabId': 'PF1'},
        },
        '/Client/UpdateUserData': const {},
        '/Client/GetUserData': {
          'Data': {
            'slot0': {'Value': base64Encode(bytes)},
          },
        },
      });
      final p = await signedIn(m.client);

      await p.saveData('slot0', bytes);
      final saveCall = m.calls.last;
      expect((saveCall.body['Data'] as Map)['slot0'], base64Encode(bytes));

      final loaded = await p.loadData('slot0');
      expect(loaded?.bytes, bytes);
    });

    test('loadData returns null for a missing slot', () async {
      final m = mock({
        '/Client/LoginWithCustomID': {'SessionTicket': 't', 'PlayFabId': 'PF1'},
        '/Client/GetAccountInfo': {
          'AccountInfo': {'PlayFabId': 'PF1'},
        },
        '/Client/GetUserData': const {'Data': {}},
      });
      final p = await signedIn(m.client);
      expect(await p.loadData('nope'), isNull);
    });
  });
}
