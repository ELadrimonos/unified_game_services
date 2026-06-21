import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'gamejolt_client.dart';

/// GameJolt provider, backed by the GameJolt Game API v1.2 over REST.
///
/// GameJolt authenticates per-player with a `username` + `userToken` (the
/// player's Game Token from their GameJolt profile), alongside the game's
/// `gameId` + `privateKey`. All four are required up front.
///
/// Supported capabilities: achievements (trophies), leaderboards (score
/// tables), cloud save (data store) and friends. GameJolt has no numeric stats
/// or rich-presence text API, so those capabilities are not advertised.
class GameJoltProvider extends UnifiedGameServicesPlatform {
  GameJoltProvider({
    required String gameId,
    required String privateKey,
    required this.username,
    required this.userToken,
    http.Client? httpClient,
    String? baseUrl,
  }) : _client = GameJoltClient(
          gameId: gameId,
          privateKey: privateKey,
          httpClient: httpClient,
          baseUrl: baseUrl ?? 'https://api.gamejolt.com/api/game/v1_2',
        );

  /// Creates a provider around an existing [GameJoltClient] (useful for tests).
  ///
  /// The named argument is `client` (Dart drops the leading underscore).
  GameJoltProvider.withClient({
    required GameJoltClient client,
    required this.username,
    required this.userToken,
    // ignore: prefer_initializing_formals
  }) : _client = client;

  /// The player's GameJolt username.
  final String username;

  /// The player's GameJolt Game Token.
  final String userToken;

  final GameJoltClient _client;
  bool _signedIn = false;
  final StreamController<GameServiceEvent> _events =
      StreamController<GameServiceEvent>.broadcast();

  /// Registers a [GameJoltProvider] as the active platform implementation.
  static void registerWith({
    required String gameId,
    required String privateKey,
    required String username,
    required String userToken,
    http.Client? httpClient,
  }) {
    UnifiedGameServicesPlatform.instance = GameJoltProvider(
      gameId: gameId,
      privateKey: privateKey,
      username: username,
      userToken: userToken,
      httpClient: httpClient,
    );
  }

  /// Credentials shared by user-scoped requests.
  Map<String, String?> get _auth =>
      {'username': username, 'user_token': userToken};

  @override
  Set<GameCapability> get capabilities => const {
        GameCapability.achievements,
        GameCapability.leaderboards,
        GameCapability.cloudSave,
        GameCapability.friends,
      };

  @override
  Stream<GameServiceEvent> get events => _events.stream;

  // ─── Authentication ──────────────────────────────────────────────────────

  @override
  Future<bool> isSignedIn() async => _signedIn;

  @override
  Future<PlayerProfile?> signIn() async {
    await _client.get('/users/auth/', _auth);
    _signedIn = true;
    final profile = await getCurrentPlayer();
    if (profile != null) {
      _emit(UserSignedInEvent(player: profile, timestamp: DateTime.now()));
    }
    return profile;
  }

  @override
  Future<void> signOut() async {
    // GameJolt auth is stateless per request; just drop local state.
    _signedIn = false;
  }

  @override
  Future<PlayerProfile?> getCurrentPlayer() async {
    final response = await _client.get('/users/', {'username': username});
    final users = (response['users'] as List?)?.cast<Map<String, dynamic>>();
    if (users == null || users.isEmpty) return null;
    return _profileFromUser(users.first);
  }

  PlayerProfile _profileFromUser(Map<String, dynamic> user) {
    final developerName = user['developer_name'] as String?;
    return PlayerProfile(
      id: '${user['id']}',
      displayName: (developerName != null && developerName.isNotEmpty)
          ? developerName
          : '${user['username']}',
      avatarUrl: user['avatar_url'] as String?,
      isOnline: user['status'] == 'active',
      extra: user,
    );
  }

  // ─── Achievements (trophies) ────────────────────────────────────────────────

