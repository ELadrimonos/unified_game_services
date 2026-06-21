import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart' show StreamGroup;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'aggregate_exception.dart';

/// The app-facing entry point: one API over one or many game-service providers.
///
/// With a single provider it simply delegates. With several it **fans out**
/// write operations to every provider that supports the relevant capability —
/// so a score or achievement can be published to Steam, Epic and GameJolt at
/// once — while **read** operations come from a single provider ([primary] by
/// default, or one chosen with `from:`).
///
/// ```dart
/// final services = UnifiedGameServices(providers: [
///   SteamProvider(),
///   GameJoltProvider(gameId: '…', privateKey: '…', username: '…', userToken: '…'),
/// ]);
/// await services.signIn();
/// await services.submitScore(leaderboardId: 'global', score: 1500); // both
/// final mine = await services.getAchievements(); // primary only
/// ```
class UnifiedGameServices {
  /// Wraps the given [providers].
  ///
  /// If [providers] is null or empty, the currently registered
  /// [UnifiedGameServicesPlatform.instance] is used (single-provider mode).
  UnifiedGameServices({List<UnifiedGameServicesPlatform>? providers})
      : providers = List.unmodifiable(
          (providers == null || providers.isEmpty)
              ? [UnifiedGameServicesPlatform.instance]
              : providers,
        );

  /// The providers this facade operates over, in priority order.
  final List<UnifiedGameServicesPlatform> providers;

  /// The provider used for read operations by default (the first one).
  UnifiedGameServicesPlatform get primary => providers.first;

  /// Whether **any** provider supports [capability].
  bool supports(GameCapability capability) =>
      providers.any((p) => p.supports(capability));

  /// Whether **every** provider supports [capability].
  bool supportsEverywhere(GameCapability capability) =>
      providers.every((p) => p.supports(capability));

  /// The first provider of concrete type [T], or `null` — for reaching a
  /// provider's provider-specific API (e.g. `provider<GameJoltProvider>()`).
  T? provider<T extends UnifiedGameServicesPlatform>() {
    for (final p in providers) {
      if (p is T) return p;
    }
    return null;
  }

  /// Merged event stream across all providers.
  Stream<GameServiceEvent> get events =>
      StreamGroup.merge(providers.map((p) => p.events));

  // ─── Authentication (fan-out) ──────────────────────────────────────────────

  /// Signs in on every provider and returns the [primary] player's profile.
  Future<PlayerProfile?> signIn() async {
    await _fanOutAll('signIn', (p) => p.signIn());
    return primary.getCurrentPlayer();
  }

  /// Signs out of every provider.
  Future<void> signOut() => _fanOutAll('signOut', (p) => p.signOut());

  /// The current player from [from] (defaults to [primary]).
  Future<PlayerProfile?> getCurrentPlayer({
    UnifiedGameServicesPlatform? from,
  }) =>
      (from ?? primary).getCurrentPlayer();

  // ─── Achievements ──────────────────────────────────────────────────────────

  /// Achievements from [from] (defaults to [primary]).
  Future<List<Achievement>> getAchievements({
    UnifiedGameServicesPlatform? from,
  }) =>
      (from ?? primary).getAchievements();

  /// Unlocks an achievement on every provider that supports achievements.
  Future<void> unlockAchievement(String achievementId) => _fanOut(
        GameCapability.achievements,
        'unlockAchievement',
        (p) => p.unlockAchievement(achievementId),
      );

  /// Adds incremental progress on every provider that supports achievements.
  Future<void> incrementAchievement(String achievementId, int steps) =>
      _fanOut(
        GameCapability.achievements,
        'incrementAchievement',
        (p) => p.incrementAchievement(achievementId, steps),
      );

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  /// Submits a score to every provider that supports leaderboards.
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) =>
      _fanOut(
        GameCapability.leaderboards,
        'submitScore',
        (p) => p.submitScore(leaderboardId: leaderboardId, score: score),
      );

  /// Fetches a leaderboard from [from] (defaults to [primary]).
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
    UnifiedGameServicesPlatform? from,
  }) =>
      (from ?? primary).getLeaderboard(
        leaderboardId,
        timeScope: timeScope,
        collection: collection,
        maxResults: maxResults,
      );

  // ─── Stats ───────────────────────────────────────────────────────────────

  /// Sets a stat on every provider that supports stats.
  Future<void> setStat(String key, num value) => _fanOut(
        GameCapability.stats,
        'setStat',
        (p) => p.setStat(key, value),
      );

  /// Increments a stat on every provider that supports stats.
  Future<void> incrementStat(String key, {num by = 1}) => _fanOut(
        GameCapability.stats,
        'incrementStat',
        (p) => p.incrementStat(key, by: by),
      );

  /// Reads a stat from [from] (defaults to [primary]).
  Future<Stat?> getStat(String key, {UnifiedGameServicesPlatform? from}) =>
      (from ?? primary).getStat(key);

  // ─── Cloud save ────────────────────────────────────────────────────────────

  /// Writes a save to every provider that supports cloud save.
  Future<void> saveData(String slot, Uint8List data) => _fanOut(
        GameCapability.cloudSave,
        'saveData',
        (p) => p.saveData(slot, data),
      );

  /// Loads a save from [from] (defaults to [primary]).
  Future<CloudSave?> loadData(String slot, {
    UnifiedGameServicesPlatform? from,
  }) =>
      (from ?? primary).loadData(slot);

  // ─── Presence ──────────────────────────────────────────────────────────────

  /// Publishes presence on every provider that supports it.
  Future<void> setPresence(RichPresence presence) => _fanOut(
        GameCapability.presence,
        'setPresence',
        (p) => p.setPresence(presence),
      );

  /// Clears presence on every provider that supports it.
  Future<void> clearPresence() => _fanOut(
        GameCapability.presence,
        'clearPresence',
        (p) => p.clearPresence(),
      );

  // ─── Friends ─────────────────────────────────────────────────────────────

  /// Friends from [from] (defaults to [primary]).
  Future<List<PlayerProfile>> getFriends({
    UnifiedGameServicesPlatform? from,
  }) =>
      (from ?? primary).getFriends();

  // ─── Fan-out helpers ─────────────────────────────────────────────────────

  /// Runs [op] on every provider that supports [capability], best-effort.
  ///
  /// Throws [CapabilityNotSupportedException] if no provider supports it, or
  /// [AggregateGameServiceException] if some providers fail.
  Future<void> _fanOut(
    GameCapability capability,
    String operation,
    Future<void> Function(UnifiedGameServicesPlatform) op,
  ) async {
    final targets =
        providers.where((p) => p.supports(capability)).toList(growable: false);
    if (targets.isEmpty) throw CapabilityNotSupportedException(capability);
    await _runAll(operation, targets, op);
  }

  /// Runs [op] on every provider, best-effort (not capability-gated).
  Future<void> _fanOutAll(
    String operation,
    Future<void> Function(UnifiedGameServicesPlatform) op,
  ) =>
      _runAll(operation, providers, op);

  Future<void> _runAll(
    String operation,
    List<UnifiedGameServicesPlatform> targets,
    Future<void> Function(UnifiedGameServicesPlatform) op,
  ) async {
    final errors = <Object>[];
    await Future.wait(targets.map((p) async {
      try {
        await op(p);
      } catch (e) {
        errors.add(e);
      }
    }));
    if (errors.isNotEmpty) {
      throw AggregateGameServiceException(operation, errors);
    }
  }
}
