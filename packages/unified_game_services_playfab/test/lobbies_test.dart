import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';
import 'package:unified_game_services_playfab/unified_game_services_playfab.dart';

typedef _Call = ({
  Uri uri,
  Map<String, dynamic> body,
  Map<String, String> headers,
});

/// Serves `byPath` (mutable, read at call time) and records every request.
({MockClient client, List<_Call> calls}) mock(Map<String, Object> byPath) {
  final calls = <_Call>[];
  final client = MockClient((req) async {
    calls.add((
      uri: req.url,
      body: (jsonDecode(req.body) as Map).cast<String, dynamic>(),
      headers: req.headers,
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
    if (data is ({int errorCode, String message})) {
      return http.Response(
        jsonEncode({
          'code': 400,
          'status': 'BadRequest',
          'errorCode': data.errorCode,
          'errorMessage': data.message,
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

const _entity = {'Id': 'ME', 'Type': 'title_player_account'};

Map<String, Object> _baseStubs() => {
  '/Client/LoginWithCustomID': {
    'SessionTicket': 'ticket',
    'PlayFabId': 'PF1',
    'EntityToken': {
      'EntityToken': 'entity-1',
      'TokenExpiration': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'Entity': _entity,
    },
  },
  '/Client/GetAccountInfo': {
    'AccountInfo': {'PlayFabId': 'PF1'},
  },
};

Map<String, dynamic> _lobbyJson({
  String owner = 'ME',
  List<String> members = const ['ME'],
  Map<String, Object> lobbyData = const {},
  Map<String, Object> searchData = const {},
  Map<String, Map<String, String>> memberData = const {},
}) => {
  'LobbyId': 'L1',
  'ConnectionString': 'conn-L1',
  'MaxPlayers': 4,
  'AccessPolicy': 'Friends',
  'Owner': {'Id': owner, 'Type': 'title_player_account'},
  'Members': [
    for (final m in members)
      {
        'MemberEntity': {'Id': m, 'Type': 'title_player_account'},
        'MemberData': memberData[m] ?? const {},
      },
  ],
  'LobbyData': lobbyData,
  'SearchData': searchData,
};

Future<({PlayFabProvider p, Map<String, Object> stubs, List<_Call> calls})>
signedIn({
  Map<String, String> searchKeys = const {
    'mode': 'string_key1',
    'level': 'number_key1',
  },
}) async {
  final stubs = _baseStubs();
  final m = mock(stubs);
  final p = PlayFabProvider.withClient(
    client: PlayFabClient(titleId: 'ABCD', httpClient: m.client),
    customId: 'c',
    lobbySearchKeys: searchKeys,
    lobbyPollInterval: null,
  );
  await p.signIn();
  return (p: p, stubs: stubs, calls: m.calls);
}

void main() {
  test('sign-in keeps the entity token and id', () async {
    final s = await signedIn();
    expect(s.p.entityId, 'ME');
  });

  test(
    'createLobby maps unified data onto PlayFab lobby and search data',
    () async {
      final s = await signedIn();
      s.stubs['/Lobby/CreateLobby'] = {
        'LobbyId': 'L1',
        'ConnectionString': 'conn-L1',
      };
      s.stubs['/Lobby/GetLobby'] = {
        'Lobby': _lobbyJson(
          lobbyData: {'map': 'dust'},
          searchData: {'string_key1': 'ranked', 'number_key1': 7},
        ),
      };

      final lobby = await s.p.createLobby(
        data: {'mode': 'ranked', 'level': '7', 'map': 'dust'},
        memberData: {'ready': 'false'},
      );

      final create = s.calls.firstWhere(
        (c) => c.uri.path == '/Lobby/CreateLobby',
      );
      expect(create.headers['X-EntityToken'], 'entity-1');
      expect(create.body['Owner'], _entity);
      expect(create.body['UseConnections'], isFalse);
      expect(create.body['OwnerMigrationPolicy'], 'None');
      expect(create.body['AccessPolicy'], 'Friends');
      expect(create.body['LobbyData'], {'map': 'dust'});
      expect(create.body['SearchData'], {
        'string_key1': 'ranked',
        'number_key1': 7,
      });
      expect((create.body['Members'] as List).single['MemberData'], {
        'ready': 'false',
      });

      expect(lobby.providerId, 'playfab');
      expect(lobby.joinToken, 'conn-L1');
      expect(lobby.ownerId, 'ME');
      expect(lobby.visibility, LobbyVisibility.friendsOnly);
      expect(lobby.data, {'map': 'dust', 'mode': 'ranked', 'level': '7'});
    },
  );

  test('a party is persisted in lobby data and stripped on read', () async {
    final s = await signedIn();
    s.stubs['/Lobby/CreateLobby'] = {'LobbyId': 'L1', 'ConnectionString': 'c'};
    s.stubs['/Lobby/GetLobby'] = {
      'Lobby': _lobbyJson(lobbyData: {'ugs_kind': 'party', 'map': 'dust'}),
    };

    final party = await s.p.createLobby(
      kind: LobbyKind.party,
      visibility: LobbyVisibility.private,
    );

    final create = s.calls.firstWhere(
      (c) => c.uri.path == '/Lobby/CreateLobby',
    );
    expect(create.body['LobbyData'], {'ugs_kind': 'party'});
    expect(create.body['AccessPolicy'], 'Private');
    expect(party.kind, LobbyKind.party);
    expect(party.data, {'map': 'dust'});
  });

  test('joinLobby sends the connection string and member data', () async {
    final s = await signedIn();
    s.stubs['/Lobby/JoinLobby'] = {'LobbyId': 'L1'};
    s.stubs['/Lobby/GetLobby'] = {
      'Lobby': _lobbyJson(members: ['OWNER', 'ME'], owner: 'OWNER'),
    };

    final lobby = await s.p.joinLobby('conn-L1', memberData: {'team': 'red'});

    final join = s.calls.firstWhere((c) => c.uri.path == '/Lobby/JoinLobby');
    expect(join.body['ConnectionString'], 'conn-L1');
    expect(join.body['MemberEntity'], _entity);
    expect(join.body['MemberData'], {'team': 'red'});
    expect(lobby.members.map((m) => m.player.id), ['OWNER', 'ME']);
  });

  test(
    'getLobby returns null when PlayFab says the lobby does not exist',
    () async {
      final s = await signedIn();
      s.stubs['/Lobby/GetLobby'] = (
        errorCode: 13000,
        message: 'LobbyDoesNotExist',
      );
      expect(await s.p.getLobby('gone'), isNull);

      s.stubs['/Lobby/GetLobby'] = (errorCode: 13001, message: 'rate limited');
      expect(s.p.getLobby('x'), throwsA(isA<PlatformOperationException>()));
    },
  );

  test('findLobbies builds an OData filter and returns summaries', () async {
    final s = await signedIn();
    s.stubs['/Lobby/FindLobbies'] = {
      'Lobbies': [
        {
          'LobbyId': 'L9',
          'ConnectionString': 'conn-L9',
          'CurrentPlayers': 1,
          'MaxPlayers': 2,
          'Owner': {'Id': 'X', 'Type': 'title_player_account'},
          'SearchData': {'string_key1': 'ranked'},
        },
      ],
    };

    final found = await s.p.findLobbies(
      filters: [
        const LobbyFilter('mode', LobbyFilterOp.equals, "ra'nked"),
        const LobbyFilter('level', LobbyFilterOp.greaterThan, '3'),
      ],
      maxResults: 200,
    );

    final call = s.calls.firstWhere((c) => c.uri.path == '/Lobby/FindLobbies');
    expect(
      call.body['Filter'],
      "string_key1 eq 'ra''nked' and number_key1 gt 3",
    );
    expect(call.body['Pagination'], {'PageSizeRequested': 50});
    final lobby = found.single;
    expect(lobby.size, 1);
    expect(lobby.hasRoom, isTrue);
    expect(lobby.members, isEmpty);
    expect(lobby.data, {'mode': 'ranked'});
    expect(lobby.joinToken, 'conn-L9');
  });

  test('a filter on a key without a search mapping is rejected', () async {
    final s = await signedIn();
    expect(
      s.p.findLobbies(
        filters: [const LobbyFilter('map', LobbyFilterOp.equals, 'x')],
      ),
      throwsArgumentError,
    );
    expect(
      s.p.findLobbies(
        filters: [const LobbyFilter('mode', LobbyFilterOp.greaterThan, '1')],
      ),
      throwsArgumentError,
    );
  });

  test(
    'updateLobby splits sets and deletes between lobby and search data',
    () async {
      final s = await signedIn();
      s.stubs['/Lobby/UpdateLobby'] = const {};
      s.stubs['/Lobby/GetLobby'] = {'Lobby': _lobbyJson()};

      await s.p.updateLobby(
        'L1',
        data: {'mode': 'casual', 'map': null, 'level': null, 'note': 'hi'},
        visibility: LobbyVisibility.public,
        maxMembers: 6,
      );

      final u = s.calls
          .firstWhere((c) => c.uri.path == '/Lobby/UpdateLobby')
          .body;
      expect(u['SearchData'], {'string_key1': 'casual'});
      expect(u['LobbyData'], {'note': 'hi'});
      expect(u['LobbyDataToDelete'], ['map']);
      expect(u['SearchDataToDelete'], ['number_key1']);
      expect(u['AccessPolicy'], 'Public');
      expect(u['MaxPlayers'], 6);
    },
  );

  test('setMemberData updates the caller and deletes null keys', () async {
    final s = await signedIn();
    s.stubs['/Lobby/UpdateLobby'] = const {};
    s.stubs['/Lobby/GetLobby'] = {
      'Lobby': _lobbyJson(
        memberData: {
          'ME': {'ready': 'true'},
        },
      ),
    };

    final lobby = await s.p.setMemberData('L1', {'ready': 'true', 'old': null});

    final u = s.calls
        .firstWhere((c) => c.uri.path == '/Lobby/UpdateLobby')
        .body;
    expect(u['MemberEntity'], _entity);
    expect(u['MemberData'], {'ready': 'true'});
    expect(u['MemberDataToDelete'], ['old']);
    expect(lobby.members.single.data, {'ready': 'true'});
  });

  test('leaveLobby posts the member entity', () async {
    final s = await signedIn();
    s.stubs['/Lobby/LeaveLobby'] = const {};
    await s.p.leaveLobby('L1');
    final l = s.calls.firstWhere((c) => c.uri.path == '/Lobby/LeaveLobby').body;
    expect(l, {'LobbyId': 'L1', 'MemberEntity': _entity});
  });

  test(
    'an entity token missing from login is fetched with GetEntityToken',
    () async {
      final stubs = _baseStubs();
      (stubs['/Client/LoginWithCustomID']! as Map).remove('EntityToken');
      stubs['/Authentication/GetEntityToken'] = {
        'EntityToken': 'entity-2',
        'TokenExpiration': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .toIso8601String(),
        'Entity': _entity,
      };
      stubs['/Lobby/GetLobby'] = {'Lobby': _lobbyJson()};
      final m = mock(stubs);
      final p = PlayFabProvider.withClient(
        client: PlayFabClient(titleId: 'ABCD', httpClient: m.client),
        customId: 'c',
        lobbyPollInterval: null,
      );
      await p.signIn();

      await p.getLobby('L1');

      expect(
        m.calls
            .firstWhere((c) => c.uri.path == '/Lobby/GetLobby')
            .headers['X-EntityToken'],
        'entity-2',
      );
    },
  );

  test('lobby calls before sign-in throw NotSignedIn', () {
    final p = PlayFabProvider.withClient(
      client: PlayFabClient(titleId: 'ABCD', httpClient: mock({}).client),
      customId: 'c',
      lobbyPollInterval: null,
    );
    expect(p.getLobby('x'), throwsA(isA<NotSignedInException>()));
  });

  test('lobbySearchKeys must be PlayFab search key names', () {
    expect(
      () => PlayFabProvider.withClient(
        client: PlayFabClient(titleId: 'ABCD', httpClient: mock({}).client),
        customId: 'c',
        lobbySearchKeys: const {'mode': 'mode'},
      ),
      throwsArgumentError,
    );
  });

  test('pollLobbies emits member, owner, data and closed events', () async {
    final s = await signedIn();
    final events = <GameServiceEvent>[];
    s.p.events.listen(events.add);

    s.stubs['/Lobby/CreateLobby'] = {'LobbyId': 'L1', 'ConnectionString': 'c'};
    s.stubs['/Lobby/GetLobby'] = {'Lobby': _lobbyJson()};
    await s.p.createLobby();

    s.stubs['/Lobby/GetLobby'] = {
      'Lobby': _lobbyJson(members: ['ME', 'B'], lobbyData: {'phase': 'ready'}),
    };
    await s.p.pollLobbies();
    await Future<void>.delayed(Duration.zero);
    expect(
      events.whereType<LobbyMemberJoinedEvent>().single.member.player.id,
      'B',
    );
    expect(events.whereType<LobbyDataChangedEvent>(), hasLength(1));

    events.clear();
    s.stubs['/Lobby/GetLobby'] = {
      'Lobby': _lobbyJson(
        owner: 'B',
        members: ['B'],
        lobbyData: {'phase': 'ready'},
      ),
    };
    await s.p.pollLobbies();
    await Future<void>.delayed(Duration.zero);
    expect(
      events.whereType<LobbyMemberLeftEvent>().single.member.player.id,
      'ME',
    );
    final owner = events.whereType<LobbyOwnerChangedEvent>().single;
    expect(owner.previousOwnerId, 'ME');
    expect(owner.lobby.ownerId, 'B');

    events.clear();
    s.stubs['/Lobby/GetLobby'] = (
      errorCode: 13000,
      message: 'LobbyDoesNotExist',
    );
    await s.p.pollLobbies();
    await Future<void>.delayed(Duration.zero);
    expect(events.single, isA<LobbyClosedEvent>());

    events.clear();
    await s.p.pollLobbies(); // nothing watched any more
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
  });
}
