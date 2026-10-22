/// @docImport 'game_services.dart';
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart' show StreamGroup;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'multi_provider_result.dart';
import 'achievement_overview.dart';

/// The app-facing entry point: one API over one or many game-service providers.
///
/// With a single provider it simply delegates. With several it **fans out**
/// write operations to every provider that advertises the relevant
/// [GameCapability] (see [providersFor]) — so a score or achievement can be
/// published to Steam, Epic and GameJolt at once — while **read** operations
/// come from a single provider ([primary] by default, or one chosen with
/// `from:`). Lifecycle calls ([signIn], [signOut], [dispose]) are not
/// capability-gated and go to every provider.
///
/// Writes return a [MultiProviderOperationResult]: a provider failing does not
/// throw, it shows up in `result.failed` while the others still succeed. The
/// only exception is [CapabilityNotSupportedException], thrown when a write (or
/// a `*FromAll` read) finds no provider with the capability, since nothing was
/// attempted.
///
/// Single-provider reads (`from:` / [primary]) are not capability-gated: they
/// call the provider directly, tag the results with its `providerId`, and let
/// its errors propagate. A provider that does not implement the operation
/// typically throws [UnimplementedError] or
/// [CapabilityNotSupportedException]; check [supports] or [providersFor]
/// first.
///
/// Unified ids are translated by the provider, not the facade: the
/// `achievements`, `leaderboards` and `stats` tables given to the constructor
/// are registered on each provider, which resolves unified ids to native ones
/// on writes and reads. Ids without a table row pass through unchanged.
///
/// ```dart
/// final services = UnifiedGameServices(
///   providers: [
///     SteamProvider(),
///     GameJoltProvider(
///       gameId: '…',
///       privateKey: '…',
///       username: '…',
///       userToken: '…',
///     ),
///   ],
///   achievements: UnifiedAchievementTable({
///     'first_win': {'steam': 'ACH_WIN', 'gamejolt': '1234'},
///   }),
/// );
/// await services.signIn();
/// await services.submitScore(leaderboardId: 'global', score: 1500); // both
/// final mine = await services.getAchievements(); // primary only
/// final both = await services.getAchievementOverview(); // merged by id
/// ```
class UnifiedGameServices {
  /// Wraps the given [providers] in a standalone facade (not the global one;
  /// see [GameServices.initialize] for that).
  ///
  /// [providers] are in priority order: the first is the [primary] and is
  /// the default source for reads; the list is copied.
  ///
  /// [achievements], [leaderboards] and [stats] map a unified id to each
  /// provider's native id. They are registered on every provider through
  /// [UnifiedGameServicesPlatform.registerMappings] (adding to, not replacing,
  /// mappings already there), and [achievements] and [stats] also translate
  /// native ids back to unified ones on reads.
  ///
  /// Throws [ArgumentError] if [providers] is empty.
  UnifiedGameServices({
    required List<UnifiedGameServicesPlatform> providers,
    UnifiedAchievementTable? achievements,
    UnifiedLeaderboardTable? leaderboards,
    UnifiedStatTable? stats,
  }) : providers = List.unmodifiable(providers),
       _achievementTable = achievements,
       _leaderboardTable = leaderboards,
       _statTable = stats {
    if (providers.isEmpty) {
      throw ArgumentError.value(
        providers,
        'providers',
        'At least one provider is required.',
      );
    }
    for (final p in providers) {
      _reverse[p] = achievements?.reverseForProvider(p.providerId) ?? {};
      p.registerMappings(
        achievementIds: achievements?.forProvider(p.providerId),
        leaderboardIds: leaderboards?.forProvider(p.providerId),
        statIds: stats?.forProvider(p.providerId),
      );
    }
  }

  final UnifiedAchievementTable? _achievementTable;
  final UnifiedLeaderboardTable? _leaderboardTable;
  final UnifiedStatTable? _statTable;

  /// Native -> unified achievement id per provider, used to translate reads.
  final Map<UnifiedGameServicesPlatform, Map<String, String>> _reverse =
      Map.identity();

