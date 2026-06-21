import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'playfab_client.dart';

/// PlayFab provider, backed by the PlayFab Client API over REST.
///
/// PlayFab is Microsoft's cross-platform backend-as-a-service. It is *not* Xbox
/// Live: a PlayFab title ships on any platform (mobile, PC, console, web) and is
/// reachable from any Dart runtime, so unlike native Xbox Live it fits the
/// pure-Dart constraint. (Xbox Live's GDK title-scoped services remain
/// deferred — see CLAUDE.md.)
///
/// Auth uses `LoginWithCustomID`: the app supplies a stable, app-chosen
/// [customId] for the player and PlayFab returns a session ticket. The title is
/// identified by its public [titleId] (no secret key — that is the server API).
///
/// Supported capabilities: leaderboards and stats (both PlayFab *player
/// statistics*), cloud save (PlayFab *user data*) and friends. PlayFab has no
/// first-class achievements API — achievements are conventionally built on
/// statistics app-side — so [GameCapability.achievements] is deliberately not
/// advertised and the achievement operations are left throwing
/// `UnimplementedError`. Rich presence and multiplayer are likewise omitted.
class PlayFabProvider extends UnifiedGameServicesPlatform {
  PlayFabProvider({
    required String titleId,
    required this.customId,
    this.displayName,
    bool createAccount = true,
    http.Client? httpClient,
    String? baseUrl,
    super.leaderboardIds,
    super.achievementIds,
  }) : _createAccount = createAccount,
       _client = PlayFabClient(
         titleId: titleId,
         httpClient: httpClient,
         baseUrl: baseUrl,
       );

  /// Creates a provider around an existing [PlayFabClient] (useful for tests).
  ///
  /// The named argument is `client` (Dart drops the leading underscore).
  PlayFabProvider.withClient({
    required PlayFabClient client,
    required this.customId,
    this.displayName,
    bool createAccount = true,
    super.leaderboardIds,
    super.achievementIds,
    // ignore_for_file: prefer_initializing_formals
  }) : _client = client,
       _createAccount = createAccount;

  /// The app-chosen stable identifier for this player (`LoginWithCustomID`).
  final String customId;

  /// Optional display name to set on the title account at first sign-in.
  final String? displayName;

  final bool _createAccount;
  final PlayFabClient _client;

  String? _playFabId;
  final StreamController<GameServiceEvent> _events =
      StreamController<GameServiceEvent>.broadcast();

  /// Registers a [PlayFabProvider] as the active platform implementation.
  static void registerWith({
    required String titleId,
    required String customId,
    String? displayName,
    bool createAccount = true,
    http.Client? httpClient,
    Map<String, String>? leaderboardIds,
  }) {
    UnifiedGameServicesPlatform.instance = PlayFabProvider(
      titleId: titleId,
      customId: customId,
      displayName: displayName,
      createAccount: createAccount,
      httpClient: httpClient,
      leaderboardIds: leaderboardIds,
    );
  }

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

  @override
  Future<bool> isSignedIn() async => _client.hasSession;

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

  @override
  Future<void> signOut() async {
    // PlayFab client sessions are stateless tickets; just drop local state.
    _client.setSessionTicket(null);
    _playFabId = null;
  }

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

  @override
  Future<Stat?> getStat(String key) async {
    final stats = await getStats();
    for (final s in stats) {
      if (s.key == key) return s;
    }
    return null;
  }

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

  @override
  Future<void> saveData(String slot, Uint8List data) async {
    await _client.post('/Client/UpdateUserData', {
      'Data': {slot: base64Encode(data)},
    });
  }

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

  @override
  Future<List<CloudSaveMetadata>> listSaves() async {
    final data = await _client.post('/Client/GetUserData', const {});
    final record = (data['Data'] as Map?)?.cast<String, dynamic>();
    if (record == null) return const [];
    return record.keys.map((k) => CloudSaveMetadata(slot: k)).toList();
  }

  @override
  Future<void> deleteSave(String slot) async {
    await _client.post('/Client/UpdateUserData', {
      'KeysToRemove': [slot],
    });
  }

  // ─── Friends ─────────────────────────────────────────────────────────────

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

  /// Closes the HTTP client and events stream.
  Future<void> dispose() async {
    _client.close();
    await _events.close();
  }

  void _emit(GameServiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
