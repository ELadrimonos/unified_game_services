part of 'platform_interface.dart';

/// The interface every game service provider implements.
///
/// Concrete providers (Google Play Games, Game Center, Steam, Epic, Xbox PC,
/// GameJolt, …) extend this class, call `super()`, and are handed to
/// `GameServices.initialize(providers: [...])` (or the
/// `UnifiedGameServices` constructor).
///
/// Methods are grouped by [GameCapability]. The base class provides default
/// implementations that throw [UnimplementedError], so a provider only needs
/// to override the operations it actually supports. Declare what is supported
/// through [capabilities].
///
/// ## Error contract
///
/// Providers translate native failures into the [GameServiceException]
/// hierarchy rather than leaking SDK errors:
///
/// - [CapabilityNotSupportedException] when an operation (or one of its
///   options) is not supported by the provider.
/// - [NotSignedInException] when an operation needs a signed-in player and
///   there is none.
/// - [SignInFailedException] when [signIn] fails or is cancelled.
/// - [NetworkException] for connectivity problems.
/// - [PlatformOperationException] for any other provider or SDK failure.
///
/// Unless noted, a method's capability gate is the [GameCapability] of its
/// section. Calling a method the provider has not implemented throws
/// [UnimplementedError] instead, which signals a provider bug rather than a
/// runtime condition; callers should check [supports] first.
///
/// ## Id mapping
///
/// A leaderboard or achievement almost always has a *different* native id on
/// each platform (Steam uses a string name, GameJolt a numeric `table_id`,
/// etc.). Callers pass one *unified* key and the provider translates it to
/// its native id with [resolveAchievementId], [resolveLeaderboardId] and
/// [resolveStatId]. The mappings come from the id tables given to the
/// facade, which hands each provider its slice through [registerMappings]:
///
/// ```dart
/// UnifiedGameServices(
///   providers: [steam, gameJolt],
///   leaderboards: UnifiedLeaderboardTable({
///     'global': ProviderIdMap(steam: 'WeeklyHigh', gameJolt: '12345'),
///   }),
/// );
/// // services.submitScore(leaderboardId: 'global', score: 1500)
/// //   → Steam submits to "WeeklyHigh", GameJolt to table 12345
/// ```
///
/// A key with no entry passes through unchanged, so providers that share the
/// caller's ids need no table. Providers must resolve ids through the
/// `resolve*Id` methods for the mapping to take effect.
abstract class UnifiedGameServicesPlatform extends PlatformInterface {
  /// Creates the platform interface.
  ///
  /// Subclass constructors call this via `super()`. The new provider starts
  /// with empty id mappings (see [registerMappings]) and no capabilities (see
  /// [capabilities]).
  UnifiedGameServicesPlatform() : super(token: _token);

  final Map<String, String> _leaderboardIds = {};
  final Map<String, String> _achievementIds = {};
  final Map<String, String> _statIds = {};

  /// Maps a unified leaderboard key to this provider's native id.
  ///
  /// Returns [unifiedId] unchanged when no mapping was registered. Provider
  /// subclasses should call this on every leaderboard id they receive
  /// ([submitScore], [getLeaderboard], [getPlayerScore]). Intended for
  /// subclasses only.
  String resolveLeaderboardId(String unifiedId) =>
      _leaderboardIds[unifiedId] ?? unifiedId;

  /// Maps a unified achievement key to this provider's native id.
  ///
  /// Returns [unifiedId] unchanged when no mapping was registered. Provider
  /// subclasses should call this on every achievement id they receive
  /// ([unlockAchievement], [incrementAchievement], [revealAchievement]).
  /// Intended for subclasses only.
  String resolveAchievementId(String unifiedId) =>
      _achievementIds[unifiedId] ?? unifiedId;

  /// Maps a unified stat key to this provider's native id.
  ///
  /// Returns [unifiedId] unchanged when no mapping was registered. Provider
  /// subclasses should call this on every stat key they receive ([getStat],
  /// [setStat], [incrementStat]). Intended for subclasses only.
  String resolveStatId(String unifiedId) => _statIds[unifiedId] ?? unifiedId;

