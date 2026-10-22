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
/// Advertises [GameCapability.leaderboards] and [GameCapability.stats] (both
/// backed by PlayFab player statistics), [GameCapability.cloudSave] (PlayFab
/// user data) and [GameCapability.friends]. PlayFab has no first-class
/// achievements API, so [GameCapability.achievements] is not advertised and the
/// achievement operations keep the base behaviour of throwing
/// [UnimplementedError]. Rich presence is not supported either.
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
  }) : _createAccount = createAccount,
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
    // ignore_for_file: prefer_initializing_formals
  }) : _client = client,
       _createAccount = createAccount;

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
  /// Fetches every statistic and filters. [key] is not mapped through
  /// `resolveStatId`.
  @override
  Future<Stat?> getStat(String key) async {
    final stats = await getStats();
    for (final s in stats) {
      if (s.key == key) return s;
    }
    return null;
  }

  /// Writes the statistic [key] and emits a [StatUpdatedEvent].
  ///
  /// PlayFab receives [value] truncated to an integer; the event carries the
  /// original [value]. The stored result follows the statistic's aggregation
  /// method in PlayFab. [key] is not mapped through `resolveStatId`.
  @override
  Future<void> setStat(String key, num value) async {
    await _client.post('/Client/UpdatePlayerStatistics', {
      'Statistics': [
        {'StatisticName': key, 'Value': value.toInt()},
      ],
    });
    _emit(
      StatUpdatedEvent(
        stat: Stat(key: key, value: value),
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

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Closes the HTTP client and closes [events].
  @override
  Future<void> dispose() async {
    _client.close();
    await _events.close();
  }

  void _emit(GameServiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