  /// The providers this facade operates over, in priority order.
  ///
  /// Unmodifiable. Fan-out results are reported in this order.
  final List<UnifiedGameServicesPlatform> providers;

  /// The provider used for single-provider reads when `from:` is omitted (the
  /// first of [providers]).
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

  /// The first provider of concrete type [T], or `null` if there is none.
  ///
  /// For reaching a provider's provider-specific API:
  ///
  /// ```dart
  /// final jolt = services.provider<GameJoltProvider>();
  /// await jolt?.openSession();
  /// ```
  T? provider<T extends UnifiedGameServicesPlatform>() {
    for (final p in providers) {
      if (p is T) return p;
    }
    return null;
  }

  /// A merged stream of the events of every provider.
  ///
  /// Each access builds a new merged stream; ordering across providers is by
  /// arrival. A provider that does not implement `events` throws
  /// [UnimplementedError] from its getter, so accessing this does too.
  Stream<GameServiceEvent> get events =>
      StreamGroup.merge(providers.map((p) => p.events));

  // ─── Authentication (fan-out) ──────────────────────────────────────────────

  /// Signs in on every provider, concurrently.
  ///
  /// Each success carries that provider's [PlayerProfile] (tagged with its
  /// `providerId`), or `null` if the provider yields no profile. Not
  /// capability-gated; failures such as [SignInFailedException] are returned
  /// in the result, not thrown.
  Future<MultiProviderOperationResult<PlayerProfile?>> signIn() => _runAll(
    'signIn',
    providers,
    (p) async => (await p.signIn())?.copyWith(providerId: p.providerId),
  );

  /// Signs out of every provider, concurrently.
  ///
  /// Not capability-gated; failures are returned in the result.
  Future<MultiProviderOperationResult<void>> signOut() =>
      _runAll('signOut', providers, (p) => p.signOut());

