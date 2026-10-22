import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'gamejolt_client.dart';

/// A provider for GameJolt, backed by the GameJolt Game API v1.2 over REST.
///
/// Advertises [GameCapability.achievements] (trophies),
/// [GameCapability.leaderboards] (score tables), [GameCapability.cloudSave]
/// (data store) and [GameCapability.friends]. GameJolt has no numeric stats or
/// rich-presence text API, so stats and presence are not advertised.
///
/// **Credentials.** The provider is bound to one player up front: the game's
/// `gameId` and `privateKey` from the GameJolt dashboard, and the player's
/// `username` and `userToken` (their Game Token). The private key signs
/// requests and is never sent, but any app that embeds it can be unpacked, so
/// keep it out of source control.
///
/// **Availability.** Pure Dart over HTTP, so it works on every platform
/// including web. Network failures surface as [NetworkException] and API
/// failures as [PlatformOperationException].
///
/// **GameJolt-specific extras** that are not part of the unified interface:
/// [openSession], [pingSession], [isSessionOpen], [closeSession],
/// [startSessionHeartbeat] and [stopSessionHeartbeat]. GameJolt sessions model
/// online presence (playing now, active or idle), not the free-text
/// [RichPresence] of the unified API. Reach them with
/// `GameServices.provider<GameJoltProvider>()`.
class GameJoltProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'gamejolt';

  /// Whether GameJolt can run on the current platform.
  ///
  /// Always `true`: the provider only needs HTTP.
  static bool get isSupported => true;

  /// Creates a provider from raw GameJolt credentials.
  ///
  /// [gameId] and [privateKey] come from the game's dashboard; [username] and
  /// [userToken] belong to the player. [httpClient] and [baseUrl] are passed to
  /// the underlying [GameJoltClient]; the client closes [httpClient] in
  /// [dispose].
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

  /// Creates a provider around an existing [GameJoltClient], typically one
  /// built on a mock HTTP client in tests.
  ///
  /// [dispose] closes [client].
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

  /// Whether [signIn] succeeded since construction or the last [signOut].
  ///
  /// This is local state; GameJolt authenticates every request statelessly.
  @override
  Future<bool> isSignedIn() async => _signedIn;

  /// Verifies the credentials with `/users/auth/`, then loads the profile and
  /// emits a [UserSignedInEvent].
  ///
  /// Throws [PlatformOperationException] when GameJolt rejects the username or
  /// Game Token. The profile's `id` is the numeric GameJolt user id, and
  /// `extra` holds the raw user record.
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

  /// Resets the local signed-in flag.
  ///
  /// GameJolt has no server-side sign-out, and an open session is not closed;
  /// use [closeSession] or [stopSessionHeartbeat] for that.
  @override
  Future<void> signOut() async {
    // GameJolt auth is stateless per request; just drop local state.
    _signedIn = false;
  }

  /// Looks up the player by username, whether or not [signIn] has been
  /// called.
  ///
  /// Returns `null` when GameJolt finds no such user. The display name is the
  /// developer name when set, otherwise the username.
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

  /// Returns the game's trophies with the player's unlock state.
  ///
  /// Trophies have no hidden flag or progress here, so `isHidden` and the step
  /// counts stay at their defaults.
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

  /// Marks the trophy as achieved and emits an [AchievementUnlockedEvent].
  ///
  /// [achievementId] is mapped through `resolveAchievementId` and must be the
  /// numeric trophy id. The event's achievement is a stub that uses the id as
  /// the title.
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

  /// Always throws [CapabilityNotSupportedException]: GameJolt trophies are
  /// all-or-nothing.
  @override
  Future<void> incrementAchievement(String achievementId, int steps) async {
    // GameJolt trophies are all-or-nothing; there is no step progress.
    throw CapabilityNotSupportedException(GameCapability.achievements);
  }

  /// Does nothing: GameJolt trophies have no hidden state to reveal.
  @override
  Future<void> revealAchievement(String achievementId) async {
    // GameJolt has no hidden/reveal concept; no-op.
  }

  // ─── Leaderboards (scores) ──────────────────────────────────────────────────

  /// Adds a score entry to the score table, with [score] as both the display
  /// text and the sort value.
  ///
  /// [leaderboardId] is mapped through `resolveLeaderboardId` and must be the
  /// numeric `table_id`. The emitted [ScoreSubmittedEvent] carries the resolved
  /// table id.
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

  /// Returns up to [maxResults] scores of the table, best first.
  ///
  /// [timeScope] and [collection] are only echoed into the returned
  /// [Leaderboard]; the query always returns the global table. Entries are
  /// ranked by position in the response. Guest scores appear with the player
  /// id `guest`.
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

  /// Stores [data] base64-encoded under the player's data-store key [slot].
  @override
  Future<void> saveData(String slot, Uint8List data) async {
    await _client.get('/data-store/set/', {
      ..._auth,
      'key': slot,
      'data': base64Encode(data),
    });
  }

  /// Reads the data-store key [slot], or returns `null` when it is missing.
  ///
  /// Any [GameServiceException] from the lookup, not only a missing key, yields
  /// `null`. Values not written by [saveData] and not valid base64 are returned
  /// as their UTF-8 bytes.
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

  /// Lists the player's data-store keys.
  ///
  /// GameJolt does not report sizes here, so only the slot is set.
  @override
  Future<List<CloudSaveMetadata>> listSaves() async {
    final response = await _client.get('/data-store/get-keys/', _auth);
    final keys = _mapList(response['keys']);
    return keys.map((k) => CloudSaveMetadata(slot: '${k['key']}')).toList();
  }

  /// Removes the data-store key [slot].
  @override
  Future<void> deleteSave(String slot) async {
    await _client.get('/data-store/remove/', {..._auth, 'key': slot});
  }

  // ─── Friends ─────────────────────────────────────────────────────────────

  /// Returns the player's friends as full profiles.
  ///
  /// Costs two requests: the friend id list, then one batched user lookup.
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

  /// Opens a play session for the player.
  ///
  /// GameJolt-specific, not part of the unified interface. Sessions close
  /// server-side after about 120 seconds without a ping.
  Future<void> openSession() => _client.get('/sessions/open/', _auth);

  /// Pings the open session to keep it alive.
  ///
  /// Set [idle] when the player is present but not actively playing.
  /// GameJolt-specific, not part of the unified interface.
  Future<void> pingSession({bool idle = false}) => _client.get(
    '/sessions/ping/',
    {..._auth, 'status': idle ? 'idle' : 'active'},
  );

  /// Whether the player currently has an open session.
  ///
  /// GameJolt-specific, not part of the unified interface.
  Future<bool> isSessionOpen() async {
    final response = await _client.get(
      '/sessions/check/',
      _auth,
      throwOnFailure: false,
    );
    return GameJoltClient.isSuccess(response);
  }

  /// Closes the open session.
  ///
  /// GameJolt-specific, not part of the unified interface.
  Future<void> closeSession() => _client.get('/sessions/close/', _auth);

  /// Opens a session and pings it every [interval] as active.
  ///
  /// The default of 60 seconds is safely under GameJolt's timeout of about 120
  /// seconds. Ping failures are not reported. Call [stopSessionHeartbeat] to
  /// end it. GameJolt-specific, not part of the unified interface.
  Future<void> startSessionHeartbeat({
    Duration interval = const Duration(seconds: 60),
  }) async {
    await openSession();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(interval, (_) => pingSession());
  }

  /// Stops the heartbeat started by [startSessionHeartbeat] and closes the
  /// session.
  ///
  /// GameJolt-specific, not part of the unified interface.
  Future<void> stopSessionHeartbeat() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await closeSession();
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Stops any session heartbeat, closes the HTTP client and closes [events].
  ///
  /// This does not close the session on the server.
  @override
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
