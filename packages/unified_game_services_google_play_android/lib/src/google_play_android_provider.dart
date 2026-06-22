import 'dart:async';

import 'package:jni/jni.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'playgames_bindings.dart';

/// Native Google Play Games provider, backed by the **Play Games v2 Java SDK**
/// reached over `package:jni` (pure Dart, no Flutter). **Android only.**
///
/// Unlike the cross-platform REST provider, writes go through the on-device
/// Play Games client, so achievement unlocks and score submissions fire the
/// **native Play Services toasts/overlay**. Authentication is handled by the
/// SDK via Play Services — there is no OAuth token to manage.
///
/// ## Host requirements (the engine/app embedding Dart on Android)
/// 1. A running ART VM with `package:jni` initialized against it (the host
///    hands the `JavaVM*`/`JNIEnv` to JNI on startup).
/// 2. The current `Activity` jobject, passed to [registerWith] / the
///    constructor (from `ANativeActivity.clazz` or the engine's activity).
/// 3. The APK must bundle `com.google.android.gms:play-services-games-v2` and
///    declare the Play Games app id `<meta-data>` in its manifest.
///
/// ## Status: writes wired; async reads pending a Task binding
/// The toast-firing writes ([unlockAchievement], [incrementAchievement],
/// [revealAchievement], [submitScore]) are plain void SDK calls and are fully
/// implemented. Operations that must read the result of a `Task<T>`
/// (confirming sign-in state, loading the current player, listing achievements
/// / leaderboard scores) are **not yet implemented**: jnigen 0.16.0
/// mis-generates `com.google.android.gms.tasks.Task`/`Tasks`, so those classes
/// are excluded and `Task`-returning methods come back as opaque [JObject].
/// Wiring the read path needs a jnigen that fixes generics (or a small
/// hand-written JNI `Tasks.await` helper) — see `jnigen.yaml`. Until then the
/// unified facade should serve reads from the REST provider
/// (`unified_game_services_google_play_rest`); this provider's role is
/// native-UX writes.
class GooglePlayAndroidProvider extends UnifiedGameServicesPlatform {
  GooglePlayAndroidProvider({
    required JObject activity,
    super.leaderboardIds,
    super.achievementIds,
  }) : _activity = activity {
    PlayGamesSdk.initialize(activity);
  }

  /// The host Activity jobject the Play Games clients are bound to.
  final JObject _activity;

  /// Best-effort sign-in flag: set once [signIn] has triggered the native flow.
  /// Not authoritative — confirming actual sign-in needs the Task read path.
  bool _signInTriggered = false;

  final StreamController<GameServiceEvent> _events =
      StreamController<GameServiceEvent>.broadcast();

  /// Registers a [GooglePlayAndroidProvider] as the active platform.
  ///
  /// [activity] is the host Android `Activity` jobject.
  static void registerWith({
    required JObject activity,
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) {
    UnifiedGameServicesPlatform.instance = GooglePlayAndroidProvider(
      activity: activity,
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
  Future<bool> isSignedIn() async => _signInTriggered;

  @override
  Future<PlayerProfile?> signIn() async {
    // Triggers the native Play Games sign-in UI. The returned Task is opaque
    // (see class docs) so we cannot yet read the AuthenticationResult or load
    // the profile here; returns null until the Task read path lands.
    final client = PlayGames.getGamesSignInClient(_activity);
    try {
      client.signIn().release();
      _signInTriggered = true;
    } finally {
      client.release();
    }
    return null;
  }

  // ─── Achievements (writes fire native toasts) ──────────────────────────────

  @override
  Future<void> unlockAchievement(String achievementId) async {
    final id = resolveAchievementId(achievementId);
    _withAchievements((c) => _withJString(id, c.unlock));
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
    _withAchievements((c) {
      final js = id.toJString();
      try {
        c.increment(js, steps);
      } finally {
        js.release();
      }
    });
  }

  @override
  Future<void> revealAchievement(String achievementId) async {
    final id = resolveAchievementId(achievementId);
    _withAchievements((c) => _withJString(id, c.reveal));
  }

  /// Provider-specific (not on the unified interface): set an incremental
  /// achievement to at least [steps], never decreasing it.
  Future<void> setAchievementStepsAtLeast(
    String achievementId,
    int steps,
  ) async {
    final id = resolveAchievementId(achievementId);
    _withAchievements((c) {
      final js = id.toJString();
      try {
        c.setSteps(js, steps);
      } finally {
        js.release();
      }
    });
  }

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    final id = resolveLeaderboardId(leaderboardId);
    final client = PlayGames.getLeaderboardsClient(_activity);
    try {
      _withJString(id, (js) => client.submitScore(js, score));
    } finally {
      client.release();
    }
    _emit(
      ScoreSubmittedEvent(
        leaderboardId: id,
        score: score,
        timestamp: DateTime.now(),
      ),
    );
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Closes the events stream. (JNI client refs are released per call.)
  Future<void> dispose() async {
    await _events.close();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Runs [body] with a fresh `AchievementsClient`, releasing it afterwards.
  void _withAchievements(void Function(AchievementsClient client) body) {
    final client = PlayGames.getAchievementsClient(_activity);
    try {
      body(client);
    } finally {
      client.release();
    }
  }

  /// Calls [body] with a temporary [JString] built from [value], releasing it.
  void _withJString(String value, void Function(JString) body) {
    final js = value.toJString();
    try {
      body(js);
    } finally {
      js.release();
    }
  }

  void _emit(GameServiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