  /// The signed-in player on [from] (defaults to [primary]), tagged with the
  /// provider's `providerId`.
  ///
  /// Returns `null` when nobody is signed in. Provider errors propagate.
  Future<PlayerProfile?> getCurrentPlayer({
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = from ?? primary;
    return (await p.getCurrentPlayer())?.copyWith(providerId: p.providerId);
  }

  /// Whether a player is signed in on [from] (defaults to [primary]).
  Future<bool> isSignedIn({UnifiedGameServicesPlatform? from}) =>
      (from ?? primary).isSignedIn();

  /// The current player on **every** provider (no capability gate: each
  /// provider is asked), one result per provider; `value` is `null` where
  /// nobody is signed in.
  ///
  /// Meant for debugging sign-in state; failures are returned, not thrown.
  Future<MultiProviderOperationResult<PlayerProfile?>>
  getCurrentPlayerFromAll() =>
      _runAll('getCurrentPlayer', providers, (p) => getCurrentPlayer(from: p));

  // ─── Achievements ──────────────────────────────────────────────────────────

  /// Achievements from [from] (defaults to [primary]), each tagged with the
  /// source `providerId`.
  ///
  /// With an `achievements` table, [Achievement.id] is the unified id and
  /// [Achievement.nativeIds] lists the native ids per provider; an achievement
  /// with no table row keeps its native id. Provider errors propagate.
  Future<List<Achievement>> getAchievements({
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = _reader(GameCapability.achievements, from);
    return _unifiedAchievements(p, await p.getAchievements());
  }

  /// Reads achievements from **every** provider that supports them, one
  /// result per provider (unlike [getAchievementOverview], which merges them).
  ///
  /// Meant for debugging and diffing providers: a provider failing is an
  /// [OperationFailure] in the result, never thrown. Throws
  /// [CapabilityNotSupportedException] when no provider supports achievements.
  Future<MultiProviderOperationResult<List<Achievement>>>
  getAchievementsFromAll() => _readAll(
    GameCapability.achievements,
    'getAchievements',
    (p) => getAchievements(from: p),
  );

  /// Translates [achievements] read from [p] to unified ids: `id` becomes the
  /// table key (or stays native when unmapped), `nativeId` keeps the original.
  List<Achievement> _unifiedAchievements(
    UnifiedGameServicesPlatform p,
    List<Achievement> achievements,
  ) {
    final reverse = _reverse[p] ?? const <String, String>{};
    return [
      for (final a in achievements)
        a.copyWith(
          id: reverse[a.id],
          nativeIds: _withOwn(
            _achievementTable?.nativeIdsFor(reverse[a.id] ?? a.id),
            p,
            a.id,
          ),
          providerId: p.providerId,
        ),
    ];
  }

  /// Reads achievements from **every** provider that supports them and merges
  /// them by unified id, so each [AchievementStatus] says on which providers
  /// it is unlocked.
  ///
  /// A provider that fails is reported in [AchievementOverview.failed], not
  /// thrown. Throws [CapabilityNotSupportedException] when no provider supports
  /// achievements.
  ///
  /// ```dart
  /// final overview = await services.getAchievementOverview();
  /// for (final a in overview.achievements) {
  ///   print('${a.id}: unlocked on ${a.unlockedOn}, locked on ${a.lockedOn}');
  /// }
  /// ```
  Future<AchievementOverview> getAchievementOverview() async {
    final targets = providersFor(GameCapability.achievements);
    if (targets.isEmpty) {
      throw CapabilityNotSupportedException(GameCapability.achievements);
    }
    final read = await _runAll(
      'getAchievements',
      targets,
      (p) async => _unifiedAchievements(p, await p.getAchievements()),
    );
    final merged = <String, Map<String, Achievement>>{};
    for (final r in read.succeeded) {
      for (final a in r.value) {
        (merged[a.id] ??= {})[r.providerId] = a;
      }
    }
    return AchievementOverview([
      for (final e in merged.entries) AchievementStatus(e.key, e.value),
    ], read.failed);
  }

  /// Unlocks, on every provider where an achievement is still locked, whatever
  /// is already unlocked on another provider.
  ///
  /// One-way by nature: achievements cannot be re-locked. Only providers that
  /// list the achievement are touched, and incremental progress is not copied
  /// (only completed unlocks). Each provider that needed an unlock gets one
  /// result entry; its unlocks run sequentially and the entry fails at the
  /// first one that throws (later ones for that provider are skipped).
  /// Providers already in sync have no entry, so the result may be empty.
  /// Providers that could not be read are skipped silently — call
  /// [getAchievementOverview] to see them in `failed`.
  ///
  /// Throws [CapabilityNotSupportedException] when no provider supports
  /// achievements.
  Future<MultiProviderOperationResult<void>> syncAchievements() async {
    final overview = await getAchievementOverview();
    final byId = {for (final p in providers) p.providerId: p};
    final pending = <String, List<String>>{};
    for (final a in overview.achievements) {
      if (!a.isUnlockedAnywhere) continue;
      for (final providerId in a.lockedOn) {
        (pending[providerId] ??= []).add(a.id);
      }
    }
    return _runAll(
      'syncAchievements',
      [for (final id in pending.keys) byId[id]!],
      (p) async {
        for (final id in pending[p.providerId]!) {
          await p.unlockAchievement(id);
        }
      },
    );
  }

  /// Unlocks [achievementId] (a unified id, or a native one when unmapped) on
  /// every provider that supports achievements.
  ///
  /// Throws [CapabilityNotSupportedException] when none does.
  Future<MultiProviderOperationResult<void>> unlockAchievement(
    String achievementId,
  ) => _fanOut(
    GameCapability.achievements,
    'unlockAchievement',
    (p) => p.unlockAchievement(achievementId),
  );

  /// Adds [steps] of progress to the incremental achievement [achievementId]
  /// on every provider that supports achievements.
  ///
  /// Throws [CapabilityNotSupportedException] when none does.
  Future<MultiProviderOperationResult<void>> incrementAchievement(
    String achievementId,
    int steps,
  ) => _fanOut(
    GameCapability.achievements,
    'incrementAchievement',
    (p) => p.incrementAchievement(achievementId, steps),
  );

  /// Reveals a hidden achievement on every provider that supports achievements.
  Future<MultiProviderOperationResult<void>> revealAchievement(
    String achievementId,
  ) => _fanOut(
    GameCapability.achievements,
    'revealAchievement',
    (p) => p.revealAchievement(achievementId),
  );

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  /// Submits [score] to [leaderboardId] on every provider that supports
  /// leaderboards.
  ///
  /// [leaderboardId] is a unified id, resolved to each provider's native id
  /// when a `leaderboards` table maps it. Throws
  /// [CapabilityNotSupportedException] when no provider supports leaderboards.
  Future<MultiProviderOperationResult<void>> submitScore({
    required String leaderboardId,
    required int score,
  }) => _fanOut(
    GameCapability.leaderboards,
    'submitScore',
    (p) => p.submitScore(leaderboardId: leaderboardId, score: score),
  );

  /// Fetches the leaderboard [leaderboardId] from [from] (defaults to
  /// [primary]).
  ///
  /// The returned [Leaderboard] and its entries are tagged with the provider's
  /// `providerId`, its `id` is the unified [leaderboardId] and `nativeIds`
  /// lists the native ids. [maxResults] caps the entries requested. Provider
  /// errors propagate.
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = _reader(GameCapability.leaderboards, from);
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
      id: leaderboardId,
      nativeIds: _withOwn(
        _leaderboardTable?.nativeIdsFor(leaderboardId),
        p,
        p.resolveLeaderboardId(leaderboardId),
      ),
      providerId: id,
      entries: [for (final e in board.entries) tag(e)],
      playerEntry: board.playerEntry == null ? null : tag(board.playerEntry!),
    );
  }

