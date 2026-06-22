import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'auth/auth_strategy.dart';
import 'games_rest_client.dart';
import 'mappers.dart';

/// Google Play Games provider backed by the **REST Games API v1**
/// (`games.googleapis.com/games/v1`), pure Dart with no Flutter.
///
/// Runs anywhere Dart runs — desktop native windows, Android (NDK), CLIs and
/// servers — because it talks to Google's cloud directly rather than the
/// on-device Play Services client. Authentication is delegated to a pluggable
/// [AuthStrategy] (browser loopback on desktop, a stored token on a server, or
/// a host-brokered native token on Android).
///
/// Supported unified capabilities: **achievements** and **leaderboards**. Stats
/// (GPG exposes only fixed read-only analytics), cloud save (lives in Drive
/// appdata, a separate API + scope) and friends/presence are intentionally not
/// advertised.
///
/// Because writes go through the REST API and not the Play Services client,
/// **native achievement/leaderboard toasts do not appear on Android** — the
/// host draws its own UI. (A future `unified_game_services_google_play_android`
/// provider routes those through the Java SDK for native UX.)
class GooglePlayGamesProvider extends UnifiedGameServicesPlatform {
  GooglePlayGamesProvider({
    required AuthStrategy auth,
    http.Client? httpClient,
    String baseUrl = 'https://games.googleapis.com/games/v1',
    super.leaderboardIds,
    super.achievementIds,
  }) : _auth = auth,
       _client = GamesRestClient(
         auth: auth,
         httpClient: httpClient,
         baseUrl: baseUrl,
       );

  /// Creates a provider around an existing [GamesRestClient] (useful for
  /// tests). The named argument is `client` (Dart drops the leading
  /// underscore).
  GooglePlayGamesProvider.withClient({
    required GamesRestClient client,
    required this._auth,
    super.leaderboardIds,
    super.achievementIds,
    // ignore: prefer_initializing_formals
  }) : _client = client;

  final AuthStrategy _auth;
  final GamesRestClient _client;
  final Random _nonce = Random();
  final StreamController<GameServiceEvent> _events =
      StreamController<GameServiceEvent>.broadcast();

  /// Registers a [GooglePlayGamesProvider] as the active platform.
  static void registerWith({
    required AuthStrategy auth,
    http.Client? httpClient,
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) {
    UnifiedGameServicesPlatform.instance = GooglePlayGamesProvider(
      auth: auth,
      httpClient: httpClient,
      leaderboardIds: leaderboardIds,
      achievementIds: achievementIds,
    );
  }

  @override
  Set<GameCapability> get capabilities => const {
    GameCapability.achievements,
    GameCapability.leaderboards,
  };

  @override
  Stream<GameServiceEvent> get events => _events.stream;

  // ─── Authentication ──────────────────────────────────────────────────────

  @override
  Future<bool> isSignedIn() async => _auth.isAuthenticated;

  @override
  Future<PlayerProfile?> signIn() async {
    // Forces the strategy to acquire a token if it has none.
    await _auth.getAccessToken();
    final profile = await getCurrentPlayer();
    if (profile != null) {
      _emit(UserSignedInEvent(player: profile, timestamp: DateTime.now()));
    }
    return profile;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _emit(UserSignedOutEvent(timestamp: DateTime.now()));
  }

  @override
  Future<PlayerProfile?> getCurrentPlayer() async {
    final json = await _client.get('/players/me');
    return playerProfileFromJson(json);
  }

  // ─── Achievements ──────────────────────────────────────────────────────────

  @override
  Future<List<Achievement>> getAchievements() async {
    final defsResponse = await _client.get('/achievements');
    final progressResponse = await _client.get('/players/me/achievements');
    final definitions = _items(defsResponse);
    final progressById = {
      for (final p in _items(progressResponse)) '${p['id']}': p,
    };
    return achievementsFromJson(definitions, progressById);
  }

  @override
  Future<void> unlockAchievement(String achievementId) async {
    final id = resolveAchievementId(achievementId);
    await _client.post('/achievements/$id/unlock');
    _emit(
      AchievementUnlockedEvent(
        achievement: Achievement(id: id, title: id, isUnlocked: true),
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> incrementAchievement(String achievementId, int steps) async {
    final id = resolveAchievementId(achievementId);
    await _client.post(
      '/achievements/$id/increment',
      query: {
        'stepsToIncrement': '$steps',
        // Idempotency token so a retried request is not double-counted.
        'requestId': '${_nonce.nextInt(1 << 32)}',
      },
    );
  }

  @override
  Future<void> revealAchievement(String achievementId) async {
    final id = resolveAchievementId(achievementId);
    await _client.post('/achievements/$id/reveal');
  }

  /// Provider-specific (not part of the unified interface): sets an incremental
  /// achievement to at least [steps] total, never decreasing it. Reach via
  /// `getInstance<GooglePlayGamesProvider>()`.
  Future<void> setAchievementStepsAtLeast(
    String achievementId,
    int steps,
  ) async {
    final id = resolveAchievementId(achievementId);
    await _client.post(
      '/achievements/$id/setStepsAtLeast',
      query: {'steps': '$steps'},
    );
  }

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    final id = resolveLeaderboardId(leaderboardId);
    await _client.post('/leaderboards/$id/scores', query: {'score': '$score'});
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
    final id = resolveLeaderboardId(leaderboardId);
    final response = await _client.get(
      '/leaderboards/$id/scores/${_collection(collection)}',
      query: {
        'timeSpan': _timeSpan(timeScope),
        'maxResults': '${maxResults.clamp(1, 30)}',
      },
    );
    final rows = _items(response);
    final entries = [
      for (var i = 0; i < rows.length; i++)
        leaderboardEntryFromJson(rows[i], fallbackRank: i + 1),
    ];
    return Leaderboard(
      id: leaderboardId,
      timeScope: timeScope,
      collection: collection,
      entries: entries,
    );
  }

  @override
  Future<LeaderboardEntry?> getPlayerScore(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
  }) async {
    final id = resolveLeaderboardId(leaderboardId);
    final response = await _client.get(
      '/players/me/leaderboards/$id/scores/${_timeSpan(timeScope)}',
    );
    final rows = _items(response);
    if (rows.isEmpty) return null;
    return leaderboardEntryFromJson(rows.first, fallbackRank: 1);
  }

  /// Provider-specific (not part of the unified interface): records [steps] of
  /// progress against a Play Games **event** (`POST /events`). Events are
  /// increment-only counters, distinct from the unified stats concept. Reach
  /// via `getInstance<GooglePlayGamesProvider>()`.
  Future<void> recordEvent(String eventId, int steps) async {
    await _client.post(
      '/events',
      query: {'eventId': eventId, 'updateCount': '$steps'},
    );
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Closes the HTTP client and the events stream.
  Future<void> dispose() async {
    _client.close();
    await _events.close();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String _timeSpan(LeaderboardTimeScope scope) => switch (scope) {
    LeaderboardTimeScope.allTime => 'ALL_TIME',
    LeaderboardTimeScope.weekly => 'WEEKLY',
    LeaderboardTimeScope.daily => 'DAILY',
  };

  static String _collection(LeaderboardCollection collection) =>
      switch (collection) {
        LeaderboardCollection.global => 'PUBLIC',
        LeaderboardCollection.friends => 'SOCIAL',
      };

  /// Extracts the `items` array (the standard Games API list envelope) as a
  /// list of maps; tolerates a missing/empty field.
  static List<Map<String, dynamic>> _items(Map<String, dynamic> response) {
    final items = response['items'];
    return items is List
        ? items.cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
  }

  void _emit(GameServiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
