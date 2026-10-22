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
/// Runs on every Dart platform, including web, because it talks to Google's
/// cloud directly rather than the on-device Play Services client. It is the
/// cross-platform tier of the Google Play Games family.
///
/// ## Authentication
/// The provider performs no OAuth itself; it asks the [AuthStrategy] passed to
/// the constructor for a bearer token carrying the
/// `https://www.googleapis.com/auth/games` scope. Choose one:
/// - `LoopbackOAuthStrategy`: interactive browser sign-in for desktop and CLI.
///   Needs a Google Cloud OAuth client of type **Desktop app**. Not available
///   on web.
/// - `StoredCredentialStrategy`: a refresh token or brokered access token, for
///   servers and headless hosts.
/// - `NativeSilentTokenStrategy`: a token brokered by an Android host through a
///   `NativeTokenProvider`.
///
/// ## Capabilities
/// Advertises [GameCapability.achievements] and [GameCapability.leaderboards]
/// only. The other capabilities are not offered because the REST API has no
/// equivalent:
/// - Stats: Play Games exposes fixed, read-only player analytics rather than
///   writable counters.
/// - Cloud save: snapshots live in Drive appdata, a separate API and OAuth
///   scope.
/// - Friends and presence: not available through the Games API this provider
///   uses.
///
/// ## Limitations
/// Writes go to Google's cloud and not through the on-device Play Games client,
/// so **no native achievement or leaderboard toasts appear on Android**; the
/// host must draw its own UI. Use `unified_game_services_google_play_android`
/// for the native experience, or `unified_game_services_google_play` to choose
/// automatically. The provider has no native UI of its own.
///
/// Failures are reported as [GameServiceException] subtypes: [NetworkException]
/// for transport errors, [NotSignedInException] when the token is rejected, and
/// [PlatformOperationException] for other API errors.
class GooglePlayGamesProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'google_play_rest';

  /// Whether this provider is supported on the current platform.
  ///
  /// Always `true`: the REST provider has no platform requirements.
  static bool get isSupported => true;

  /// Creates a provider that authorizes requests through [auth].
  ///
  /// [httpClient] defaults to a new [http.Client] owned by the provider and
  /// closed by [dispose]. [baseUrl] overrides the Games API root, e.g. for a
  /// test server.
  GooglePlayGamesProvider({
    required AuthStrategy auth,
    http.Client? httpClient,
    String baseUrl = 'https://games.googleapis.com/games/v1',
  }) : _auth = auth,
       _client = GamesRestClient(
         auth: auth,
         httpClient: httpClient,
         baseUrl: baseUrl,
       );

  /// Creates a provider around an existing [client], typically in tests.
  ///
  /// [client] and the `auth` strategy should share the same credentials.
  /// [dispose] closes [client].
  GooglePlayGamesProvider.withClient({
    required GamesRestClient client,
    required this._auth,
    // ignore: prefer_initializing_formals
  }) : _client = client;

  final AuthStrategy _auth;
  final GamesRestClient _client;
  final Random _nonce = Random();
  final StreamController<GameServiceEvent> _events =
      StreamController<GameServiceEvent>.broadcast();

  @override
  Set<GameCapability> get capabilities => const {
    GameCapability.achievements,
    GameCapability.leaderboards,
  };

  @override
  Stream<GameServiceEvent> get events => _events.stream;

  // ─── Authentication ──────────────────────────────────────────────────────

  /// Whether the [AuthStrategy] currently holds credentials.
  ///
  /// Makes no network call, so a held token that has since been revoked or has
  /// expired still reports `true`.
  @override
  Future<bool> isSignedIn() async => _auth.isAuthenticated;

  /// Acquires a token through the [AuthStrategy] (running its interactive flow
  /// if needed) and loads the player's profile.
  ///
  /// Emits a [UserSignedInEvent] when a profile is returned. Failures of the
  /// strategy surface as [SignInFailedException] or [NotSignedInException].
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

  /// Drops the strategy's local credentials and emits a [UserSignedOutEvent].
  ///
  /// The token is not revoked at Google.
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

  /// Fetches the achievement definitions and the player's progress with two
  /// requests and merges them.
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

  /// Unlocks the achievement and emits an [AchievementUnlockedEvent].
  ///
  /// The event carries a placeholder [Achievement] whose title is the id.
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

  /// Increments the achievement with a random `requestId`, so a retried request
  /// is not double-counted.
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

  /// Sets an incremental achievement to at least [steps] total, never
  /// decreasing it.
  ///
  /// Provider-specific: not part of the unified interface. Reach it via
  /// `GameServices.provider<GooglePlayGamesProvider>()`.
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

  /// Submits [score] to the leaderboard and emits a [ScoreSubmittedEvent].
  ///
  /// Play Games keeps the best score according to the leaderboard's sort order.
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

  /// Fetches a page of scores.
  ///
  /// [LeaderboardCollection.global] maps to Play Games' `PUBLIC` collection and
  /// [LeaderboardCollection.friends] to `SOCIAL`. [maxResults] is clamped to
  /// the API's range of 1 to 30. The returned [Leaderboard] carries the id as
  /// passed, not the resolved native id.
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

  /// Returns the player's score for [timeScope], or `null` when they have none.
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

  /// Records [steps] of progress against the Play Games **event** [eventId]
  /// (`POST /events`).
  ///
  /// Events are increment-only counters, distinct from the unified stats
  /// concept.
  ///
  /// Provider-specific: not part of the unified interface. Reach it via
  /// `GameServices.provider<GooglePlayGamesProvider>()`.
  Future<void> recordEvent(String eventId, int steps) async {
    await _client.post(
      '/events',
      query: {'eventId': eventId, 'updateCount': '$steps'},
    );
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Closes the HTTP client, even an injected one, and the events stream.
  @override
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