  /// Registers unified-key to native-id mappings for this provider.
  ///
  /// Each map goes from a unified key to this provider's native id and feeds
  /// [resolveAchievementId], [resolveLeaderboardId] or [resolveStatId]
  /// respectively. A `null` map is ignored.
  ///
  /// Mappings accumulate: entries are added to those already registered, and a
  /// key registered again replaces its earlier native id. There is no way to
  /// remove a mapping. The facade calls this once per provider when it is
  /// constructed, passing the provider's slice of each id table (see
  /// [UnifiedIdTable.forProvider]); provider authors normally never call it.
  void registerMappings({
    Map<String, String>? achievementIds,
    Map<String, String>? leaderboardIds,
    Map<String, String>? statIds,
  }) {
    if (achievementIds != null) _achievementIds.addAll(achievementIds);
    if (leaderboardIds != null) _leaderboardIds.addAll(leaderboardIds);
    if (statIds != null) _statIds.addAll(statIds);
  }

  static final Object _token = Object();

  // ─── Identity ────────────────────────────────────────────────────────────

  /// A stable, lowercase `snake_case` identifier for this provider
  /// (e.g. `steam`, `epic`, `game_center`, `google_play_rest`,
  /// `google_play_android`, `gamejolt`).
  ///
  /// It is part of the public contract: it must never change across versions
  /// and must not be derived from `runtimeType`. The facade uses it to report
  /// per-provider outcomes and to select this provider's column of the id
  /// tables, so it must match the key used in [ProviderIdMap] (see
  /// [ProviderId] for the well-known values). Distinct implementations of the
  /// same store, such as the Google Play REST and Android tiers, have distinct
  /// ids.
  String get providerId;

  // ─── Capabilities ────────────────────────────────────────────────────────

  /// The set of capabilities this provider supports.
  ///
  /// Defaults to empty; providers override to advertise their features.
  ///
  /// Advertise only what is implemented: callers rely on this set to decide
  /// whether to call an operation.
  Set<GameCapability> get capabilities => const {};

  /// Whether [capabilities] contains [capability].
  bool supports(GameCapability capability) => capabilities.contains(capability);

  // ─── Events ──────────────────────────────────────────────────────────────

  /// A broadcast stream of events (sign-in, unlocks, score submissions, …).
  ///
  /// Providers emit [GameServiceEvent]s for the operations they perform;
  /// which events a provider emits is provider-dependent. The stream may be
  /// listened to by several subscribers and does not replay past events, so
  /// subscribe before calling the operations of interest. It is closed by
  /// [dispose]. The facade merges the streams of all its providers, so a
  /// provider should override this even if it never emits.
  ///
  /// The default implementation throws [UnimplementedError] when the getter is
  /// read.
  Stream<GameServiceEvent> get events =>
      throw UnimplementedError('events has not been implemented.');

  // ─── Authentication ────────────────────────────────────────────────────────

  /// Signs the player in.
  ///
  /// Returns the authenticated [PlayerProfile], or `null` if sign-in
  /// succeeded without producing a profile. Throws [SignInFailedException] if
  /// sign-in fails or the player cancels it, and [NetworkException] on
  /// connectivity problems. Providers may emit a [UserSignedInEvent] on
  /// [events]. Not gated by a [GameCapability].
  ///
  /// Whether this prompts the player, restores a previous session or uses
  /// configured credentials is provider-dependent.
  Future<PlayerProfile?> signIn() =>
      throw UnimplementedError('signIn() has not been implemented.');

  /// Signs the current player out.
  ///
  /// Providers may emit a [UserSignedOutEvent] on [events]. Not gated by a
  /// [GameCapability]. What this does on platforms that have no sign-out
  /// concept is provider-dependent.
  Future<void> signOut() =>
      throw UnimplementedError('signOut() has not been implemented.');

  /// Whether a player is currently signed in.
  ///
  /// Completes with `false`, rather than throwing [NotSignedInException], when
  /// nobody is signed in.
  Future<bool> isSignedIn() =>
      throw UnimplementedError('isSignedIn() has not been implemented.');

  /// The signed-in player's profile, or `null` if not signed in.
  ///
  /// Unlike most operations this reports "not signed in" with `null` instead
  /// of throwing [NotSignedInException].
  Future<PlayerProfile?> getCurrentPlayer() =>
      throw UnimplementedError('getCurrentPlayer() has not been implemented.');

