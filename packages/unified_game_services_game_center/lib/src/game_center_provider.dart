import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart' as pkg_ffi;
import 'package:objective_c/objective_c.dart' as objc;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'gamekit_bindings.dart';

/// Apple Game Center provider, backed by GameKit through pure-Dart
/// Objective-C FFI (`package:objective_c`). **No Flutter dependency** — the
/// same binary works in a Flutter app, a custom Dart game engine, a CLI, or a
/// server, as long as it runs on macOS or iOS.
///
/// ## Runtime requirements (supplied by the host process)
///
/// GameKit is not a network API; it talks to the OS Game Center service, and
/// the OS imposes two requirements the host — not this package — must meet:
///
/// 1. **A signed app bundle.** The executable must run inside a code-signed
///    `.app`/`.ipa` with an `Info.plist` whose bundle id is registered in App
///    Store Connect, plus the matching entitlements/provisioning. A bare
///    `dart run foo.dart` has no bundle and GameKit refuses to authenticate
///    (`GKErrorNotAuthenticated`). A Flutter macOS/iOS app already is such a
///    bundle; a custom engine must package itself as one.
/// 2. **A pumped main run loop.** GameKit delivers its completion handlers on
///    the main dispatch queue / `CFRunLoop`. The host must keep that run loop
///    running for the `Future`s returned here to complete. Flutter and AppKit
///    apps do this already; a headless engine must pump `CFRunLoopRun()` (or
///    equivalent) on the main thread.
///
/// This mirrors how the Steam provider needs the Steam client running: the
/// capability is pure Dart, but the surrounding environment is the host's job.
///
/// ## Capabilities
///
/// Auth, achievements and leaderboards. GameKit has no portable notion of
/// free-form numeric *stats* or *rich presence*, so those capabilities are not
/// advertised; cloud save (`GKSavedGame`) and friends are deferred to a later
/// iteration.
class GameCenterProvider extends UnifiedGameServicesPlatform {
  GameCenterProvider({super.leaderboardIds, super.achievementIds});

  /// `GKErrorDomain` and friends. Instantiated against the dlopen'd framework
  /// so the `GKErrorDomain` symbol can be read; the Obj-C message sends in the
  /// generated extension types resolve through the shared runtime.
  static GameKitBindings? _gk;

  final StreamController<GameServiceEvent> _events =
      StreamController<GameServiceEvent>.broadcast();

  /// Registers a [GameCenterProvider] as the active platform implementation.
  static void registerWith({
    Map<String, String>? leaderboardIds,
    Map<String, String>? achievementIds,
  }) {
    UnifiedGameServicesPlatform.instance = GameCenterProvider(
      leaderboardIds: leaderboardIds,
      achievementIds: achievementIds,
    );
  }

  /// Loads GameKit into the process so its Obj-C classes are registered.
  ///
  /// Idempotent. Tries the macOS absolute path first, then the bare framework
  /// name (iOS / dyld shared cache).
  static GameKitBindings _ensureLoaded() {
    final existing = _gk;
    if (existing != null) return existing;
    const candidates = [
      '/System/Library/Frameworks/GameKit.framework/GameKit',
      'GameKit.framework/GameKit',
      'GameKit',
    ];
    ffi.DynamicLibrary? lib;
    for (final path in candidates) {
      try {
        lib = ffi.DynamicLibrary.open(path);
        break;
      } catch (_) {
        // try next candidate
      }
    }
    if (lib == null) {
      throw const PlatformOperationException(
        'Could not load GameKit.framework. Game Center is only available on '
        'macOS and iOS.',
      );
    }
    return _gk = GameKitBindings(lib);
  }

  @override
  Set<GameCapability> get capabilities => const {
    GameCapability.achievements,
    GameCapability.leaderboards,
  };

  @override
  Stream<GameServiceEvent> get events => _events.stream;

  /// Releases the events stream.
  Future<void> dispose() async {
    await _events.close();
  }

  // ─── Authentication ────────────────────────────────────────────────────────

