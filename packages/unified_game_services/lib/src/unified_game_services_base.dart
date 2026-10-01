import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart' show StreamGroup;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'multi_provider_result.dart';

/// The app-facing entry point: one API over one or many game-service providers.
///
/// With a single provider it simply delegates. With several it **fans out**
/// write operations to every provider that supports the relevant capability —
/// so a score or achievement can be published to Steam, Epic and GameJolt at
/// once — while **read** operations come from a single provider ([primary] by
/// default, or one chosen with `from:`).
///
/// Writes return a [MultiProviderOperationResult]: a provider failing does not
/// throw, it shows up in `result.failed` while the others still succeed.
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
  /// Wraps the given [providers] in a standalone facade (not the global one;
  /// see `GameServices.initialize` for that).
  ///
  /// Throws [ArgumentError] if [providers] is empty.
  UnifiedGameServices({required List<UnifiedGameServicesPlatform> providers})
    : providers = List.unmodifiable(providers) {
    if (providers.isEmpty) {
      throw ArgumentError.value(
        providers,
        'providers',
        'At least one provider is required.',
      );
    }
  }

  /// The providers this facade operates over, in priority order.
  final List<UnifiedGameServicesPlatform> providers;

  /// The provider used for read operations by default (the first one).
  UnifiedGameServicesPlatform get primary => providers.first;

  /// Whether **any** provider supports [capability].
  bool supports(GameCapability capability) =>
      providers.any((p) => p.supports(capability));

  /// The union of every provider's capabilities.
  Set<GameCapability> get capabilities => {
    for (final p in providers) ...p.capabilities,
  };

  /// The configured providers that advertise [capability], in priority order.
  ///
  /// Empty when none does. This is exactly the set a write fan-out for
  /// [capability] targets.
  List<UnifiedGameServicesPlatform> providersFor(GameCapability capability) =>
      providers.where((p) => p.supports(capability)).toList(growable: false);

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

  /// Signs in on every provider; each result carries that provider's profile.
  Future<MultiProviderOperationResult<PlayerProfile?>> signIn() => _runAll(
    'signIn',
    providers,
    (p) async => (await p.signIn())?.copyWith(providerId: p.providerId),
  );

  /// Signs out of every provider.
  Future<MultiProviderOperationResult<void>> signOut() =>
      _runAll('signOut', providers, (p) => p.signOut());

  /// The current player from [from] (defaults to [primary]).
  Future<PlayerProfile?> getCurrentPlayer({
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = from ?? primary;
    return (await p.getCurrentPlayer())?.copyWith(providerId: p.providerId);
  }

  // ─── Achievements ──────────────────────────────────────────────────────────

  /// Achievements from [from] (defaults to [primary]), each tagged with the
  /// source `providerId`.
  Future<List<Achievement>> getAchievements({
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = from ?? primary;
    return [
      for (final a in await p.getAchievements())
        a.copyWith(providerId: p.providerId),
    ];
  }

  /// Unlocks an achievement on every provider that supports achievements.
  Future<MultiProviderOperationResult<void>> unlockAchievement(
    String achievementId,
  ) => _fanOut(
    GameCapability.achievements,
    'unlockAchievement',
    (p) => p.unlockAchievement(achievementId),
  );

  /// Adds incremental progress on every provider that supports achievements.
  Future<MultiProviderOperationResult<void>> incrementAchievement(
    String achievementId,
    int steps,
  ) => _fanOut(
    GameCapability.achievements,
    'incrementAchievement',
    (p) => p.incrementAchievement(achievementId, steps),
  );

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  /// Submits a score to every provider that supports leaderboards.
  Future<MultiProviderOperationResult<void>> submitScore({
    required String leaderboardId,
    required int score,
  }) => _fanOut(
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
  }) async {
    final p = from ?? primary;
    final board = await p.getLeaderboard(
      leaderboardId,
      timeScope: timeScope,
      collection: collection,
      maxResults: maxResults,
    );
    final id = p.providerId;
    LeaderboardEntry tag(LeaderboardEntry e) =>
        e.copyWith(player: e.player.copyWith(providerId: id));
    return board.copyWith(
      providerId: id,
      entries: [for (final e in board.entries) tag(e)],
      playerEntry: board.playerEntry == null ? null : tag(board.playerEntry!),
    );
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  /// Sets a stat on every provider that supports stats.
  Future<MultiProviderOperationResult<void>> setStat(String key, num value) =>
      _fanOut(GameCapability.stats, 'setStat', (p) => p.setStat(key, value));

  /// Increments a stat on every provider that supports stats.
  Future<MultiProviderOperationResult<void>> incrementStat(
    String key, {
    num by = 1,
  }) => _fanOut(
    GameCapability.stats,
    'incrementStat',
    (p) => p.incrementStat(key, by: by),
  );

  /// Reads a stat from [from] (defaults to [primary]).
  Future<Stat?> getStat(String key, {UnifiedGameServicesPlatform? from}) async {
    final p = from ?? primary;
    return (await p.getStat(key))?.copyWith(providerId: p.providerId);
  }

  // ─── Cloud save ────────────────────────────────────────────────────────────

  /// Writes a save to every provider that supports cloud save.
  Future<MultiProviderOperationResult<void>> saveData(
    String slot,
    Uint8List data,
  ) => _fanOut(
    GameCapability.cloudSave,
    'saveData',
    (p) => p.saveData(slot, data),
  );

  /// Loads a save from [from] (defaults to [primary]).
  Future<CloudSave?> loadData(
    String slot, {
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = from ?? primary;
    final save = await p.loadData(slot);
    return save?.copyWith(
      metadata: save.metadata.copyWith(providerId: p.providerId),
    );
  }

  // ─── Presence ──────────────────────────────────────────────────────────────

  /// Publishes presence on every provider that supports it.
  Future<MultiProviderOperationResult<void>> setPresence(
    RichPresence presence,
  ) => _fanOut(
    GameCapability.presence,
    'setPresence',
    (p) => p.setPresence(presence),
  );

  /// Clears presence on every provider that supports it.
  Future<MultiProviderOperationResult<void>> clearPresence() => _fanOut(
    GameCapability.presence,
    'clearPresence',
    (p) => p.clearPresence(),
  );

  // ─── Friends ─────────────────────────────────────────────────────────────

  /// Friends from [from] (defaults to [primary]).
  Future<List<PlayerProfile>> getFriends({
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = from ?? primary;
    return [
      for (final f in await p.getFriends())
        f.copyWith(providerId: p.providerId),
    ];
  }

  // ─── Fan-out helpers ─────────────────────────────────────────────────────

  /// Runs [op] on every provider that supports [capability].
  ///
  /// Provider failures are returned in the result, never thrown. Throws
  /// [CapabilityNotSupportedException] only when no provider supports
  /// [capability] (nothing was attempted).
  Future<MultiProviderOperationResult<void>> _fanOut(
    GameCapability capability,
    String operation,
    Future<void> Function(UnifiedGameServicesPlatform) op,
  ) {
    final targets = providersFor(capability);
    if (targets.isEmpty) throw CapabilityNotSupportedException(capability);
    return _runAll(operation, targets, op);
  }

  /// Disposes every provider (timers, HTTP clients, native SDK handles).
  ///
  /// Call once the facade is no longer needed. Every provider is disposed even
  /// if another fails; failures are reported in the result.
  Future<MultiProviderOperationResult<void>> dispose() =>
      _runAll('dispose', providers, (p) => p.dispose());

  /// Runs [op] on every one of [targets] concurrently, capturing each outcome.
  Future<MultiProviderOperationResult<T>> _runAll<T>(
    String operation,
    List<UnifiedGameServicesPlatform> targets,
    Future<T> Function(UnifiedGameServicesPlatform) op,
  ) async {
    final results = await Future.wait(
      targets.map((p) async {
        try {
          return ProviderOperationResult<T>.success(p.providerId, await op(p));
        } catch (e, st) {
          return ProviderOperationResult<T>.fromError(p.providerId, e, st);
        }
      }),
    );
    return MultiProviderOperationResult<T>(operation, results);
  }
}
