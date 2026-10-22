import 'dart:async';
import 'dart:io' show Platform;

import 'package:jni/jni.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

// The bindings define stubs (`Leaderboard`, `Exception`) that clash with the
// unified model / dart:core.
import 'play_games_data.dart';
import 'playgames_bindings.dart' hide Exception, Leaderboard;

/// Native Google Play Games provider, backed by the **Play Games v2 Java SDK**
/// reached over `package:jni` (pure Dart, no Flutter). **Android only.**
///
/// Unlike the cross-platform REST provider, writes go through the on-device
/// Play Games client, so achievement unlocks and score submissions fire the
/// **native Play Services toasts/overlay**. Authentication is handled by the
/// SDK via Play Services: [signIn] shows the native sign-in UI when needed,
/// and there is no OAuth token to manage.
///
/// ## Host requirements
/// The engine or app embedding Dart on Android must provide:
/// 1. A running ART VM with `package:jni` initialized against it (the host
///    hands the `JavaVM*`/`JNIEnv` to JNI on startup).
/// 2. An `activityResolver`, passed to the constructor, that returns the
///    current `Activity` jobject (from `ANativeActivity.clazz` or the engine's
///    activity). It is invoked fresh before each native call, so a volatile
///    activity (Flutter's goes stale on rotation) is never cached. Engine
///    hosts with a stable activity can pass `() => activity`.
/// 3. An APK that bundles `com.google.android.gms:play-services-games-v2` and
///    declares the Play Games app id `<meta-data>` in its manifest.
///
/// On Flutter, `unified_game_services_google_play_flutter` supplies the
/// resolver for you.
///
/// ## Capabilities
/// Advertises [GameCapability.achievements], [GameCapability.leaderboards]
/// and [GameCapability.overlays]. Stats, cloud save, friends and presence are
/// not advertised, for the same reasons as in the REST provider.
///
/// ## Operations
/// Session: [isSignedIn], [signIn] and [getCurrentPlayer]; [signOut] throws
/// [PlatformOperationException] (Play Games v2 has no sign-out). Writes:
/// [unlockAchievement], [incrementAchievement], [revealAchievement] and
/// [submitScore] use the SDK's `*Immediate` variants and await their `Task`,
/// so a rejected write (unknown id, signed out, offline) throws instead of
/// being reported as a success. Reads: [getAchievements], [getLeaderboard]
/// and [getPlayerScore]. Native screens: [showAchievementsUI] and
/// [showLeaderboardsUI].
class GooglePlayAndroidProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'google_play_android';

  /// Whether this provider is supported on the current platform.
  ///
  /// `true` only on Android.
  static bool get isSupported => Platform.isAndroid;

  /// Creates the provider and initializes the Play Games SDK.
  ///
  /// [activityResolver] returns the host `Activity`; see the class
  /// documentation for how it is called. It is also invoked once here to
  /// initialize `PlayGamesSdk`.
  ///
  /// Throws [UnsupportedError] when not running on Android.
  GooglePlayAndroidProvider({
    required JObject Function() activityResolver,
    // ignore: prefer_initializing_formals
  }) : _activityResolver = activityResolver {
    if (!isSupported) {
      throw UnsupportedError(
        'GooglePlayAndroidProvider is Android-only (Play Games v2 Java SDK via package:jni) '
        'and cannot run on this platform.',
      );
    }
    PlayGamesSdk.initialize(_activityResolver().as(Context.type));
  }

  /// Resolves the host Android `Activity` jobject the Play Games clients bind
  /// to. **Called fresh, synchronously, immediately before each native call**
  /// — never cached across an `await`.
  ///
  /// Under Flutter the activity reference is volatile (it can go stale on
  /// rotation / backgrounding), so storing it would crash; the resolver lets
  /// each operation fetch the live one. Engine hosts with a stable activity can
  /// pass `() => activity`.
  final JObject Function() _activityResolver;

  final StreamController<GameServiceEvent> _events =
      StreamController<GameServiceEvent>.broadcast();

  @override
  Set<GameCapability> get capabilities => const {
    GameCapability.achievements,
    GameCapability.leaderboards,
    GameCapability.overlays,
  };

  @override
  Stream<GameServiceEvent> get events => _events.stream;

  // ─── Authentication ──────────────────────────────────────────────────────

  /// Whether the Play Games SDK reports the player as authenticated.
  ///
  /// Queries the SDK, so it reflects the live Play Services state. Throws
  /// [PlatformOperationException] if the query fails.
  @override
  Future<bool> isSignedIn() async {
    final client = PlayGames.getGamesSignInClient(
      _activityResolver().as(Activity.type),
    );
    final Task<AuthenticationResult?> task;
    try {
      task = client.isAuthenticated();
    } finally {
      client.release();
    }
    try {
      return await _isAuthenticated(task);
    } on _TaskFailure catch (e) {
      throw PlatformOperationException(
        'Could not query Play Games sign-in state',
        cause: e.error,
      );
    }
  }

  /// Shows the native Play Games sign-in UI when needed, waits for the outcome
  /// and loads the player with [getCurrentPlayer].
  ///
  /// Emits a [UserSignedInEvent] when a profile is returned. Returns `null`
  /// when sign-in succeeded but the profile could not be loaded. Throws
  /// [SignInFailedException] if sign-in fails or the player is not
  /// authenticated afterwards.
  @override
  Future<PlayerProfile?> signIn() async {
    final client = PlayGames.getGamesSignInClient(
      _activityResolver().as(Activity.type),
    );
    final Task<AuthenticationResult?> task;
    try {
      task = client.signIn();
    } finally {
      client.release();
    }
    final bool ok;
    try {
      ok = await _isAuthenticated(task);
    } on _TaskFailure catch (e) {
      throw SignInFailedException('Play Games sign-in failed', e.error);
    }
    if (!ok) {
      throw const SignInFailedException(
        'Play Games sign-in was not completed (player not authenticated).',
      );
    }
    final PlayerProfile? player;
    try {
      player = await getCurrentPlayer();
    } on GameServiceException {
      // Signed in, but the profile read failed: sign-in itself succeeded.
      return null;
    }
    if (player != null) {
      _emit(UserSignedInEvent(player: player, timestamp: DateTime.now()));
    }
    return player;
  }

  /// Always throws [PlatformOperationException]: Play Games v2 has no
  /// programmatic sign-out; the player manages the account in Play Games.
  @override
  Future<void> signOut() async {
    throw const PlatformOperationException(
      'Play Games v2 has no sign-out; the player signs out in Play Games.',
    );
  }

  /// Loads the signed-in player with the SDK's `PlayersClient`.
  ///
  /// The profile carries the player id and display name; `avatarUrl` stays
  /// `null` because Play Games image URLs are only readable through its
  /// `ImageManager`. Returns `null` when no player is signed in. Throws
  /// [PlatformOperationException] for other failures.
  @override
  Future<PlayerProfile?> getCurrentPlayer() async {
    final client = PlayGames.getPlayersClient(
      _activityResolver().as(Activity.type),
    );
    final Task<Player?> task;
    try {
      task = client.getCurrentPlayer();
    } finally {
      client.release();
    }
    final Player? player;
    try {
      player = (await _awaitTask(task as Task<JObject?>))?.as(Player.type);
    } on _TaskFailure catch (e) {
      if (e.isSignInRequired) return null;
      throw PlatformOperationException(
        'Could not load the Play Games player',
        cause: e.error,
      );
    }
    if (player == null) return null;
    try {
      return PlayerProfile(
        id: player.getPlayerId().toDartString(releaseOriginal: true),
        displayName: player.getDisplayName().toDartString(
          releaseOriginal: true,
        ),
        providerId: providerId,
      );
    } finally {
      player.release();
    }
  }

  Future<bool> _isAuthenticated(Task<AuthenticationResult?> task) async {
    final result = (await _awaitTask(
      task as Task<JObject?>,
    ))?.as(AuthenticationResult.type);
    if (result == null) return false;
    try {
      return result.isAuthenticated;
    } finally {
      result.release();
    }
  }

  // ─── Achievements (writes fire native toasts) ──────────────────────────────

  /// Unlocks the achievement with the SDK's `unlockImmediate`, firing the native
  /// toast, and emits an [AchievementUnlockedEvent].
  ///
  /// Completes only once Play Games confirms the write. Throws
  /// [NotSignedInException] when sign-in is required and
  /// [PlatformOperationException] for other failures, such as offline use.
  @override
  Future<void> unlockAchievement(String achievementId) async {
    final id = resolveAchievementId(achievementId);
    await _awaitWrite(
      _withAchievements((c) => _withJString(id, c.unlockImmediate)),
      'unlock achievement "$id"',
    );
    _emit(
      AchievementUnlockedEvent(
        achievement: Achievement(id: id, title: id, isUnlocked: true),
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Increments the achievement with the SDK's `incrementImmediate`.
  ///
  /// Fails the same way as [unlockAchievement].
  @override
  Future<void> incrementAchievement(String achievementId, int steps) async {
    final id = resolveAchievementId(achievementId);
    await _awaitWrite(
      _withAchievements(
        (c) => _withJString(id, (js) => c.incrementImmediate(js, steps)),
      ),
      'increment achievement "$id"',
    );
  }

  /// Reveals the achievement with the SDK's `revealImmediate`.
  ///
  /// Fails the same way as [unlockAchievement].
  @override
  Future<void> revealAchievement(String achievementId) async {
    final id = resolveAchievementId(achievementId);
    await _awaitWrite(
      _withAchievements((c) => _withJString(id, c.revealImmediate)),
      'reveal achievement "$id"',
    );
  }

  /// Sets an incremental achievement to at least [steps], never decreasing it.
  ///
  /// Provider-specific: not part of the unified interface. Fails the same way
  /// as [unlockAchievement].
  Future<void> setAchievementStepsAtLeast(
    String achievementId,
    int steps,
  ) async {
    final id = resolveAchievementId(achievementId);
    await _awaitWrite(
      _withAchievements(
        (c) => _withJString(id, (js) => c.setStepsImmediate(js, steps)),
      ),
      'set steps of achievement "$id"',
    );
  }

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  /// Submits [score] with the SDK's `submitScoreImmediate` and emits a
  /// [ScoreSubmittedEvent].
  ///
  /// Fails the same way as [unlockAchievement].
  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    final id = resolveLeaderboardId(leaderboardId);
    final client = PlayGames.getLeaderboardsClient(
      _activityResolver().as(Activity.type),
    );
    final Task<JObject?> task;
    try {
      task = _withJString(id, (js) => client.submitScoreImmediate(js, score));
    } finally {
      client.release();
    }
    await _awaitWrite(task, 'submit score to "$id"');
    _emit(
      ScoreSubmittedEvent(
        leaderboardId: id,
        score: score,
        timestamp: DateTime.now(),
      ),
    );
  }

  // ─── Native UIs ([GameCapability.overlays]) ─────────────────────────────────

  /// Opens the native Play Games **achievements** screen.
  ///
  /// Throws [NotSignedInException] when the player is not signed in and
  /// [PlatformOperationException] if the SDK cannot produce the screen. The
  /// REST tier has no system UI, so only this provider advertises
  /// [GameCapability.overlays].
  @override
  Future<void> showAchievementsUI() async {
    final client = PlayGames.getAchievementsClient(
      _activityResolver().as(Activity.type),
    );
    final Task<Intent?> task;
    try {
      task = client.getAchievementsIntent();
    } finally {
      client.release();
    }
    await _startIntent(task, _achievementsRequestCode);
  }

  /// Opens the native Play Games **leaderboards** screen: the list of all
  /// leaderboards, or a single one when [leaderboardId] is given.
  ///
  /// The unified [leaderboardId] is translated to the Play Games id. See
  /// [showAchievementsUI] for failure behavior.
  @override
  Future<void> showLeaderboardsUI({String? leaderboardId}) async {
    final client = PlayGames.getLeaderboardsClient(
      _activityResolver().as(Activity.type),
    );
    final Task<Intent?> task;
    try {
      if (leaderboardId == null) {
        task = client.getAllLeaderboardsIntent();
      } else {
        final js = resolveLeaderboardId(leaderboardId).toJString();
        try {
          task = client.getLeaderboardIntent(js);
        } finally {
          js.release();
        }
      }
    } finally {
      client.release();
    }
    await _startIntent(task, _leaderboardsRequestCode);
  }

  /// Play Games has no generic overlay: use [showAchievementsUI] or
  /// [showLeaderboardsUI].
  @override
  Future<void> showOverlay({String? overlayId}) =>
      throw const PlatformOperationException(
        'Google Play Games has no generic overlay; use showAchievementsUI() or '
        'showLeaderboardsUI().',
      );

  static const _achievementsRequestCode = 9003;
  static const _leaderboardsRequestCode = 9004;

  /// Awaits [task] without blocking a thread, via an `OnCompleteListener`.
  ///
  /// Completes with the task result (a new reference the caller must release,
  /// or null) or errors with a [_TaskFailure] carrying the Java exception text.
  /// Releases the task and the listener.
  Future<JObject?> _awaitTask(Task<JObject?> task) async {
    final completer = Completer<JObject?>();
    final listener = OnCompleteListener<JObject?>.implement(
      $OnCompleteListener<JObject?>(
        onComplete: (done) {
          if (completer.isCompleted) return;
          if (done.isSuccessful) {
            completer.complete(done.result);
          } else {
            completer.completeError(_TaskFailure(done.exception?.toString()));
          }
        },
      ),
    );
    try {
      task.addOnCompleteListener(listener).release();
      return await completer.future;
    } finally {
      listener.release();
      task.release();
    }
  }

  /// Awaits [task] and launches its `Intent` from a freshly resolved Activity.
  Future<void> _startIntent(Task<Intent?> task, int requestCode) async {
    final Intent? intent;
    try {
      intent = (await _awaitTask(task as Task<JObject?>))?.as(Intent.type);
    } on _TaskFailure catch (e) {
      // ApiException status 4 = SIGN_IN_REQUIRED.
      if (e.isSignInRequired) {
        throw NotSignedInException(
          'Sign in to Play Games before opening its UI',
          e.error,
        );
      }
      throw PlatformOperationException(
        'Play Games UI request failed',
        cause: e.error,
      );
    }
    if (intent == null) {
      throw const PlatformOperationException(
        'Play Games returned no intent for this UI',
      );
    }
    try {
      // Re-resolve: the activity may have changed while awaiting the Task.
      _activityResolver()
          .as(Activity.type)
          .startActivityForResult(intent, requestCode);
    } finally {
      intent.release();
    }
  }

  // ─── Reads ─────────────────────────────────────────────────────────────────
  //
  // The payload types (AnnotatedData, data buffers, Achievement,
  // LeaderboardScore) are opaque in the committed bindings, so their getters
  // are called reflectively; see play_games_data.dart.

  /// Loads the achievement definitions merged with the player's progress.
  ///
  /// Uses the SDK's cached data when fresh (`load(false)`). Hidden
  /// achievements report `isHidden: true`. Incremental achievements carry their
  /// native steps; `unlockedAt` is the last update of an unlocked achievement.
  /// Throws [NotSignedInException] when sign-in is required and
  /// [PlatformOperationException] for other failures.
  @override
  Future<List<Achievement>> getAchievements() async {
    final buffer = await _awaitRead(
      _withAchievements((c) => c.load(false)) as Task<JObject?>,
      'load achievements',
    );
    if (buffer == null) return const [];
    return readBuffer(buffer, (e) {
      final a = readAchievement(e);
      final unlocked = a.state == achievementStateUnlocked;
      return Achievement(
        id: a.id,
        title: a.name,
        description: a.description,
        isUnlocked: unlocked,
        unlockedAt: unlocked && a.updatedAtMillis > 0
            ? DateTime.fromMillisecondsSinceEpoch(a.updatedAtMillis)
            : null,
        isHidden: a.state == achievementStateHidden,
        currentSteps: a.currentSteps,
        totalSteps: a.totalSteps,
      );
    });
  }

  /// Loads up to [maxResults] top scores (clamped to the SDK's 1–25).
  ///
  /// [timeScope] maps to Play Games' daily, weekly and all-time spans and
  /// [collection] to its public and friends collections. Throws like
  /// [getAchievements].
  @override
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) async {
    final id = resolveLeaderboardId(leaderboardId);
    final scores = await _awaitRead(
      _withLeaderboards(
            (c) => _withJString(
              id,
              (js) => c.loadTopScores(
                js,
                _timeSpan(timeScope),
                _collection(collection),
                maxResults.clamp(1, 25),
              ),
            ),
          )
          as Task<JObject?>,
      'load leaderboard "$id"',
    );
    final entries = <LeaderboardEntry>[];
    if (scores != null) {
      final wrapper = scores.as(LeaderboardsClient$LeaderboardScores.type);
      try {
        entries.addAll(
          readBuffer(wrapper.scores, (e) => _entryOf(readScore(e))),
        );
      } finally {
        wrapper.release();
      }
    }
    return Leaderboard(
      id: leaderboardId,
      timeScope: timeScope,
      collection: collection,
      entries: entries,
    );
  }

  /// Loads the signed-in player's score, or `null` when they have none.
  ///
  /// Uses the public collection, so the rank is global at any position.
  /// Throws like [getAchievements].
  @override
  Future<LeaderboardEntry?> getPlayerScore(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
  }) async {
    final id = resolveLeaderboardId(leaderboardId);
    final score = await _awaitRead(
      _withLeaderboards(
            (c) => _withJString(
              id,
              (js) => c.loadCurrentPlayerLeaderboardScore(
                js,
                _timeSpan(timeScope),
                _collectionPublic,
              ),
            ),
          )
          as Task<JObject?>,
      'load the player score on "$id"',
    );
    if (score == null) return null;
    try {
      return _entryOf(readScore(score));
    } finally {
      score.release();
    }
  }

  // `LeaderboardVariant` constants.
  static const _collectionPublic = 0;
  static const _collectionFriends = 3;

  static int _timeSpan(LeaderboardTimeScope scope) => switch (scope) {
    LeaderboardTimeScope.daily => 0,
    LeaderboardTimeScope.weekly => 1,
    LeaderboardTimeScope.allTime => 2,
  };

  static int _collection(LeaderboardCollection collection) =>
      switch (collection) {
        LeaderboardCollection.global => _collectionPublic,
        LeaderboardCollection.friends => _collectionFriends,
      };

  static LeaderboardEntry _entryOf(ScoreData s) => LeaderboardEntry(
    rank: s.rank,
    score: s.rawScore,
    formattedScore: s.displayScore,
    achievedAt: s.timestampMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(s.timestampMillis)
        : null,
    player: PlayerProfile(id: s.holderId ?? '', displayName: s.holderName),
  );

  /// Awaits a read `Task` whose result is an `AnnotatedData`, and returns its
  /// payload (a new reference, or `null`). Maps failures like [_awaitWrite].
  Future<JObject?> _awaitRead(Task<JObject?> task, String what) async {
    final JObject? annotated;
    try {
      annotated = await _awaitTask(task);
    } on _TaskFailure catch (e) {
      if (e.isSignInRequired) {
        throw NotSignedInException('Sign in to Play Games to $what', e.error);
      }
      throw PlatformOperationException(
        'Play Games failed to $what',
        cause: e.error,
      );
    }
    return annotated == null ? null : unwrapAnnotated(annotated);
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Closes the events stream.
  ///
  /// JNI client references are released per call, so nothing else is held.
  @override
  Future<void> dispose() async {
    await _events.close();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Runs [body] with a fresh `AchievementsClient`, releasing it afterwards.
  T _withAchievements<T>(T Function(AchievementsClient client) body) {
    final client = PlayGames.getAchievementsClient(
      _activityResolver().as(Activity.type),
    );
    try {
      return body(client);
    } finally {
      client.release();
    }
  }

  /// Runs [body] with a fresh `LeaderboardsClient`, releasing it afterwards.
  T _withLeaderboards<T>(T Function(LeaderboardsClient client) body) {
    final client = PlayGames.getLeaderboardsClient(
      _activityResolver().as(Activity.type),
    );
    try {
      return body(client);
    } finally {
      client.release();
    }
  }

  /// Calls [body] with a temporary [JString] built from [value], releasing it.
  T _withJString<T>(String value, T Function(JString) body) {
    final js = value.toJString();
    try {
      return body(js);
    } finally {
      js.release();
    }
  }

  /// Awaits the `Task` of an `*Immediate` write and maps a failure to a
  /// [GameServiceException], so the facade reports it per provider.
  ///
  /// Unlike the queued, fire-and-forget `unlock`/`submitScore`, `*Immediate`
  /// calls complete only once Play Games confirmed the write, so they fail
  /// offline instead of queueing.
  Future<void> _awaitWrite(Task<JObject?> task, String what) async {
    try {
      (await _awaitTask(task))?.release();
    } on _TaskFailure catch (e) {
      if (e.isSignInRequired) {
        throw NotSignedInException('Sign in to Play Games to $what', e.error);
      }
      throw PlatformOperationException(
        'Play Games failed to $what',
        cause: e.error,
      );
    }
  }

  void _emit(GameServiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}

/// A failed Play Services `Task`, carrying the Java exception's text.
class _TaskFailure implements Exception {
  _TaskFailure(this.error);

  final String? error;

  /// `ApiException` status 4 = `SIGN_IN_REQUIRED`.
  bool get isSignInRequired =>
      error != null &&
      (error!.contains('ApiException: 4:') ||
          error!.contains('SIGN_IN_REQUIRED'));
}