  GKLocalPlayer get _local {
    _ensureLoaded();
    return GKLocalPlayer.getLocalPlayer();
  }

  @override
  Future<bool> isSignedIn() async {
    _ensureLoaded();
    return _local.isAuthenticated;
  }

  @override
  Future<PlayerProfile?> signIn() async {
    _ensureLoaded();
    final player = _local;
    if (player.isAuthenticated) return _profileOf(player);

    final completer = Completer<PlayerProfile?>();
    // GameKit may invoke the handler more than once (e.g. to hand back a view
    // controller it wants presented). We resolve on the first terminal state.
    player.authenticateHandler =
        ObjCBlock_ffiVoid_NSViewController_NSError.fromFunction((
          NSViewController? viewController,
          objc.NSError? error,
        ) {
          if (completer.isCompleted) return;
          if (error != null) {
            completer.completeError(_mapError(error, 'signIn'));
            return;
          }
          final current = _local;
          if (current.isAuthenticated) {
            final profile = _profileOf(current);
            _events.add(
              UserSignedInEvent(player: profile, timestamp: DateTime.now()),
            );
            completer.complete(profile);
            return;
          }
          if (viewController != null) {
            // The OS wants to show its Game Center sign-in UI. We cannot
            // present a view controller from pure Dart; the host app must have
            // the player already signed in at the OS level, or present this
            // controller itself (outside the unified API).
            completer.completeError(
              const SignInFailedException(
                'Game Center requires the OS sign-in UI to be presented, which '
                'this pure-Dart provider cannot do. Sign in to Game Center via '
                'system Settings, or present the auth view controller from the '
                'host app.',
              ),
            );
          }
          // Otherwise: a non-terminal callback; wait for the next one.
        });
    return completer.future;
  }

  @override
  Future<PlayerProfile?> getCurrentPlayer() async {
    _ensureLoaded();
    final player = _local;
    return player.isAuthenticated ? _profileOf(player) : null;
  }

  PlayerProfile _profileOf(GKLocalPlayer player) {
    final id = player.gamePlayerID.toDartString();
    final name = player.displayName.toDartString();
    return PlayerProfile(id: id, displayName: name);
  }

  void _requireSignedIn() {
    if (!_local.isAuthenticated) throw const NotSignedInException();
  }

  // ─── Achievements ──────────────────────────────────────────────────────────

  @override
  Future<List<Achievement>> getAchievements() async {
    _requireSignedIn();
    // Descriptions carry the static metadata (title, hidden, …); GKAchievement
    // carries the player's per-achievement progress. Merge them by id.
    final descriptions = await _loadArray(
      GKAchievementDescription.loadAchievementDescriptionsWithCompletionHandler,
      'getAchievements',
    );
    final progress = await _loadArray(
      GKAchievement.loadAchievementsWithCompletionHandler,
      'getAchievements',
    );

    final progressById = <String, GKAchievement>{};
    for (final obj in progress.asDart()) {
      final a = GKAchievement.as(obj);
      final id = a.identifier?.toDartString();
      if (id != null) progressById[id] = a;
    }

    final result = <Achievement>[];
    for (final obj in descriptions.asDart()) {
      final d = GKAchievementDescription.as(obj);
      final id = d.identifier?.toDartString();
      if (id == null) continue;
      final p = progressById[id];
      final percent = p?.percentComplete ?? 0.0;
      final unlocked = p?.isCompleted ?? false;
      result.add(
        Achievement(
          id: id,
          title: d.title?.toDartString() ?? id,
          description:
              (unlocked ? d.achievedDescription : d.unachievedDescription)
                  ?.toDartString(),
          isUnlocked: unlocked,
          isHidden: d.isHidden,
          // GameKit models progress as a 0–100 percentage. We surface it as
          // steps-out-of-100 to fit the unified incremental model.
          currentSteps: percent.round(),
          totalSteps: 100,
        ),
      );
    }
    return result;
  }

  @override
  Future<void> unlockAchievement(String achievementId) =>
      _reportAchievement(resolveAchievementId(achievementId), 100.0);