  // ─── Achievements ──────────────────────────────────────────────────────────

  /// Returns all achievements with the player's current progress.
  ///
  /// Gated by [GameCapability.achievements]. Ids in the result are the native
  /// ids reported by the provider; the facade rewrites them to unified keys.
  /// Throws [NotSignedInException] if the provider needs a signed-in player to
  /// read progress.
  Future<List<Achievement>> getAchievements() =>
      throw UnimplementedError('getAchievements() has not been implemented.');

  /// Unlocks the achievement identified by [achievementId].
  ///
  /// Gated by [GameCapability.achievements]. [achievementId] is a unified key
  /// resolved through [resolveAchievementId]. Throws [NotSignedInException]
  /// when no player is signed in. Whether unlocking an already-unlocked
  /// achievement is a no-op or an error is provider-dependent. Providers may
  /// emit an [AchievementUnlockedEvent].
  Future<void> unlockAchievement(String achievementId) =>
      throw UnimplementedError('unlockAchievement() has not been implemented.');

  /// Adds [steps] of progress to an incremental achievement.
  ///
  /// Gated by [GameCapability.achievements]. [achievementId] is a unified key
  /// resolved through [resolveAchievementId]; [steps] is a relative amount to
  /// add, not the new total. Providers whose achievements are all-or-nothing
  /// throw [CapabilityNotSupportedException] even though they advertise
  /// [GameCapability.achievements]. Throws [NotSignedInException] when no
  /// player is signed in.
  Future<void> incrementAchievement(String achievementId, int steps) =>
      throw UnimplementedError(
        'incrementAchievement() has not been implemented.',
      );

