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
    super.leaderboardIds,
    super.achievementIds,
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
    super.leaderboardIds,
    super.achievementIds,
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
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) {
    UnifiedGameServicesPlatform.instance = GameJoltProvider(
      gameId: gameId,
      privateKey: privateKey,
      username: username,
      userToken: userToken,
      httpClient: httpClient,
      leaderboardIds: leaderboardIds,
      achievementIds: achievementIds,
    );
  }

  /// Credentials shared by user-scoped requests.
  Map<String, String?> get _auth => {
    'username': username,
    'user_token': userToken,
  };

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
    final users = _mapList(response['users']);
    if (users.isEmpty) return null;
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
    final trophies = _mapList(response['trophies']);
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
    final id = resolveAchievementId(achievementId);
    await _client.get('/trophies/add-achieved/', {..._auth, 'trophy_id': id});
    _emit(
      AchievementUnlockedEvent(
        achievement: Achievement(id: id, title: id, isUnlocked: true),
        timestamp: DateTime.now(),
      ),
    );
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
    final id = resolveLeaderboardId(leaderboardId);
    await _client.get('/scores/add/', {
      ..._auth,
      'table_id': id,
      'score': '$score',
      'sort': '$score',
    });
    _emit(
      ScoreSubmittedEvent(
        leaderboardId: id,
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
    final response = await _client.get('/scores/', {
      'table_id': resolveLeaderboardId(leaderboardId),
      'limit': '$maxResults',
    });
    final scores = _mapList(response['scores']);
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < scores.length; i++) {
      final s = scores[i];
      final isGuest = s['user_id'] == null || '${s['user_id']}' == '0';
      entries.add(
        LeaderboardEntry(
          rank: i + 1,
          score: int.tryParse('${s['sort']}') ?? 0,
          formattedScore: s['score'] as String?,
          player: PlayerProfile(
            id: isGuest ? 'guest' : '${s['user_id']}',
            displayName: isGuest ? '${s['guest']}' : '${s['user']}',
          ),
        ),
      );
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
    final keys = _mapList(response['keys']);
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
    final friends = _mapList(response['friends']);
    final ids = friends.map((f) => '${f['friend_id']}').toList();
    if (ids.isEmpty) return const [];

    final users = await _client.get('/users/', {'user_id': ids.join(',')});
    final list = _mapList(users['users']);
    return list
        .map((u) => _profileFromUser(u).copyWith(isFriend: true))
        .toList();
  }

  // ─── GameJolt-specific: sessions ────────────────────────────────────────────
  //
  // Not part of the unified interface. GameJolt sessions track "playing now"
  // (online + active/idle), which is online presence rather than the rich,
  // free-text presence modeled by [RichPresence] — hence exposed here, on the
  // concrete provider, for apps that target GameJolt directly. Sessions close
  // server-side after ~120s without a ping; use [startSessionHeartbeat] to keep
  // one alive automatically.

  Timer? _heartbeat;

  /// Opens a play session for the signed-in player.
  Future<void> openSession() => _client.get('/sessions/open/', _auth);

  /// Pings the open session to keep it alive. Set [idle] when the player is
  /// present but not actively playing.
  Future<void> pingSession({bool idle = false}) => _client.get(
    '/sessions/ping/',
    {..._auth, 'status': idle ? 'idle' : 'active'},
  );

  /// Whether the player currently has an open session.
  Future<bool> isSessionOpen() async {
    final response = await _client.get(
      '/sessions/check/',
      _auth,
      throwOnFailure: false,
    );
    return GameJoltClient.isSuccess(response);
  }

  /// Closes the open session.
  Future<void> closeSession() => _client.get('/sessions/close/', _auth);

  /// Opens a session and pings it every [interval] (default 60s, safely under
  /// GameJolt's ~120s timeout). Call [stopSessionHeartbeat] to end it.
  Future<void> startSessionHeartbeat({
    Duration interval = const Duration(seconds: 60),
  }) async {
    await openSession();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(interval, (_) => pingSession());
  }

  /// Stops the heartbeat started by [startSessionHeartbeat] and closes the
  /// session.
  Future<void> stopSessionHeartbeat() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await closeSession();
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Closes the HTTP client and events stream, stopping any session heartbeat.
  Future<void> dispose() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _client.close();
    await _events.close();
  }

  void _emit(GameServiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}

/// Coerces a GameJolt list-shaped field into a list of maps.
///
/// The Game API envelope is not consistent: a field that holds a collection
/// (`friends`, `users`, `trophies`, `scores`, `keys`) can come back as a JSON
/// array, but also as `null` or even an empty string `""` when there are no
/// rows. Anything that is not a list collapses to an empty list.
List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value.cast<Map<String, dynamic>>()
    : const <Map<String, dynamic>>[];