  @override
  Future<void> incrementAchievement(String achievementId, int steps) async {
    // GameKit has no atomic increment; read the current percentage and add.
    // `steps` are interpreted as percentage points (totalSteps == 100).
    final id = resolveAchievementId(achievementId);
    final current = await getAchievements();
    var existing = 0;
    for (final a in current) {
      if (a.id == id) {
        existing = a.currentSteps;
        break;
      }
    }
    final next = (existing + steps).clamp(0, 100).toDouble();
    await _reportAchievement(id, next);
  }

  @override
  Future<void> revealAchievement(String achievementId) =>
      // Reporting 0% reveals a hidden achievement without completing it.
      _reportAchievement(
        resolveAchievementId(achievementId),
        0.0,
        banner: false,
      );

  Future<void> _reportAchievement(
    String id,
    double percent, {
    bool banner = true,
  }) async {
    _requireSignedIn();
    final achievement = GKAchievement.alloc().initWithIdentifier(
      id.toNSString(),
    );
    achievement.percentComplete = percent;
    achievement.showsCompletionBanner = banner;
    await _runVoid(
      (handler) => GKAchievement.reportAchievements(
        objc.NSArray.of([achievement]),
        withCompletionHandler: handler,
      ),
      'reportAchievement',
    );
    if (percent >= 100.0) {
      _events.add(
        AchievementUnlockedEvent(
          achievement: Achievement(
            id: id,
            title: id,
            isUnlocked: true,
            currentSteps: 100,
            totalSteps: 100,
          ),
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    _requireSignedIn();
    final board = await _loadLeaderboard(resolveLeaderboardId(leaderboardId));
    await _runVoid(
      (handler) => board.submitScore(
        score,
        context: 0,
        player: _local,
        completionHandler: handler,
      ),
      'submitScore',
    );
    _events.add(
      ScoreSubmittedEvent(
        leaderboardId: leaderboardId,
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
    _requireSignedIn();
    final board = await _loadLeaderboard(resolveLeaderboardId(leaderboardId));
    final completer = Completer<Leaderboard>();
    final range = pkg_ffi.calloc<objc.NSRange>()
      ..ref.location = 1
      ..ref.length = maxResults < 1 ? 1 : maxResults;
    board.loadEntriesForPlayerScope(
      _playerScope(collection),
      timeScope: _timeScope(timeScope),
      range: range.ref,
      completionHandler:
          ObjCBlock_ffiVoid_GKLeaderboardEntry_NSArray_NSInteger_NSError.fromFunction(
            (
              GKLeaderboardEntry localEntry,
              objc.NSArray? entries,
              int totalCount,
              objc.NSError? error,
            ) {
              pkg_ffi.calloc.free(range);
              if (completer.isCompleted) return;
              if (error != null) {
                completer.completeError(_mapError(error, 'getLeaderboard'));
                return;
              }
              final rows = <LeaderboardEntry>[
                if (entries != null)
                  for (final obj in entries.asDart())
                    _entryOf(GKLeaderboardEntry.as(obj)),
              ];
              completer.complete(
                Leaderboard(
                  id: leaderboardId,
                  displayName: board.title?.toDartString(),
                  timeScope: timeScope,
                  collection: collection,
                  entries: rows,
                  playerEntry: _maybeEntryOf(localEntry),
                ),
              );
            },
          ),
    );
    return completer.future;
  }

  @override
  Future<LeaderboardEntry?> getPlayerScore(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
  }) async {
    final board = await getLeaderboard(
      leaderboardId,
      timeScope: timeScope,
      maxResults: 1,
    );
    return board.playerEntry;
  }

  Future<GKLeaderboard> _loadLeaderboard(String id) async {
    final array = await _loadArrayWith(
      (handler) => GKLeaderboard.loadLeaderboardsWithIDs(
        objc.NSArray.of([id.toNSString()]),
        completionHandler: handler,
      ),
      'loadLeaderboard',
    );
    final list = array.asDart();
    if (list.isEmpty) {
      throw PlatformOperationException(
        'No Game Center leaderboard with id "$id".',
      );
    }
    return GKLeaderboard.as(list.first);
  }

  LeaderboardEntry _entryOf(GKLeaderboardEntry e) {
    final player = e.player;
    return LeaderboardEntry(
      rank: e.rank,
      player: PlayerProfile(
        id: player.gamePlayerID.toDartString(),
        displayName: player.displayName.toDartString(),
      ),
      score: e.score,
      formattedScore: e.formattedScore.toDartString(),
      achievedAt: e.date.toDateTime(),
    );
  }

  /// Like [_entryOf], but returns `null` when GameKit handed back a nil entry
  /// (the local player has no score on this board).
  LeaderboardEntry? _maybeEntryOf(GKLeaderboardEntry e) =>
      e.ref.pointer.address == 0 ? null : _entryOf(e);

  GKLeaderboardPlayerScope _playerScope(LeaderboardCollection c) => switch (c) {
    LeaderboardCollection.global =>
      GKLeaderboardPlayerScope.GKLeaderboardPlayerScopeGlobal,
    LeaderboardCollection.friends =>
      GKLeaderboardPlayerScope.GKLeaderboardPlayerScopeFriendsOnly,
  };

  GKLeaderboardTimeScope _timeScope(LeaderboardTimeScope t) => switch (t) {
    LeaderboardTimeScope.allTime =>
      GKLeaderboardTimeScope.GKLeaderboardTimeScopeAllTime,
    LeaderboardTimeScope.weekly =>
      GKLeaderboardTimeScope.GKLeaderboardTimeScopeWeek,
    LeaderboardTimeScope.daily =>
      GKLeaderboardTimeScope.GKLeaderboardTimeScopeToday,
  };

  // ─── Async / error plumbing ────────────────────────────────────────────────

  /// Runs a GameKit call whose completion handler is `(NSArray?, NSError?)`.
  Future<objc.NSArray> _loadArray(
    void Function(
      objc.ObjCBlock<ffi.Void Function(objc.NSArray?, objc.NSError?)>?,
    )
    call,
    String op,
  ) => _loadArrayWith((handler) => call(handler), op);

  Future<objc.NSArray> _loadArrayWith(
    void Function(
      objc.ObjCBlock<ffi.Void Function(objc.NSArray?, objc.NSError?)> handler,
    )
    call,
    String op,
  ) {
    final completer = Completer<objc.NSArray>();
    call(
      ObjCBlock_ffiVoid_NSArray_NSError.fromFunction((
        objc.NSArray? array,
        objc.NSError? error,
      ) {
        if (completer.isCompleted) return;
        if (error != null) {
          completer.completeError(_mapError(error, op));
        } else {
          completer.complete(array ?? objc.NSArray.of(const []));
        }
      }),
    );
    return completer.future;
  }

  /// Runs a GameKit call whose completion handler is `(NSError?)`.
  Future<void> _runVoid(
    void Function(objc.ObjCBlock<ffi.Void Function(objc.NSError?)> handler)
    call,
    String op,
  ) {
    final completer = Completer<void>();
    call(
      ObjCBlock_ffiVoid_NSError.fromFunction((objc.NSError? error) {
        if (completer.isCompleted) return;
        if (error != null) {
          completer.completeError(_mapError(error, op));
        } else {
          completer.complete();
        }
      }),
    );
    return completer.future;
  }

  /// Maps an `NSError` from `GKErrorDomain` onto the unified exception types.
  GameServiceException _mapError(objc.NSError error, String op) {
    final code = error.code;
    final message = error.localizedDescription.toDartString();
    // GKErrorCode values (GKError.h).
    const notAuthenticated = 6;
    const communicationsFailure = 3;
    const cancelled = 2;
    return switch (code) {
      notAuthenticated => const NotSignedInException(),
      communicationsFailure => NetworkException(message),
      cancelled => SignInFailedException(message),
      _ => PlatformOperationException('$op failed: $message', code: '$code'),
    };
  }
}
