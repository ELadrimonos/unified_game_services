import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart' show StreamGroup;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'multi_provider_result.dart';
import 'unified_achievement.dart';

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

  /// Whether a player is signed in on [from] (defaults to [primary]).
  Future<bool> isSignedIn({UnifiedGameServicesPlatform? from}) =>
      (from ?? primary).isSignedIn();

  // ─── Achievements ──────────────────────────────────────────────────────────

  /// Achievements from [from] (defaults to [primary]), each tagged with the
  /// source `providerId`.
  Future<List<Achievement>> getAchievements({
    UnifiedGameServicesPlatform? from,
  }) async {
    final p = _reader(GameCapability.achievements, from);
    return _unifiedAchievements(p, await p.getAchievements());
  }

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
  /// them by unified id, so each [UnifiedAchievement] says on which providers
  /// it is unlocked.
  ///
  /// A provider that fails is reported in [AchievementOverview.failed], not
  /// thrown. Throws [CapabilityNotSupportedException] when no provider supports
  /// achievements.
  Future<AchievementOverview> getUnifiedAchievements() async {
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
      for (final a in r.value!) {
        (merged[a.id] ??= {})[r.providerId] = a;
      }
    }
    return AchievementOverview([
      for (final e in merged.entries) UnifiedAchievement(e.key, e.value),
    ], read.failed);
  }

  /// Unlocks, on every provider where an achievement is still locked, whatever
  /// is already unlocked on another provider.
  ///
  /// One-way by nature: achievements cannot be re-locked. Only providers that
  /// list the achievement are touched, and incremental progress is not copied
  /// (only completed unlocks). Each provider that needed an unlock gets one
  /// result entry, which fails if any of its unlocks failed; providers already
  /// in sync have no entry. Providers that could not be read are skipped
  /// silently — call [getUnifiedAchievements] to see them in `failed`.
  Future<MultiProviderOperationResult<void>> syncAchievements() async {
    final overview = await getUnifiedAchievements();
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

  /// Reveals a hidden achievement on every provider that supports achievements.
  Future<MultiProviderOperationResult<void>> revealAchievement(
    String achievementId,
  ) => _fanOut(
    GameCapability.achievements,
    'revealAchievement',
    (p) => p.revealAchievement(achievementId),
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

  /// The signed-in player's own entry on [leaderboardId] from [from]
  /// (defaults to [primary]), or `null` when the player has no score.
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
  /// keyed by unified key where a mapping exists.
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
    final p = _reader(GameCapability.cloudSave, from);
    final save = await p.loadData(slot);
    return save?.copyWith(
      metadata: save.metadata.copyWith(providerId: p.providerId),
    );
  }

  /// Metadata of the saves on [from] (defaults to [primary]).
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
    final p = _reader(GameCapability.friends, from);
    return [
      for (final f in await p.getFriends())
        f.copyWith(providerId: p.providerId),
    ];
  }

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
  /// **Note:** Reserved capability ([GameCapability.matchmaking]); not yet implemented.
  Future<MultiProviderOperationResult<void>> startMatchmaking({
    Map<String, dynamic>? attributes,
  }) => _fanOut(
    GameCapability.matchmaking,
    'startMatchmaking',
    (p) => p.startMatchmaking(attributes: attributes),
  );

  /// Cancels matchmaking on every provider supporting matchmaking.
  ///
  /// **Note:** Reserved capability ([GameCapability.matchmaking]); not yet implemented.
  Future<MultiProviderOperationResult<void>> cancelMatchmaking() => _fanOut(
    GameCapability.matchmaking,
    'cancelMatchmaking',
    (p) => p.cancelMatchmaking(),
  );

  // ─── Overlays ─────────────────────────────────────────────────────────────

  /// Opens the achievements UI overlay on every provider supporting overlays.
  ///
  /// **Note:** Reserved capability ([GameCapability.overlays]); not yet implemented.
  Future<MultiProviderOperationResult<void>> showAchievementsUI() => _fanOut(
    GameCapability.overlays,
    'showAchievementsUI',
    (p) => p.showAchievementsUI(),
  );

  /// Opens the leaderboards UI overlay on every provider supporting overlays.
  ///
  /// **Note:** Reserved capability ([GameCapability.overlays]); not yet implemented.
  Future<MultiProviderOperationResult<void>> showLeaderboardsUI({
    String? leaderboardId,
  }) => _fanOut(
    GameCapability.overlays,
    'showLeaderboardsUI',
    (p) => p.showLeaderboardsUI(leaderboardId: leaderboardId),
  );

  /// Opens a platform-native overlay on every provider supporting overlays.
  ///
  /// **Note:** Reserved capability ([GameCapability.overlays]); not yet implemented.
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