  /// The signed-in player's own entry on [leaderboardId] from [from] (defaults
  /// to [primary]), or `null` when they have none.
  ///
  /// Throws [CapabilityNotSupportedException] when [from] does not support
  /// leaderboards; other provider errors propagate.
  Future<LeaderboardEntry?> getPlayerScore(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = _reader(GameCapability.leaderboards, from);
    final entry = await p.getPlayerScore(leaderboardId, timeScope: timeScope);
    return entry?.copyWith(
      player: entry.player.copyWith(providerId: p.providerId),
    );
  }

  /// The player's own entry on [leaderboardId] from **every** provider that
  /// supports leaderboards, one result per provider (`value` is `null` where
  /// the player has no entry).
  ///
  /// Failures are returned, not thrown. Throws
  /// [CapabilityNotSupportedException] when no provider supports leaderboards.
  Future<MultiProviderOperationResult<LeaderboardEntry?>> getPlayerScoreFromAll(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
  }) => _readAll(
    GameCapability.leaderboards,
    'getPlayerScore',
    (p) => getPlayerScore(leaderboardId, timeScope: timeScope, from: p),
  );

  /// Fetches a leaderboard from **every** provider that supports leaderboards,
  /// one result per provider. Each [Leaderboard] keeps its own `providerId`.
  ///
  /// Meant for debugging and comparing providers; failures are returned, not
  /// thrown. Throws [CapabilityNotSupportedException] when no provider
  /// supports leaderboards.
  Future<MultiProviderOperationResult<Leaderboard>> getLeaderboardFromAll(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) => _readAll(
    GameCapability.leaderboards,
    'getLeaderboard',
    (p) => getLeaderboard(
      leaderboardId,
      timeScope: timeScope,
      collection: collection,
      maxResults: maxResults,
      from: p,
    ),
  );

  // ─── Stats ───────────────────────────────────────────────────────────────

  /// Sets the stat [key] to [value] on every provider that supports stats.
  ///
  /// Throws [CapabilityNotSupportedException] when none does.
  Future<MultiProviderOperationResult<void>> setStat(String key, num value) =>
      _fanOut(GameCapability.stats, 'setStat', (p) => p.setStat(key, value));

  /// Increases the stat [key] by [by] on every provider that supports stats.
  ///
  /// Throws [CapabilityNotSupportedException] when none does.
  Future<MultiProviderOperationResult<void>> incrementStat(
    String key, {
    num by = 1,
  }) => _fanOut(
    GameCapability.stats,
    'incrementStat',
    (p) => p.incrementStat(key, by: by),
  );

  /// Reads the stat [key] from [from] (defaults to [primary]), or `null` when
  /// the provider has no such stat.
  ///
  /// The returned [Stat] keeps the requested unified [key]. Provider errors
  /// propagate.
  Future<Stat?> getStat(String key, {UnifiedGameServicesPlatform? from}) async {
    final p = _reader(GameCapability.stats, from);
    return (await p.getStat(key))?.copyWith(
      key: key,
      nativeKeys: _withOwn(
        _statTable?.nativeIdsFor(key),
        p,
        p.resolveStatId(key),
      ),
      providerId: p.providerId,
    );
  }

  /// All stats of the signed-in player from [from] (defaults to [primary]),
  /// keyed by unified key (native key when unmapped) and tagged with the
  /// source `providerId`.
  ///
  /// Throws [CapabilityNotSupportedException] when [from] does not support
  /// stats; other provider errors propagate.
  Future<List<Stat>> getStats({UnifiedGameServicesPlatform? from}) async {
    final p = _reader(GameCapability.stats, from);
    final reverse =
        _statTable?.reverseForProvider(p.providerId) ??
        const <String, String>{};
    return [
      for (final s in await p.getStats())
        s.copyWith(
          key: reverse[s.key],
          nativeKeys: _withOwn(
            _statTable?.nativeIdsFor(reverse[s.key] ?? s.key),
            p,
            s.key,
          ),
          providerId: p.providerId,
        ),
    ];
  }

  /// Reads every stat from **every** provider that supports stats, one result
  /// per provider.
  ///
  /// Meant for debugging and diffing providers; failures are returned, not
  /// thrown. Throws [CapabilityNotSupportedException] when no provider
  /// supports stats.
  Future<MultiProviderOperationResult<List<Stat>>> getStatsFromAll() =>
      _readAll(GameCapability.stats, 'getStats', (p) => getStats(from: p));

  /// Reads the stat [key] from **every** provider that supports stats, one
  /// result per provider (`value` is `null` where the stat does not exist).
  Future<MultiProviderOperationResult<Stat?>> getStatFromAll(String key) =>
      _readAll(GameCapability.stats, 'getStat', (p) => getStat(key, from: p));

  // ─── Cloud save ────────────────────────────────────────────────────────────

  /// Writes [data] to the save [slot] on every provider that supports cloud
  /// save.
  ///
  /// Overwrites existing data in that slot on each provider. Throws
  /// [CapabilityNotSupportedException] when none does.
  Future<MultiProviderOperationResult<void>> saveData(
    String slot,
    Uint8List data,
  ) => _fanOut(
    GameCapability.cloudSave,
    'saveData',
    (p) => p.saveData(slot, data),
  );

  /// Loads the save [slot] from [from] (defaults to [primary]), or `null` when
  /// the slot is empty.
  ///
  /// Provider errors propagate.
  Future<CloudSave?> loadData(
    String slot, {
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = _reader(GameCapability.cloudSave, from);
    final save = await p.loadData(slot);
    return save?.copyWith(
      metadata: save.metadata.copyWith(providerId: p.providerId),
    );
  }

  /// Metadata of every save slot on [from] (defaults to [primary]), tagged
  /// with the source `providerId`.
  ///
  /// Throws [CapabilityNotSupportedException] when [from] does not support
  /// cloud save; other provider errors propagate.
  Future<List<CloudSaveMetadata>> listSaves({
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = _reader(GameCapability.cloudSave, from);
    return [
      for (final m in await p.listSaves()) m.copyWith(providerId: p.providerId),
    ];
  }

  /// Deletes a save from every provider that supports cloud save.
  Future<MultiProviderOperationResult<void>> deleteSave(String slot) => _fanOut(
    GameCapability.cloudSave,
    'deleteSave',
    (p) => p.deleteSave(slot),
  );

  /// Lists the save slots of **every** provider that supports cloud save, one
  /// result per provider. Handy to spot slots that exist on one store only.
  Future<MultiProviderOperationResult<List<CloudSaveMetadata>>>
  listSavesFromAll() => _readAll(
    GameCapability.cloudSave,
    'listSaves',
    (p) => listSaves(from: p),
  );

  /// Loads the save [slot] from **every** provider that supports cloud save,
  /// one result per provider (`value` is `null` where the slot is empty).
  Future<MultiProviderOperationResult<CloudSave?>> loadDataFromAll(
    String slot,
  ) => _readAll(
    GameCapability.cloudSave,
    'loadData',
    (p) => loadData(slot, from: p),
  );

  // ─── Presence ──────────────────────────────────────────────────────────────

  /// Publishes [presence] on every provider that supports it.
  ///
  /// Throws [CapabilityNotSupportedException] when none does.
  Future<MultiProviderOperationResult<void>> setPresence(
    RichPresence presence,
  ) => _fanOut(
    GameCapability.presence,
    'setPresence',
    (p) => p.setPresence(presence),
  );

  /// Clears the published presence on every provider that supports it.
  ///
  /// Throws [CapabilityNotSupportedException] when none does.
  Future<MultiProviderOperationResult<void>> clearPresence() => _fanOut(
    GameCapability.presence,
    'clearPresence',
    (p) => p.clearPresence(),
  );

  // ─── Friends ─────────────────────────────────────────────────────────────

  /// The friends list from [from] (defaults to [primary]), each profile tagged
  /// with the source `providerId`.
  ///
  /// Provider errors propagate.
  Future<List<PlayerProfile>> getFriends({
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = _reader(GameCapability.friends, from);
    return [
      for (final f in await p.getFriends())
        f.copyWith(providerId: p.providerId),
    ];
  }

  /// Friends from **every** provider that supports friends, one result per
  /// provider.
  ///
  /// Failures are returned, not thrown. Throws
  /// [CapabilityNotSupportedException] when no provider supports friends.
  Future<MultiProviderOperationResult<List<PlayerProfile>>>
  getFriendsFromAll() => _readAll(
    GameCapability.friends,
    'getFriends',
    (p) => getFriends(from: p),
  );

  // ─── Lobbies & invitations ─────────────────────────────────────────────────
  //
  // A lobby belongs to one provider and is never fanned out. Calls that create
  // or find lobbies go to [on], or else to the first provider advertising
  // [GameCapability.lobbies]. Calls on an existing [Lobby] route by
  // `lobby.providerId`. They return the value and throw on failure.

  /// The provider a lobby call without a lobby targets.
  UnifiedGameServicesPlatform _lobbyProvider(UnifiedGameServicesPlatform? on) {
    if (on != null) return _reader(GameCapability.lobbies, on);
    final capable = providersFor(GameCapability.lobbies);
    if (capable.isEmpty) {
      throw CapabilityNotSupportedException(GameCapability.lobbies);
    }
    return capable.first;
  }

  /// The provider that owns [lobby].
  UnifiedGameServicesPlatform _lobbyOwner(Lobby lobby) {
    for (final p in providers) {
      if (p.providerId == lobby.providerId) {
        return _reader(GameCapability.lobbies, p);
      }
    }
    throw ArgumentError.value(
      lobby,
      'lobby',
      'No registered provider has providerId "${lobby.providerId}".',
    );
  }

  Lobby _tagLobby(UnifiedGameServicesPlatform p, Lobby lobby) => lobby.copyWith(
    providerId: p.providerId,
    members: [
      for (final m in lobby.members)
        m.copyWith(player: m.player.copyWith(providerId: p.providerId)),
    ],
  );

  /// Creates a lobby on [on] (default: the first provider with lobbies).
  Future<Lobby> createLobby({
    int maxMembers = 4,
    LobbyVisibility visibility = LobbyVisibility.friendsOnly,
    LobbyKind kind = LobbyKind.lobby,
    Map<String, String> data = const {},
    Map<String, String> memberData = const {},
    UnifiedGameServicesPlatform? on,
  }) async {
    final p = _lobbyProvider(on);
    return _tagLobby(
      p,
      await p.createLobby(
        maxMembers: maxMembers,
        visibility: visibility,
        kind: kind,
        data: data,
        memberData: memberData,
      ),
    );
  }

  /// Joins the lobby identified by [joinToken] on [on] (default: the first
  /// provider with lobbies). The token comes from `Lobby.joinToken`, an
  /// [InvitationReceivedEvent] or a [JoinRequestedEvent].
  Future<Lobby> joinLobby(
    String joinToken, {
    Map<String, String> memberData = const {},
    UnifiedGameServicesPlatform? on,
  }) async {
    final p = _lobbyProvider(on);
    return _tagLobby(p, await p.joinLobby(joinToken, memberData: memberData));
  }

  /// Leaves [lobby].
  Future<void> leaveLobby(Lobby lobby) async =>
      _lobbyOwner(lobby).leaveLobby(lobby.id);

  /// The current state of [lobby], or `null` if it no longer exists.
  Future<Lobby?> refreshLobby(Lobby lobby) async {
    final p = _lobbyOwner(lobby);
    final fresh = await p.getLobby(lobby.id);
    return fresh == null ? null : _tagLobby(p, fresh);
  }

  /// Searches public lobbies on [on] (default: the first provider with
  /// lobbies) matching every filter.
  Future<List<Lobby>> findLobbies({
    List<LobbyFilter> filters = const [],
    int maxResults = 25,
    UnifiedGameServicesPlatform? on,
  }) async {
    final p = _lobbyProvider(on);
    return [
      for (final l in await p.findLobbies(
        filters: filters,
        maxResults: maxResults,
      ))
        _tagLobby(p, l),
    ];
  }

  /// Updates [lobby]; owner only. Entries of [data] merge in and a `null` value
  /// removes the key.
  Future<Lobby> updateLobby(
    Lobby lobby, {
    Map<String, String?>? data,
    LobbyVisibility? visibility,
    int? maxMembers,
  }) async {
    final p = _lobbyOwner(lobby);
    return _tagLobby(
      p,
      await p.updateLobby(
        lobby.id,
        data: data,
        visibility: visibility,
        maxMembers: maxMembers,
      ),
    );
  }

  /// Updates the signed-in player's own data in [lobby]; a `null` value removes
  /// the key.
  Future<Lobby> setMemberData(Lobby lobby, Map<String, String?> data) async {
    final p = _lobbyOwner(lobby);
    return _tagLobby(p, await p.setMemberData(lobby.id, data));
  }

  /// Invites [userId] to [lobby].
  Future<void> sendInvitation(Lobby lobby, String userId) async {
    final p = _lobbyOwner(lobby);
    if (!p.supports(GameCapability.invitations)) {
      throw CapabilityNotSupportedException(GameCapability.invitations);
    }
    await p.sendInvitation(lobby.id, userId);
  }

  // ─── Matchmaking ──────────────────────────────────────────────────────────

  /// Starts matchmaking on every provider supporting matchmaking.
  ///
  /// **Note:** Reserved capability ([GameCapability.matchmaking]); not yet
  /// implemented.
  Future<MultiProviderOperationResult<void>> startMatchmaking({
    Map<String, dynamic>? attributes,
  }) => _fanOut(
    GameCapability.matchmaking,
    'startMatchmaking',
    (p) => p.startMatchmaking(attributes: attributes),
  );

  /// Cancels matchmaking on every provider supporting matchmaking.
  ///
  /// **Note:** Reserved capability ([GameCapability.matchmaking]); not yet
  /// implemented.
  Future<MultiProviderOperationResult<void>> cancelMatchmaking() => _fanOut(
    GameCapability.matchmaking,
    'cancelMatchmaking',
    (p) => p.cancelMatchmaking(),
  );

  // ─── Overlays ─────────────────────────────────────────────────────────────

  /// Opens the achievements UI overlay on every provider supporting overlays.
  ///
  /// Implemented by Google Play Android.
  Future<MultiProviderOperationResult<void>> showAchievementsUI() => _fanOut(
    GameCapability.overlays,
    'showAchievementsUI',
    (p) => p.showAchievementsUI(),
  );

  /// Opens the leaderboards UI overlay on every provider supporting overlays.
  ///
  /// Shows [leaderboardId] when given, otherwise each provider's default view.
  /// Implemented by Google Play Android.
  Future<MultiProviderOperationResult<void>> showLeaderboardsUI({
    String? leaderboardId,
  }) => _fanOut(
    GameCapability.overlays,
    'showLeaderboardsUI',
    (p) => p.showLeaderboardsUI(leaderboardId: leaderboardId),
  );

  /// Opens a platform-native overlay on every provider supporting overlays.
  ///
  /// No built-in provider implements this yet. Google Play Android advertises
  /// [GameCapability.overlays] but has no generic overlay, so its entry in the
  /// result is a [PlatformOperationException].
  Future<MultiProviderOperationResult<void>> showOverlay({String? overlayId}) =>
      _fanOut(
        GameCapability.overlays,
        'showOverlay',
        (p) => p.showOverlay(overlayId: overlayId),
      );

  // ─── Identity Tokens ──────────────────────────────────────────────────────

  /// Retrieves an identity token from [from] (defaults to [primary]).
  ///
  /// Gated by [GameCapability.identityTokens]. The format depends on the
  /// provider (Steam: hex ticket, Epic: JWT).
  Future<String?> getIdentityToken({UnifiedGameServicesPlatform? from}) async {
    return _reader(GameCapability.identityTokens, from).getIdentityToken();
  }

  // ─── Fan-out helpers ─────────────────────────────────────────────────────

  /// The table row [row] plus [p]'s own [native] id, read-only.
  Map<String, String> _withOwn(
    Map<String, String>? row,
    UnifiedGameServicesPlatform p,
    String native,
  ) => Map.unmodifiable({...?row, p.providerId: native});

  /// The provider a read targets: [from] or [primary]. Throws
  /// [CapabilityNotSupportedException] when it does not advertise [capability].
  UnifiedGameServicesPlatform _reader(
    GameCapability capability,
    UnifiedGameServicesPlatform? from,
  ) {
    final p = from ?? primary;
    if (!p.supports(capability)) {
      throw CapabilityNotSupportedException(capability);
    }
    return p;
  }

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

  /// Like [_fanOut] but for reads: runs [op] on every provider that supports
  /// [capability] and returns each provider's value or failure.
  Future<MultiProviderOperationResult<T>> _readAll<T>(
    GameCapability capability,
    String operation,
    Future<T> Function(UnifiedGameServicesPlatform) op,
  ) {
    final targets = providersFor(capability);
    if (targets.isEmpty) throw CapabilityNotSupportedException(capability);
    return _runAll(operation, targets, op);
  }

  /// Disposes every provider (timers, HTTP clients, native SDK handles).
  ///
  /// Call once the facade is no longer needed. Every provider is disposed even
  /// if another fails; failures are reported in the result. Does not affect
  /// [GameServices.instance]; call [GameServices.reset] if this facade was the
  /// global one.
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
          return OperationSuccess<T>(
            providerId: p.providerId,
            value: await op(p),
          );
        } catch (e, st) {
          return ProviderOperationResult<T>.fromError(p.providerId, e, st);
        }
      }),
    );
    return MultiProviderOperationResult<T>(operation, results);
  }
}