  /// Reveals a hidden achievement without unlocking it.
  ///
  /// Gated by [GameCapability.achievements]. [achievementId] is a unified key
  /// resolved through [resolveAchievementId]. Providers without a hidden
  /// state may treat this as a no-op.
  Future<void> revealAchievement(String achievementId) =>
      throw UnimplementedError('revealAchievement() has not been implemented.');

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  /// Submits [score] to the leaderboard identified by [leaderboardId].
  ///
  /// Gated by [GameCapability.leaderboards]. [leaderboardId] is a unified key
  /// resolved through [resolveLeaderboardId]. Whether a lower or non-improving
  /// score replaces the player's existing one is decided by the leaderboard's
  /// configuration on the provider. Throws [NotSignedInException] when no
  /// player is signed in. Providers may emit a [ScoreSubmittedEvent].
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) => throw UnimplementedError('submitScore() has not been implemented.');

  /// Fetches a page of [leaderboardId], scoped by [timeScope] and
  /// [collection], up to [maxResults] entries.
  ///
  /// Gated by [GameCapability.leaderboards]. [leaderboardId] is a unified key
  /// resolved through [resolveLeaderboardId].
  ///
  /// - [timeScope] defaults to [LeaderboardTimeScope.allTime]; providers that
  ///   cannot scope by time typically fall back to it.
  /// - [collection] defaults to [LeaderboardCollection.global];
  ///   [LeaderboardCollection.friends] restricts the page to the player's
  ///   friends, which not every provider supports.
  /// - [maxResults] defaults to `25` and is an upper bound; fewer entries may
  ///   be returned, and a provider may cap it lower. There is no paging
  ///   cursor, so this always returns the top of the board.
  ///
  /// The returned [Leaderboard.entries] are ordered best-first; they are empty
  /// for a board with no scores.
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) => throw UnimplementedError('getLeaderboard() has not been implemented.');

  /// Returns the signed-in player's own entry on [leaderboardId], or `null`.
  ///
  /// Gated by [GameCapability.leaderboards]. [leaderboardId] is a unified key
  /// resolved through [resolveLeaderboardId]; [timeScope] defaults to
  /// [LeaderboardTimeScope.allTime]. Completes with `null` when the player has
  /// no score on the board (or the provider cannot find it). Throws
  /// [NotSignedInException] when no player is signed in.
  Future<LeaderboardEntry?> getPlayerScore(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
  }) => throw UnimplementedError('getPlayerScore() has not been implemented.');

  // ─── Stats ───────────────────────────────────────────────────────────────

  /// Returns all numeric stats for the signed-in player.
  ///
  /// Gated by [GameCapability.stats]. Throws [NotSignedInException] when no
  /// player is signed in. The list is empty if the player has no stats.
  Future<List<Stat>> getStats() =>
      throw UnimplementedError('getStats() has not been implemented.');

  /// Returns a single stat by [key], or `null` if it does not exist.
  ///
  /// Gated by [GameCapability.stats]. [key] is a unified key resolved through
  /// [resolveStatId]. Throws [NotSignedInException] when no player is signed
  /// in.
  Future<Stat?> getStat(String key) =>
      throw UnimplementedError('getStat() has not been implemented.');

  /// Sets the stat [key] to [value].
  ///
  /// Gated by [GameCapability.stats]. [key] is a unified key resolved through
  /// [resolveStatId]; [value] replaces the stored value. Providers may emit a
  /// [StatUpdatedEvent].
  Future<void> setStat(String key, num value) =>
      throw UnimplementedError('setStat() has not been implemented.');

  /// Increments the stat [key] by [by] (default `1`).
  ///
  /// Gated by [GameCapability.stats]. [key] is a unified key resolved through
  /// [resolveStatId]; [by] is a relative amount added to the current value,
  /// not the new total. Providers may emit a [StatUpdatedEvent].
  Future<void> incrementStat(String key, {num by = 1}) =>
      throw UnimplementedError('incrementStat() has not been implemented.');

  // ─── Cloud save ────────────────────────────────────────────────────────────

  /// Writes [data] to the cloud save [slot].
  ///
  /// Gated by [GameCapability.cloudSave]. [slot] is a caller-defined name,
  /// not resolved through the id mappings. An existing save in [slot] is
  /// replaced and a missing one is created; providers do not merge. Throws
  /// [NotSignedInException] when no player is signed in. Size limits and
  /// conflict handling are provider-dependent.
  Future<void> saveData(String slot, Uint8List data) =>
      throw UnimplementedError('saveData() has not been implemented.');

  /// Loads the cloud save [slot], or `null` if it does not exist.
  ///
  /// Gated by [GameCapability.cloudSave]. Throws [NotSignedInException] when
  /// no player is signed in.
  Future<CloudSave?> loadData(String slot) =>
      throw UnimplementedError('loadData() has not been implemented.');

  /// Lists metadata for every cloud save slot.
  ///
  /// Gated by [GameCapability.cloudSave]. The list is empty when there are no
  /// saves, and carries no payloads (see [loadData]). Throws
  /// [NotSignedInException] when no player is signed in.
  Future<List<CloudSaveMetadata>> listSaves() =>
      throw UnimplementedError('listSaves() has not been implemented.');

  /// Deletes the cloud save [slot].
  ///
  /// Gated by [GameCapability.cloudSave]. Whether deleting a slot that does
  /// not exist completes silently or throws is provider-dependent; callers
  /// that need to tell the difference should check [listSaves] first. Throws
  /// [NotSignedInException] when no player is signed in.
  Future<void> deleteSave(String slot) =>
      throw UnimplementedError('deleteSave() has not been implemented.');

  // ─── Rich presence ───────────────────────────────────────────────────────

  /// Publishes [presence] as the player's current activity.
  ///
  /// Gated by [GameCapability.presence]. Replaces any previously published
  /// presence. Providers expose only a subset of the [RichPresence] fields.
  /// Throws [NotSignedInException] when no player is signed in. Providers may
  /// emit a [PresenceChangedEvent].
  Future<void> setPresence(RichPresence presence) =>
      throw UnimplementedError('setPresence() has not been implemented.');

  /// Clears any published presence.
  ///
  /// Gated by [GameCapability.presence]. Providers may emit a
  /// [PresenceChangedEvent] with a `null` presence.
  Future<void> clearPresence() =>
      throw UnimplementedError('clearPresence() has not been implemented.');

  // ─── Friends ─────────────────────────────────────────────────────────────

  /// Returns the signed-in player's friends.
  ///
  /// Gated by [GameCapability.friends]. The list is empty if the player has
  /// no friends. Throws [NotSignedInException] when no player is signed in.
  Future<List<PlayerProfile>> getFriends() =>
      throw UnimplementedError('getFriends() has not been implemented.');

  // ─── Invitations ──────────────────────────────────────────────────────────

  /// Sends a game invitation to [friendId] with optional [payload].
  ///
  /// **Note:** Reserved capability ([GameCapability.invitations]); not yet
  /// implemented.
  Future<void> sendInvitation(String friendId, {String? payload}) =>
      throw UnimplementedError('sendInvitation() has not been implemented.');

  // ─── Lobbies ──────────────────────────────────────────────────────────────

  /// Creates a new game lobby with [maxPlayers] and an optional [name].
  ///
  /// **Note:** Reserved capability ([GameCapability.lobbies]); not yet
  /// implemented.
  Future<void> createLobby({int maxPlayers = 4, String? name}) =>
      throw UnimplementedError('createLobby() has not been implemented.');

  /// Joins an existing game lobby by [lobbyId].
  ///
  /// **Note:** Reserved capability ([GameCapability.lobbies]); not yet
  /// implemented.
  Future<void> joinLobby(String lobbyId) =>
      throw UnimplementedError('joinLobby() has not been implemented.');

  /// Leaves the lobby identified by [lobbyId].
  ///
  /// **Note:** Reserved capability ([GameCapability.lobbies]); not yet
  /// implemented.
  Future<void> leaveLobby(String lobbyId) =>
      throw UnimplementedError('leaveLobby() has not been implemented.');

  // ─── Matchmaking ──────────────────────────────────────────────────────────

  /// Starts a matchmaking search with optional [attributes].
  ///
  /// **Note:** Reserved capability ([GameCapability.matchmaking]); not yet
  /// implemented.
  Future<void> startMatchmaking({Map<String, dynamic>? attributes}) =>
      throw UnimplementedError('startMatchmaking() has not been implemented.');

  /// Cancels an active matchmaking search.
  ///
  /// **Note:** Reserved capability ([GameCapability.matchmaking]); not yet
  /// implemented.
  Future<void> cancelMatchmaking() =>
      throw UnimplementedError('cancelMatchmaking() has not been implemented.');

  // ─── Overlays ─────────────────────────────────────────────────────────────

  /// Opens the platform-native achievements UI overlay.
  ///
  /// **Note:** Reserved capability ([GameCapability.overlays]); not yet
  /// implemented.
  Future<void> showAchievementsUI() => throw UnimplementedError(
    'showAchievementsUI() has not been implemented.',
  );

  /// Opens the platform-native leaderboards UI overlay.
  ///
  /// Shows [leaderboardId] when given, otherwise the provider's default view.
  ///
  /// **Note:** Reserved capability ([GameCapability.overlays]); not yet
  /// implemented.
  Future<void> showLeaderboardsUI({String? leaderboardId}) =>
      throw UnimplementedError(
        'showLeaderboardsUI() has not been implemented.',
      );

  /// Opens a generic or provider-specific native overlay (e.g. settings,
  /// friends list).
  ///
  /// [overlayId] selects a provider-defined overlay.
  ///
  /// **Note:** Reserved capability ([GameCapability.overlays]); not yet
  /// implemented.
  Future<void> showOverlay({String? overlayId}) =>
      throw UnimplementedError('showOverlay() has not been implemented.');

  // ─── Identity Tokens ──────────────────────────────────────────────────────

  /// Retrieves a platform-signed identity token or session ticket for server
  /// verification.
  ///
  /// **Note:** Reserved capability ([GameCapability.identityTokens]); not yet
  /// implemented.
  Future<String?> getIdentityToken() =>
      throw UnimplementedError('getIdentityToken() has not been implemented.');

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  /// Releases any resources the provider holds (timers, HTTP clients, native
  /// SDK handles, event streams).
  ///
  /// Call once the provider is no longer needed; the facade's own dispose
  /// calls this on every provider. Implementations must be safe to call more
  /// than once, and the provider must not be used afterwards. Closing the
  /// [events] stream is part of disposing. The default implementation is a
  /// no-op so providers without resources need not override it.
  Future<void> dispose() async {}
}
