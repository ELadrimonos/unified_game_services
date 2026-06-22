import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:unified_game_services_android_rest/unified_game_services_android_rest.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import '_fakes.dart';

void main() {
  group('GamesRestClient', () {
    test('sends a Bearer token and decodes the JSON body', () async {
      String? authHeader;
      final client = GamesRestClient(
        auth: FakeAuthStrategy(token: 'abc'),
        baseUrl: 'https://x/games/v1',
        httpClient: MockClient((req) async {
          authHeader = req.headers['Authorization'];
          return http.Response(jsonEncode({'playerId': '42'}), 200);
        }),
      );
      final json = await client.get('/players/me');
      expect(authHeader, 'Bearer abc');
      expect(json['playerId'], '42');
    });

    test('on 401 forces one refresh and retries with the new token', () async {
      final auth = FakeAuthStrategy(token: 'stale', refreshedToken: 'fresh');
      final seen = <String?>[];
      final client = GamesRestClient(
        auth: auth,
        baseUrl: 'https://x/games/v1',
        httpClient: MockClient((req) async {
          final token = req.headers['Authorization'];
          seen.add(token);
          if (token == 'Bearer stale') return http.Response('', 401);
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );
      final json = await client.get('/players/me');
      expect(json['ok'], true);
      expect(auth.refreshes, 1);
      expect(seen, ['Bearer stale', 'Bearer fresh']);
    });

    test('throws NotSignedInException when a 401 persists after refresh', () {
      final client = GamesRestClient(
        auth: FakeAuthStrategy(),
        httpClient: MockClient((_) async => http.Response('', 401)),
      );
      expect(
        () => client.get('/players/me'),
        throwsA(isA<NotSignedInException>()),
      );
    });

    test('maps a Google error envelope to PlatformOperationException', () {
      final client = GamesRestClient(
        auth: FakeAuthStrategy(),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'code': 403, 'message': 'The project is not enabled.'},
            }),
            403,
          ),
        ),
      );
      expect(
        () => client.get('/players/me'),
        throwsA(
          isA<PlatformOperationException>()
              .having((e) => e.message, 'message', contains('not enabled'))
              .having((e) => e.code, 'code', '403'),
        ),
      );
    });

    test('wraps transport failures in NetworkException', () {
      final client = GamesRestClient(
        auth: FakeAuthStrategy(),
        httpClient: MockClient((_) async => throw const _Boom()),
      );
      expect(() => client.get('/players/me'), throwsA(isA<NetworkException>()));
    });
  });
}

class _Boom implements Exception {
  const _Boom();
}
