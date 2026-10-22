import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'playfab_client.dart';

/// A provider for PlayFab, backed by the PlayFab Client API over REST.
///
/// PlayFab is Microsoft's cross-platform backend service. It is not Xbox Live:
/// a PlayFab title can ship on any platform and is reachable from any Dart
/// runtime, including web.
///
/// Supported capabilities: leaderboards and stats (both PlayFab *player
/// statistics*), cloud save (PlayFab *user data*), friends and lobbies (the
/// PlayFab Multiplayer Lobby REST API; see the lobby section below for how
/// searchable data and ownership map). PlayFab has no first-class achievements
/// API — achievements are conventionally built on statistics app-side — so
/// [GameCapability.achievements] is deliberately not advertised and the
/// achievement operations throw [CapabilityNotSupportedException]. Rich
/// presence, invitations and matchmaking are omitted.
///
/// **Authentication.** [signIn] calls `LoginWithCustomID`: the app supplies a
/// stable, app-chosen custom id for the player and PlayFab returns a session
/// ticket. The title is identified by its public Title ID, with no secret key
/// (that belongs to the server API). Every other operation needs [signIn] to
/// have succeeded first and throws [NotSignedInException] otherwise.
///
/// **Availability.** Pure Dart over HTTP, so it works on every platform.
/// Network failures surface as [NetworkException] and PlayFab error responses
/// as [PlatformOperationException].
class PlayFabProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'playfab';

  /// Whether PlayFab can run on the current platform.
  ///
  /// Always `true`: the provider only needs HTTP.
  static bool get isSupported => true;

  /// Creates a provider for the title with the given [titleId].
  ///
  /// [signIn] logs in with `LoginWithCustomID` using [customId]. When
  /// [createAccount] is `true`, PlayFab creates the account for an unknown
  /// [customId]. [displayName] is applied after every sign-in. [httpClient] and
  /// [baseUrl] are passed to the underlying [PlayFabClient]; the client closes
  /// [httpClient] in [dispose].
  PlayFabProvider({
    required String titleId,
    required this.customId,
    this.displayName,
    bool createAccount = true,
    http.Client? httpClient,
    String? baseUrl,
    Map<String, String> lobbySearchKeys = const {},
    Duration? lobbyPollInterval = const Duration(seconds: 5),
  }) : _createAccount = createAccount,
       _searchKeys = _validatedSearchKeys(lobbySearchKeys),
       _lobbyPollInterval = lobbyPollInterval,
       _client = PlayFabClient(
         titleId: titleId,
         httpClient: httpClient,
         baseUrl: baseUrl,
       );

  /// Creates a provider around an existing [PlayFabClient], typically one built
  /// on a mock HTTP client in tests.
  ///
  /// [dispose] closes [client]. The other parameters are as in the default
  /// constructor.
  PlayFabProvider.withClient({
    required PlayFabClient client,
    required this.customId,
    this.displayName,
    bool createAccount = true,
    Map<String, String> lobbySearchKeys = const {},
    Duration? lobbyPollInterval = const Duration(seconds: 5),
    // ignore_for_file: prefer_initializing_formals
  }) : _client = client,
       _createAccount = createAccount,
       _searchKeys = _validatedSearchKeys(lobbySearchKeys),
       _lobbyPollInterval = lobbyPollInterval;

  /// The app-chosen, stable identifier of this player, used for
  /// `LoginWithCustomID`.
  final String customId;

  /// The display name to set on the title account during [signIn], or `null`
  /// to leave it unchanged.
  ///
  /// It is applied on every sign-in, not only the first.
  final String? displayName;

  final bool _createAccount;
  final PlayFabClient _client;

  String? _playFabId;
  final StreamController<GameServiceEvent> _events =
      StreamController<GameServiceEvent>.broadcast();

  @override
  Set<GameCapability> get capabilities => const {
    GameCapability.leaderboards,
    GameCapability.stats,
    GameCapability.cloudSave,
    GameCapability.friends,
    GameCapability.lobbies,
  };

  @override
  Stream<GameServiceEvent> get events => _events.stream;

  // ─── Authentication ──────────────────────────────────────────────────────

  /// Whether a session ticket is held, meaning [signIn] succeeded and
  /// [signOut] has not been called since.
  @override
  Future<bool> isSignedIn() async => _client.hasSession;

  /// Logs in with `LoginWithCustomID`, applies [displayName] if set, loads the
  /// account and emits a [UserSignedInEvent].
  ///
  /// The profile's `id` is the PlayFab id, and `extra` holds the raw account
  /// info. Throws [SignInFailedException] when the login fails or returns no
  /// session ticket.
  @override
  Future<PlayerProfile?> signIn() async {
    final Map<String, dynamic> data;
    try {
      data = await _client.post('/Client/LoginWithCustomID', {
        'TitleId': _client.titleId,
        'CustomId': customId,
        'CreateAccount': _createAccount,
      }, authenticated: false);
    } on GameServiceException catch (e) {
      throw SignInFailedException(e.message, e);
    }

    final ticket = data['SessionTicket'] as String?;
    if (ticket == null) {
      throw const SignInFailedException('PlayFab login returned no ticket.');
    }
    _client.setSessionTicket(ticket);
    _client.setEntity((data['EntityToken'] as Map?)?.cast<String, dynamic>());
    _playFabId =
        (data['PlayFabId'] as String?) ??
        ((data['EntityToken'] as Map?)?['Entity'] as Map?)?['Id'] as String?;

    if (displayName != null) {
      await _client.post('/Client/UpdateUserTitleDisplayName', {
        'DisplayName': displayName,
      });
    }

    final profile = await getCurrentPlayer();
    if (profile != null) {
      _emit(UserSignedInEvent(player: profile, timestamp: DateTime.now()));
    }
    return profile;
  }

  /// Discards the session ticket locally.
  ///
  /// The ticket is not invalidated on the server.
  @override
  Future<void> signOut() async {
    // PlayFab client sessions are stateless tickets; just drop local state.
    _stopWatching();
    _client.setSessionTicket(null);
    _playFabId = null;
  }

  /// Loads the account info of the signed-in player.
  ///
  /// Unlike most providers this queries the server each time. Throws
  /// [NotSignedInException] before [signIn].
  @override
  Future<PlayerProfile?> getCurrentPlayer() async {
    final data = await _client.post('/Client/GetAccountInfo', const {});
    final info = (data['AccountInfo'] as Map?)?.cast<String, dynamic>();
    if (info == null) return null;
    return _profileFromAccount(info);
  }

  PlayerProfile _profileFromAccount(Map<String, dynamic> info) {
    final titleInfo = (info['TitleInfo'] as Map?)?.cast<String, dynamic>();
    final id = '${info['PlayFabId'] ?? _playFabId ?? ''}';
    return PlayerProfile(
      id: id,
      displayName: (titleInfo?['DisplayName'] as String?) ?? id,
      avatarUrl: titleInfo?['AvatarUrl'] as String?,
      extra: info,
    );
  }

  // ─── Leaderboards (player statistics) ────────────────────────────────────
  //
  // A PlayFab leaderboard is just the ranking view of a named statistic, so a
  // unified `leaderboardId` maps to a statistic name. submitScore writes the
  // statistic; getLeaderboard reads its ranked view.

  /// Writes [score] to the player statistic that backs the leaderboard.
  ///
  /// [leaderboardId] is mapped through `resolveLeaderboardId` and must be the
  /// statistic name. The new value replaces the previous one according to the
  /// statistic's aggregation method in PlayFab. The emitted
  /// [ScoreSubmittedEvent] carries the resolved name.
  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    final name = resolveLeaderboardId(leaderboardId);
    await _client.post('/Client/UpdatePlayerStatistics', {
      'Statistics': [
        {'StatisticName': name, 'Value': score},
      ],
    });
    _emit(
      ScoreSubmittedEvent(
        leaderboardId: name,
        score: score,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Returns up to [maxResults] entries of the statistic's leaderboard, from
  /// the top.
  ///
  /// Ranks are 1-based. [timeScope] and [collection] are only echoed into the
  /// returned [Leaderboard]; the query always returns the global board. PlayFab
  /// versioned statistics are not selectable.
  @override
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) async {
    final name = resolveLeaderboardId(leaderboardId);
    final data = await _client.post('/Client/GetLeaderboard', {
      'StatisticName': name,
      'StartPosition': 0,
      'MaxResultsCount': maxResults,
    });
    return Leaderboard(
      id: leaderboardId,
      timeScope: timeScope,
      collection: collection,
      entries: _entries(data['Leaderboard']),
    );
  }

  /// Returns the player's entry, or `null` when the board has no entries.
  ///
  /// Queries the one-entry window around the player. [timeScope] is ignored.
  /// If the window does not contain the player, the first returned entry is
  /// used instead.
  @override
  Future<LeaderboardEntry?> getPlayerScore(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
  }) async {
    final name = resolveLeaderboardId(leaderboardId);
    final data = await _client.post('/Client/GetLeaderboardAroundPlayer', {
      'StatisticName': name,
      'MaxResultsCount': 1,
    });
    final entries = _entries(data['Leaderboard']);
    if (entries.isEmpty) return null;
    // The requested player is the centre of the returned window.
    return entries.firstWhere(
      (e) => e.player.id == _playFabId,
      orElse: () => entries.first,
    );
  }

  List<LeaderboardEntry> _entries(dynamic raw) {
    final rows = raw is List ? raw.cast<Map<String, dynamic>>() : const [];
    return rows.map((row) {
      final profile = (row['Profile'] as Map?)?.cast<String, dynamic>();
      final id = '${row['PlayFabId'] ?? ''}';
      return LeaderboardEntry(
        // PlayFab `Position` is 0-based; expose 1-based ranks.
        rank: ((row['Position'] as int?) ?? 0) + 1,
        score: (row['StatValue'] as int?) ?? 0,
        player: PlayerProfile(
          id: id,
          displayName:
              (row['DisplayName'] as String?) ??
              (profile?['DisplayName'] as String?) ??
              id,
        ),
      );
    }).toList();
  }

  // ─── Stats (player statistics) ─────────────────────────────────────────────

  /// Returns the player's statistics.
  ///
  /// Keys are PlayFab statistic names.
  @override
  Future<List<Stat>> getStats() async {
    final data = await _client.post('/Client/GetPlayerStatistics', const {});
    final raw = data['Statistics'];
    final rows = raw is List ? raw.cast<Map<String, dynamic>>() : const [];
    return rows
        .map(
          (s) => Stat(
            key: '${s['StatisticName']}',
            value: (s['Value'] as num?) ?? 0,
          ),
        )
        .toList();
  }

  /// Returns the statistic [key], or `null` when the player has no value.
  ///
  /// Fetches every statistic and filters. [key] is mapped through
  /// `resolveStatId` to the PlayFab statistic name.
  @override
  Future<Stat?> getStat(String key) async {
    final name = resolveStatId(key);
    final stats = await getStats();
    for (final s in stats) {
      if (s.key == name) return s;
    }
    return null;
  }

  /// Writes the statistic [key] and emits a [StatUpdatedEvent].
  ///
  /// PlayFab receives [value] truncated to an integer; the event carries the
  /// original [value]. The stored result follows the statistic's aggregation
  /// method in PlayFab. [key] is mapped through `resolveStatId`; the event
  /// carries the resolved name.
  @override
  Future<void> setStat(String key, num value) async {
    final name = resolveStatId(key);
    await _client.post('/Client/UpdatePlayerStatistics', {
      'Statistics': [
        {'StatisticName': name, 'Value': value.toInt()},
      ],
    });
    _emit(
      StatUpdatedEvent(
        stat: Stat(key: name, value: value),
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Reads the statistic, treating a missing one as zero, then writes the sum.
  ///
  /// The read-modify-write is not atomic.
  @override
  Future<void> incrementStat(String key, {num by = 1}) async {
    // PlayFab statistics are absolute; read-modify-write to increment.
    final current = await getStat(key);
    await setStat(key, (current?.value ?? 0) + by);
  }

  // ─── Cloud save (user data) ─────────────────────────────────────────────────
  //
  // PlayFab user data is a key→string store; binary payloads are base64-encoded
  // (following the GameJolt data-store convention).

  /// Stores [data] base64-encoded in the player's user data under the key
  /// [slot].
  @override
  Future<void> saveData(String slot, Uint8List data) async {
    await _client.post('/Client/UpdateUserData', {
      'Data': {slot: base64Encode(data)},
    });
  }

  /// Reads the user-data key [slot], or returns `null` when it is absent.
  ///
  /// Values not written by [saveData] and not valid base64 are returned as
  /// their UTF-8 bytes.
  @override
  Future<CloudSave?> loadData(String slot) async {
    final data = await _client.post('/Client/GetUserData', {
      'Keys': [slot],
    });
    final record = (data['Data'] as Map?)?.cast<String, dynamic>();
    final entry = (record?[slot] as Map?)?.cast<String, dynamic>();
    final raw = entry?['Value'] as String?;
    if (raw == null) return null;
    final bytes = _decodeStore(raw);
    return CloudSave.fromBytes(
      metadata: CloudSaveMetadata(slot: slot, sizeBytes: bytes.length),
      bytes: bytes,
    );
  }

  /// Stored payloads are base64 written by [saveData]; tolerate plain strings
  /// written outside this provider.
  Uint8List _decodeStore(String raw) {
    try {
      return base64Decode(raw);
    } on FormatException {
      return Uint8List.fromList(utf8.encode(raw));
    }
  }

  /// Lists the keys of the player's user data.
  ///
  /// Only the slot is set; sizes are not fetched.
  @override
  Future<List<CloudSaveMetadata>> listSaves() async {
    final data = await _client.post('/Client/GetUserData', const {});
    final record = (data['Data'] as Map?)?.cast<String, dynamic>();
    if (record == null) return const [];
    return record.keys.map((k) => CloudSaveMetadata(slot: k)).toList();
  }

  /// Removes the user-data key [slot].
  @override
  Future<void> deleteSave(String slot) async {
    await _client.post('/Client/UpdateUserData', {
      'KeysToRemove': [slot],
    });
  }

  // ─── Friends ─────────────────────────────────────────────────────────────

  /// Returns the player's PlayFab friends.
  ///
  /// Profiles carry the friend's PlayFab id and title display name, with the
  /// raw friend record in `extra`.
  @override
  Future<List<PlayerProfile>> getFriends() async {
    final data = await _client.post('/Client/GetFriendsList', const {});
    final raw = data['Friends'];
    final rows = raw is List ? raw.cast<Map<String, dynamic>>() : const [];
    return rows.map((f) {
      final id = '${f['FriendPlayFabId'] ?? ''}';
      return PlayerProfile(
        id: id,
        displayName: (f['TitleDisplayName'] as String?) ?? id,
        isFriend: true,
        extra: f,
      );
    }).toList();
  }

  // ─── Lobbies (PlayFab Multiplayer Lobby API) ─────────────────────────────
  //
  // Lobby calls use the entity token (`X-EntityToken`) of the signed-in
  // `title_player_account`, refreshed through `Authentication/GetEntityToken`.
  //
  // Mapping and limits of this REST-only implementation:
  //  * Lobbies are created with `UseConnections: false` and owner migration
  //    `None`. Searchable lobbies otherwise need a live PubSub connection, which
  //    needs a SignalR client; without it `findLobbies` would return nothing.
  //    The cost: PlayFab never migrates ownership for you.
  //  * PlayFab keeps *searchable* data apart from regular lobby data, and
  //    searchable keys must be named `string_key1..30` / `number_key1..30`.
  //    [lobbySearchKeys] maps unified data keys onto those names; mapped keys go
  //    to searchable data, every other key to regular lobby data.
  //  * `Lobby.joinToken` is PlayFab's connection string. Member ids are
  //    title-player entity ids (see [entityId]), not `PlayFabId`s.
  //  * Events come from polling [pollLobbies] every [lobbyPollInterval]; invites
  //    need PubSub so `invitations` is not advertised.

  final Map<String, String> _searchKeys;
  final Duration? _lobbyPollInterval;
  final Map<String, Lobby> _watched = {};
  Timer? _poller;
  var _polling = false;

  static final RegExp _searchKeyPattern = RegExp(
    r'^(string|number)_key([1-9]|[12][0-9]|30)$',
  );

  static Map<String, String> _validatedSearchKeys(Map<String, String> keys) {
    for (final e in keys.entries) {
      if (!_searchKeyPattern.hasMatch(e.value)) {
        throw ArgumentError.value(
          e.value,
          'lobbySearchKeys["${e.key}"]',
          'must be string_key1..30 or number_key1..30',
        );
      }
    }
    return Map.unmodifiable(keys);
  }

  /// The signed-in player's `title_player_account` entity id: the id of this
  /// player as a lobby member and owner. `null` before sign-in.
  String? get entityId => _client.entityId;

  Map<String, String> get _entityKey => {
    'Id': _client.entityId!,
    'Type': _client.entityType ?? 'title_player_account',
  };

  Future<Map<String, dynamic>> _lobbyPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    await _ensureEntity();
    return _client.post(endpoint, body, useEntityToken: true);
  }

  /// Splits unified [data] into PlayFab lobby data and searchable data.
  ({Map<String, String> lobby, Map<String, Object> search}) _splitData(
    Map<String, String> data,
  ) {
    final lobby = <String, String>{};
    final search = <String, Object>{};
    data.forEach((key, value) {
      final searchKey = _searchKeys[key];
      if (searchKey == null) {
        lobby[key] = value;
      } else {
        search[searchKey] = searchKey.startsWith('number_')
            ? (num.tryParse(value) ??
                  (throw ArgumentError.value(
                    value,
                    key,
                    'must be numeric ($searchKey)',
                  )))
            : value;
      }
    });
    return (lobby: lobby, search: search);
  }

  static String _text(Object? v) =>
      v is num && v == v.truncate() ? '${v.toInt()}' : '$v';

  Map<String, String> _unifiedSearchData(Map<String, dynamic>? search) {
    final unified = {for (final e in _searchKeys.entries) e.value: e.key};
    return {
      for (final e in (search ?? const <String, dynamic>{}).entries)
        unified[e.key] ?? e.key: _text(e.value),
    };
  }

  static const _policyToVisibility = {
    'Public': LobbyVisibility.public,
    'Friends': LobbyVisibility.friendsOnly,
    'Private': LobbyVisibility.private,
  };

  static String _policy(LobbyVisibility v) => switch (v) {
    LobbyVisibility.public => 'Public',
    LobbyVisibility.friendsOnly => 'Friends',
    LobbyVisibility.private => 'Private',
  };

  PlayerProfile _entityProfile(Map<String, dynamic> key) {
    final id = '${key['Id']}';
    return PlayerProfile(
      id: id,
      displayName: id,
      extra: {'entityType': key['Type']},
    );
  }

  Lobby _lobbyFromJson(Map<String, dynamic> j) {
    final owner = (j['Owner'] as Map?)?.cast<String, dynamic>();
    final lobbyData = {
      for (final e in ((j['LobbyData'] as Map?) ?? const {}).entries)
        '${e.key}': _text(e.value),
    };
    final kindName = lobbyData.remove(lobbyKindDataKey);
    return Lobby(
      id: j['LobbyId'] as String,
      providerId: providerId,
      joinToken: j['ConnectionString'] as String? ?? '',
      ownerId: owner == null ? '' : '${owner['Id']}',
      members: [
        for (final m in (j['Members'] as List? ?? const []))
          LobbyMember(
            player: _entityProfile(
              ((m as Map)['MemberEntity'] as Map).cast<String, dynamic>(),
            ),
            data: {
              for (final e in ((m['MemberData'] as Map?) ?? const {}).entries)
                '${e.key}': _text(e.value),
            },
          ),
      ],
      maxMembers: (j['MaxPlayers'] as num?)?.toInt() ?? 0,
      visibility:
          _policyToVisibility[j['AccessPolicy']] ?? LobbyVisibility.public,
      kind: LobbyKind.values.asNameMap()[kindName] ?? LobbyKind.lobby,
      data: {
        ...lobbyData,
        ..._unifiedSearchData((j['SearchData'] as Map?)?.cast()),
      },
    );
  }

  @override
  Future<Lobby> createLobby({
    int maxMembers = 4,
    LobbyVisibility visibility = LobbyVisibility.friendsOnly,
    LobbyKind kind = LobbyKind.lobby,
    Map<String, String> data = const {},
    Map<String, String> memberData = const {},
  }) async {
    final split = _splitData({
      ...data,
      if (kind != LobbyKind.lobby) lobbyKindDataKey: kind.name,
    });
    await _ensureEntity();
    final created = await _lobbyPost('/Lobby/CreateLobby', {
      'MaxPlayers': maxMembers,
      'Owner': _entityKey,
      'UseConnections': false,
      'OwnerMigrationPolicy': 'None',
      'RestrictInvitesToLobbyOwner': false,
      'AccessPolicy': _policy(visibility),
      if (split.lobby.isNotEmpty) 'LobbyData': split.lobby,
      if (split.search.isNotEmpty) 'SearchData': split.search,
      'Members': [
        {'MemberEntity': _entityKey, 'MemberData': memberData},
      ],
    });
    return _fetchAndWatch(created['LobbyId'] as String);
  }

  @override
  Future<Lobby> joinLobby(
    String joinToken, {
    Map<String, String> memberData = const {},
  }) async {
    await _ensureEntity();
    final joined = await _lobbyPost('/Lobby/JoinLobby', {
      'ConnectionString': joinToken,
      'MemberData': memberData,
      'MemberEntity': _entityKey,
    });
    return _fetchAndWatch(joined['LobbyId'] as String);
  }

  @override
  Future<void> leaveLobby(String lobbyId) async {
    await _ensureEntity();
    _watched.remove(lobbyId);
    if (_watched.isEmpty) _stopPolling();
    await _lobbyPost('/Lobby/LeaveLobby', {
      'LobbyId': lobbyId,
      'MemberEntity': _entityKey,
    });
  }

  @override
  Future<Lobby?> getLobby(String lobbyId) async {
    try {
      final res = await _lobbyPost('/Lobby/GetLobby', {'LobbyId': lobbyId});
      return _lobbyFromJson((res['Lobby'] as Map).cast<String, dynamic>());
    } on PlatformOperationException catch (e) {
      if (e.code == '13000') return null; // LobbyDoesNotExist
      rethrow;
    }
  }

  @override
  Future<List<Lobby>> findLobbies({
    List<LobbyFilter> filters = const [],
    int maxResults = 25,
  }) async {
    final res = await _lobbyPost('/Lobby/FindLobbies', {
      if (filters.isNotEmpty)
        'Filter': filters.map(_filterClause).join(' and '),
      'Pagination': {'PageSizeRequested': maxResults.clamp(1, 50)},
    });
    return [
      for (final l in (res['Lobbies'] as List? ?? const []))
        _summaryFromJson((l as Map).cast<String, dynamic>()),
    ];
  }

  Lobby _summaryFromJson(Map<String, dynamic> j) {
    final owner = (j['Owner'] as Map?)?.cast<String, dynamic>();
    return Lobby(
      id: j['LobbyId'] as String,
      providerId: providerId,
      joinToken: j['ConnectionString'] as String? ?? '',
      ownerId: owner == null ? '' : '${owner['Id']}',
      memberCount: (j['CurrentPlayers'] as num?)?.toInt() ?? 0,
      maxMembers: (j['MaxPlayers'] as num?)?.toInt() ?? 0,
      visibility: LobbyVisibility.public,
      data: _unifiedSearchData((j['SearchData'] as Map?)?.cast()),
    );
  }

  String _filterClause(LobbyFilter f) {
    final key =
        _searchKeys[f.key] ??
        (_searchKeyPattern.hasMatch(f.key) ? f.key : null);
    if (key == null) {
      throw ArgumentError.value(
        f.key,
        'filters',
        'is not searchable; map it in lobbySearchKeys',
      );
    }
    final op = switch (f.op) {
      LobbyFilterOp.equals => 'eq',
      LobbyFilterOp.notEquals => 'ne',
      LobbyFilterOp.lessThan => 'lt',
      LobbyFilterOp.greaterThan => 'gt',
    };
    if (key.startsWith('number_')) {
      final n = num.tryParse(f.value);
      if (n == null) {
        throw ArgumentError.value(f.value, f.key, 'must be numeric ($key)');
      }
      return '$key $op $n';
    }
    if (f.op == LobbyFilterOp.lessThan || f.op == LobbyFilterOp.greaterThan) {
      throw ArgumentError.value(
        f.op,
        f.key,
        'numeric comparison needs a number_key, but $key is a string key',
      );
    }
    return "$key $op '${f.value.replaceAll("'", "''")}'";
  }

  @override
  Future<Lobby> updateLobby(
    String lobbyId, {
    Map<String, String?>? data,
    LobbyVisibility? visibility,
    int? maxMembers,
  }) async {
    final set = <String, String>{};
    final remove = <String>[];
    data?.forEach((k, v) => v == null ? remove.add(k) : set[k] = v);
    final splitSet = _splitData(set);
    final removeSearch = [
      for (final k in remove)
        if (_searchKeys.containsKey(k)) _searchKeys[k]!,
    ];
    final removeLobby = [
      for (final k in remove)
        if (!_searchKeys.containsKey(k)) k,
    ];
    await _lobbyPost('/Lobby/UpdateLobby', {
      'LobbyId': lobbyId,
      if (splitSet.lobby.isNotEmpty) 'LobbyData': splitSet.lobby,
      if (splitSet.search.isNotEmpty) 'SearchData': splitSet.search,
      if (removeLobby.isNotEmpty) 'LobbyDataToDelete': removeLobby,
      if (removeSearch.isNotEmpty) 'SearchDataToDelete': removeSearch,
      if (visibility case final v?) 'AccessPolicy': _policy(v),
      'MaxPlayers': ?maxMembers,
    });
    return _refetch(lobbyId);
  }

  @override
  Future<Lobby> setMemberData(String lobbyId, Map<String, String?> data) async {
    await _ensureEntity();
    await _lobbyPost('/Lobby/UpdateLobby', {
      'LobbyId': lobbyId,
      'MemberEntity': _entityKey,
      'MemberData': {for (final e in data.entries) e.key: ?e.value},
      'MemberDataToDelete': [
        for (final e in data.entries)
          if (e.value == null) e.key,
      ],
    });
    return _refetch(lobbyId);
  }

  Future<void> _ensureEntity() async {
    if (!_client.hasSession) {
      throw const NotSignedInException(
        'PlayFab session ticket missing; call signIn() first.',
      );
    }
    if (_client.entityId == null || _client.entityTokenStale) {
      _client.setEntity(
        await _client.post('/Authentication/GetEntityToken', const {}),
      );
    }
  }

  Future<Lobby> _refetch(String lobbyId) async {
    final lobby = await getLobby(lobbyId);
    if (lobby == null) {
      throw const PlatformOperationException('The lobby no longer exists.');
    }
    if (_watched.containsKey(lobbyId)) _watched[lobbyId] = lobby;
    return lobby;
  }

  Future<Lobby> _fetchAndWatch(String lobbyId) async {
    final lobby = await _refetch(lobbyId);
    _watched[lobbyId] = lobby;
    final interval = _lobbyPollInterval;
    if (interval != null) {
      _poller ??= Timer.periodic(interval, (_) => pollLobbies());
    }
    return lobby;
  }

  /// Fetches every lobby this provider joined and emits the lobby events for
  /// what changed since the last look. Called on a timer every
  /// `lobbyPollInterval`; call it yourself when polling is disabled (`null`).
  Future<void> pollLobbies() async {
    if (_polling) return;
    _polling = true;
    try {
      for (final id in _watched.keys.toList()) {
        final old = _watched[id];
        if (old == null) continue;
        final Lobby? current;
        try {
          current = await getLobby(id);
        } on GameServiceException {
          continue; // transient; try again on the next tick
        }
        if (current == null) {
          _watched.remove(id);
          _emit(LobbyClosedEvent(lobby: old, timestamp: DateTime.now()));
          continue;
        }
        _watched[id] = current;
        _diffLobby(old, current);
      }
      if (_watched.isEmpty) _stopPolling();
    } finally {
      _polling = false;
    }
  }

  void _diffLobby(Lobby old, Lobby current) {
    final now = DateTime.now();
    final before = {for (final m in old.members) m.player.id: m};
    final after = {for (final m in current.members) m.player.id: m};
    for (final e in after.entries) {
      if (!before.containsKey(e.key)) {
        _emit(
          LobbyMemberJoinedEvent(
            lobby: current,
            member: e.value,
            timestamp: now,
          ),
        );
      }
    }
    for (final e in before.entries) {
      if (!after.containsKey(e.key)) {
        _emit(
          LobbyMemberLeftEvent(lobby: current, member: e.value, timestamp: now),
        );
      }
    }
    if (old.ownerId != current.ownerId) {
      _emit(
        LobbyOwnerChangedEvent(
          lobby: current,
          previousOwnerId: old.ownerId,
          timestamp: now,
        ),
      );
    }
    final memberDataChanged = after.entries.any(
      (e) =>
          before[e.key] != null &&
          before[e.key]!.data.toString() != e.value.data.toString(),
    );
    if (memberDataChanged ||
        old.data.toString() != current.data.toString() ||
        old.visibility != current.visibility ||
        old.maxMembers != current.maxMembers) {
      _emit(LobbyDataChangedEvent(lobby: current, timestamp: now));
    }
  }

  void _stopPolling() {
    _poller?.cancel();
    _poller = null;
  }

  void _stopWatching() {
    _watched.clear();
    _stopPolling();
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Closes the HTTP client and closes [events].
  @override
  Future<void> dispose() async {
    // PlayFab does not detect disconnects here (no PubSub), so leave the lobbies
    // we joined; best effort, a failure must not block shutting down.
    for (final id in _watched.keys.toList()) {
      try {
        await leaveLobby(id);
      } on GameServiceException {
        // Already gone or offline.
      }
    }
    _stopWatching();
    _client.close();
    await _events.close();
  }

  void _emit(GameServiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