  @override
  Future<List<Achievement>> getAchievements() async {
    final response = await _client.get('/trophies/', _auth);
    final trophies =
        (response['trophies'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    return trophies.map(_achievementFromTrophy).toList();
  }

  Achievement _achievementFromTrophy(Map<String, dynamic> t) {
    // `achieved` is `false` (bool/string) when locked, otherwise a human date.
    final achieved = t['achieved'];
    final unlocked = achieved != false && achieved != 'false';
    return Achievement(
      id: '${t['id']}',
      title: '${t['title']}',
      description: t['description'] as String?,
      isUnlocked: unlocked,
      iconUrl: t['image_url'] as String?,
    );
  }

  @override
  Future<void> unlockAchievement(String achievementId) async {
    await _client.get('/trophies/add-achieved/', {
      ..._auth,
      'trophy_id': achievementId,
    });
    _emit(AchievementUnlockedEvent(
      achievement: Achievement(
          id: achievementId, title: achievementId, isUnlocked: true),
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> incrementAchievement(String achievementId, int steps) async {
    // GameJolt trophies are all-or-nothing; there is no step progress.
    throw CapabilityNotSupportedException(GameCapability.achievements);
  }

  @override
  Future<void> revealAchievement(String achievementId) async {
    // GameJolt has no hidden/reveal concept; no-op.
  }

  // ─── Leaderboards (scores) ──────────────────────────────────────────────────

  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    await _client.get('/scores/add/', {
      ..._auth,
      'table_id': leaderboardId,
      'score': '$score',
      'sort': '$score',
    });
    _emit(ScoreSubmittedEvent(
      leaderboardId: leaderboardId,
      score: score,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) async {
    final response = await _client.get('/scores/', {
      'table_id': leaderboardId,
      'limit': '$maxResults',
    });
    final scores =
        (response['scores'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < scores.length; i++) {
      final s = scores[i];
      final isGuest = s['user_id'] == null || '${s['user_id']}' == '0';
      entries.add(LeaderboardEntry(
        rank: i + 1,
        score: int.tryParse('${s['sort']}') ?? 0,
        formattedScore: s['score'] as String?,
        player: PlayerProfile(
          id: isGuest ? 'guest' : '${s['user_id']}',
          displayName: isGuest ? '${s['guest']}' : '${s['user']}',
        ),
      ));
    }
    return Leaderboard(
      id: leaderboardId,
      timeScope: timeScope,
      collection: collection,
      entries: entries,
    );
  }

  // ─── Cloud save (data store) ────────────────────────────────────────────────

  @override
  Future<void> saveData(String slot, Uint8List data) async {
    await _client.get('/data-store/set/', {
      ..._auth,
      'key': slot,
      'data': base64Encode(data),
    });
  }

  @override
  Future<CloudSave?> loadData(String slot) async {
    final Map<String, dynamic> response;
    try {
      response = await _client.get('/data-store/', {..._auth, 'key': slot});
    } on GameServiceException {
      // GameJolt returns success:false for a missing key.
      return null;
    }
    final raw = response['data'] as String?;
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
    final response = await _client.get('/data-store/get-keys/', _auth);
    final keys =
        (response['keys'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return keys.map((k) => CloudSaveMetadata(slot: '${k['key']}')).toList();
  }

  @override
  Future<void> deleteSave(String slot) async {
    await _client.get('/data-store/remove/', {..._auth, 'key': slot});
  }

  // ─── Friends ─────────────────────────────────────────────────────────────

  @override
  Future<List<PlayerProfile>> getFriends() async {
    final response = await _client.get('/friends/', _auth);
    final friends =
        (response['friends'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];
    final ids = friends.map((f) => '${f['friend_id']}').toList();
    if (ids.isEmpty) return const [];

    final users = await _client.get('/users/', {'user_id': ids.join(',')});
    final list =
        (users['users'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return list
        .map((u) => _profileFromUser(u).copyWith(isFriend: true))
        .toList();
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
