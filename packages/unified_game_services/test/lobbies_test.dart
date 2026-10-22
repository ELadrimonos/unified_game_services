import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:test/test.dart';
import 'package:unified_game_services/unified_game_services.dart';

/// An in-memory lobby backend: the smallest provider that honours the contract.
class MemoryLobbyProvider extends UnifiedGameServicesPlatform
    with MockPlatformInterfaceMixin {
  MemoryLobbyProvider(this.name, {Set<GameCapability>? caps})
    : capabilities = caps ?? {GameCapability.lobbies};

  final String name;
  final Map<String, Lobby> lobbies = {};
  final List<String> invited = [];
  var _next = 0;

  @override
  String get providerId => name;

  @override
  final Set<GameCapability> capabilities;

  final _me = const PlayerProfile(id: 'me', displayName: 'Me');

  @override
  Future<Lobby> createLobby({
    int maxMembers = 4,
    LobbyVisibility visibility = LobbyVisibility.friendsOnly,
    LobbyKind kind = LobbyKind.lobby,
    Map<String, String> data = const {},
    Map<String, String> memberData = const {},
  }) async {
    final id = '$name-${_next++}';
    return lobbies[id] = Lobby(
      id: id,
      providerId: name,
      joinToken: 'tok-$id',
      ownerId: _me.id,
      members: [LobbyMember(player: _me, data: memberData)],
      maxMembers: maxMembers,
      visibility: visibility,
      kind: kind,
      data: data,
    );
  }

  Lobby _byToken(String token) =>
      lobbies.values.firstWhere((l) => l.joinToken == token);

  @override
  Future<Lobby> joinLobby(
    String joinToken, {
    Map<String, String> memberData = const {},
  }) async {
    final l = _byToken(joinToken);
    return lobbies[l.id] = l.copyWith(
      members: [
        ...l.members,
        LobbyMember(
          player: const PlayerProfile(id: 'guest', displayName: 'Guest'),
          data: memberData,
        ),
      ],
    );
  }

  @override
  Future<void> leaveLobby(String lobbyId) async => lobbies.remove(lobbyId);

  @override
  Future<Lobby?> getLobby(String lobbyId) async => lobbies[lobbyId];

  @override
  Future<List<Lobby>> findLobbies({
    List<LobbyFilter> filters = const [],
    int maxResults = 25,
  }) async => [
    for (final l in lobbies.values)
      if (l.visibility == LobbyVisibility.public &&
          filters.every(
            (f) => f.op == LobbyFilterOp.equals && l.data[f.key] == f.value,
          ))
        l,
  ].take(maxResults).toList();

  @override
  Future<Lobby> updateLobby(
    String lobbyId, {
    Map<String, String?>? data,
    LobbyVisibility? visibility,
    int? maxMembers,
  }) async {
    final l = lobbies[lobbyId]!;
    final merged = {...l.data};
    data?.forEach((k, v) => v == null ? merged.remove(k) : merged[k] = v);
    return lobbies[lobbyId] = l.copyWith(
      data: merged,
      visibility: visibility,
      maxMembers: maxMembers,
    );
  }

  @override
  Future<void> sendInvitation(String lobbyId, String userId) async =>
      invited.add('$lobbyId:$userId');
}

void main() {
  late MemoryLobbyProvider playfab;
  late MemoryLobbyProvider steam;
  late UnifiedGameServices services;

  setUp(() {
    playfab = MemoryLobbyProvider(
      'playfab',
      caps: {GameCapability.lobbies, GameCapability.invitations},
    );
    steam = MemoryLobbyProvider('steam');
    services = UnifiedGameServices(providers: [playfab, steam]);
  });

  test(
    'lobby calls go to the first provider with lobbies, never fan out',
    () async {
      final lobby = await services.createLobby(data: {'mode': 'ranked'});
      expect(lobby.providerId, 'playfab');
      expect(playfab.lobbies, hasLength(1));
      expect(steam.lobbies, isEmpty);
    },
  );

  test('createLobby passes the kind through', () async {
    final party = await services.createLobby(kind: LobbyKind.party);
    expect(party.kind, LobbyKind.party);
    expect((await services.createLobby()).kind, LobbyKind.lobby);
  });

  test('on: targets a specific provider', () async {
    final lobby = await services.createLobby(on: steam);
    expect(lobby.providerId, 'steam');
    expect(steam.lobbies, hasLength(1));
  });

  test('operations on a lobby route by its providerId', () async {
    final steamLobby = await services.createLobby(on: steam);
    final updated = await services.updateLobby(steamLobby, data: {'k': 'v'});
    expect(updated.data, {'k': 'v'});
    expect(steam.lobbies[steamLobby.id]!.data, {'k': 'v'});
    expect(playfab.lobbies, isEmpty);

    await services.leaveLobby(steamLobby);
    expect(steam.lobbies, isEmpty);
    expect(await services.refreshLobby(steamLobby), isNull);
  });

  test('joinLobby takes a join token and tags members', () async {
    final lobby = await services.createLobby();
    final joined = await services.joinLobby(lobby.joinToken);
    expect(joined.members, hasLength(2));
    expect(
      joined.members.every((m) => m.player.providerId == 'playfab'),
      isTrue,
    );
  });

  test('findLobbies returns only public matches', () async {
    await services.createLobby(
      visibility: LobbyVisibility.public,
      data: {'mode': 'ranked'},
    );
    await services.createLobby(
      visibility: LobbyVisibility.public,
      data: {'mode': 'casual'},
    );
    await services.createLobby(data: {'mode': 'ranked'});

    final found = await services.findLobbies(
      filters: [const LobbyFilter('mode', LobbyFilterOp.equals, 'ranked')],
    );
    expect(found, hasLength(1));
    expect(found.single.providerId, 'playfab');
  });

  test(
    'sendInvitation needs the invitations capability on the lobby owner',
    () async {
      final pf = await services.createLobby();
      await services.sendInvitation(pf, 'friend');
      expect(playfab.invited, ['${pf.id}:friend']);

      final st = await services.createLobby(on: steam);
      expect(
        services.sendInvitation(st, 'friend'),
        throwsA(isA<CapabilityNotSupportedException>()),
      );
    },
  );

  test('no provider with lobbies throws CapabilityNotSupportedException', () {
    final none = UnifiedGameServices(
      providers: [MemoryLobbyProvider('x', caps: {})],
    );
    expect(none.createLobby(), throwsA(isA<CapabilityNotSupportedException>()));
  });

  test('a lobby from an unregistered provider is rejected', () async {
    final lobby = await services.createLobby();
    final other = UnifiedGameServices(providers: [steam]);
    expect(() => other.leaveLobby(lobby), throwsArgumentError);
  });
}
