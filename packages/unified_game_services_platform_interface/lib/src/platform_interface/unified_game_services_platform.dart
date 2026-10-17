part of 'platform_interface.dart';

/// The interface every game service provider implements.
///
/// Concrete providers (Google Play Games, Game Center, Steam, Epic, Xbox PC,
/// GameJolt, …) extend this class, call `super()`, and are handed to
/// `GameServices.initialize(providers: [...])` (or the
/// `UnifiedGameServices` constructor).
///
/// Methods are grouped by [GameCapability]. The base class provides default
/// implementations that throw [CapabilityNotSupportedException] for the
/// operation's [GameCapability] (authentication and [events] throw
/// [UnimplementedError]: every provider must supply those). A provider only
/// needs to override the operations it actually supports; declare support
/// through [capabilities].
abstract class UnifiedGameServicesPlatform extends PlatformInterface {
  /// Creates the platform interface.
  ///
  /// A leaderboard or achievement almost always has a *different* native id on
  /// each platform (Steam uses a string name, GameJolt a numeric `table_id`,
  /// etc.). When you fan out a single call through [UnifiedGameServices], you
  /// pass one *unified* key and each provider translates it to its own native
  /// id using these maps:
  ///
  /// ```dart
  /// SteamProvider(leaderboardIds: {'global': 'WeeklyHigh'});
  /// GameJoltProvider(leaderboardIds: {'global': '12345'});
  /// // services.submitScore(leaderboardId: 'global', score: 1500)
  /// //   → Steam submits to "WeeklyHigh", GameJolt to table 12345
  /// ```
  ///
  /// A key with no entry passes through unchanged, so providers that share the
  /// caller's ids need no map. Providers must resolve ids through
  /// [resolveLeaderboardId] / [resolveAchievementId] for this to take effect.
  UnifiedGameServicesPlatform() : super(token: _token);

  final Map<String, String> _leaderboardIds = {};
  final Map<String, String> _achievementIds = {};
  final Map<String, String> _statIds = {};

  /// Maps a unified leaderboard key to this provider's native id.
  ///
  /// Returns [unifiedId] unchanged when no alias was registered. Provider
  /// subclasses should call this on every leaderboard id they receive
  /// (`submitScore`, `getLeaderboard`, …). Not part of the public API surface
  /// — intended for subclasses only.
  String resolveLeaderboardId(String unifiedId) =>
      _leaderboardIds[unifiedId] ?? unifiedId;

  /// Maps a unified achievement key to this provider's native id.
  ///
  /// See [resolveLeaderboardId]. Intended for subclasses only.
  String resolveAchievementId(String unifiedId) =>
      _achievementIds[unifiedId] ?? unifiedId;

  /// Maps a unified stat key to this provider's native id.
  ///
  /// See [resolveLeaderboardId]. Intended for subclasses only.
  String resolveStatId(String unifiedId) => _statIds[unifiedId] ?? unifiedId;

  /// Registers additional mappings for this provider (called by facade initialization).
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
  /// (e.g. `steam`, `epic`, `game_center`, `google_play`, `gamejolt`).
  ///
  /// It is part of the public contract: it must never change across versions
  /// and must not be derived from `runtimeType`. The facade uses it to report
  /// per-provider outcomes. Distinct implementations of the same store (e.g.
  /// the Google Play REST and Android tiers) share one id.
  String get providerId;

  // ─── Capabilities ────────────────────────────────────────────────────────

  /// The set of capabilities this provider supports.
  ///
  /// Defaults to empty; providers override to advertise their features.
  Set<GameCapability> get capabilities => const {};

  /// Whether this provider supports [capability].
  bool supports(GameCapability capability) => capabilities.contains(capability);

  // ─── Events ──────────────────────────────────────────────────────────────

  /// A broadcast stream of events (sign-in, unlocks, score submissions, …).
  Stream<GameServiceEvent> get events =>
      throw UnimplementedError('events has not been implemented.');

  // ─── Authentication ────────────────────────────────────────────────────────

  /// Signs the player in.
  ///
  /// Returns the authenticated [PlayerProfile], or `null` if sign-in did not
  /// produce a profile. Throws [SignInFailedException] on failure.
  Future<PlayerProfile?> signIn() =>
      throw UnimplementedError('signIn() has not been implemented.');

  /// Signs the current player out, if the provider supports it.
  Future<void> signOut() =>
      throw UnimplementedError('signOut() has not been implemented.');

  /// Whether a player is currently signed in.
  Future<bool> isSignedIn() =>
      throw UnimplementedError('isSignedIn() has not been implemented.');

  /// The signed-in player's profile, or `null` if not signed in.
  Future<PlayerProfile?> getCurrentPlayer() =>
      throw UnimplementedError('getCurrentPlayer() has not been implemented.');

  // ─── Achievements ──────────────────────────────────────────────────────────

  /// Returns all achievements with the player's current progress.
  Future<List<Achievement>> getAchievements() =>
      throw CapabilityNotSupportedException(GameCapability.achievements);

  /// Unlocks the achievement identified by [achievementId].
  Future<void> unlockAchievement(String achievementId) =>
      throw CapabilityNotSupportedException(GameCapability.achievements);

  /// Adds [steps] of progress to an incremental achievement.
  Future<void> incrementAchievement(String achievementId, int steps) =>
      throw CapabilityNotSupportedException(GameCapability.achievements);

  /// Reveals a hidden achievement without unlocking it.
  Future<void> revealAchievement(String achievementId) =>
      throw CapabilityNotSupportedException(GameCapability.achievements);

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  /// Submits [score] to the leaderboard identified by [leaderboardId].
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) => throw CapabilityNotSupportedException(GameCapability.leaderboards);

  /// Fetches a page of [leaderboardId], scoped by [timeScope] and
  /// [collection], up to [maxResults] entries.
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) => throw CapabilityNotSupportedException(GameCapability.leaderboards);

  /// Returns the signed-in player's own entry on [leaderboardId], or `null`.
  Future<LeaderboardEntry?> getPlayerScore(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
  }) => throw CapabilityNotSupportedException(GameCapability.leaderboards);

  // ─── Stats ───────────────────────────────────────────────────────────────

  /// Returns all numeric stats for the signed-in player.
  Future<List<Stat>> getStats() =>
      throw CapabilityNotSupportedException(GameCapability.stats);

  /// Returns a single stat by [key], or `null` if it does not exist.
  Future<Stat?> getStat(String key) =>
      throw CapabilityNotSupportedException(GameCapability.stats);

  /// Sets the stat [key] to [value].
  Future<void> setStat(String key, num value) =>
      throw CapabilityNotSupportedException(GameCapability.stats);

  /// Increments the stat [key] by [by] (default `1`).
  Future<void> incrementStat(String key, {num by = 1}) =>
      throw CapabilityNotSupportedException(GameCapability.stats);

  // ─── Cloud save ────────────────────────────────────────────────────────────

  /// Writes [data] to the cloud save [slot].
  Future<void> saveData(String slot, Uint8List data) =>
      throw CapabilityNotSupportedException(GameCapability.cloudSave);

  /// Loads the cloud save [slot], or `null` if it does not exist.
  Future<CloudSave?> loadData(String slot) =>
      throw CapabilityNotSupportedException(GameCapability.cloudSave);

  /// Lists metadata for every cloud save slot.
  Future<List<CloudSaveMetadata>> listSaves() =>
      throw CapabilityNotSupportedException(GameCapability.cloudSave);

  /// Deletes the cloud save [slot].
  Future<void> deleteSave(String slot) =>
      throw CapabilityNotSupportedException(GameCapability.cloudSave);

  // ─── Rich presence ───────────────────────────────────────────────────────

  /// Publishes [presence] as the player's current activity.
  Future<void> setPresence(RichPresence presence) =>
      throw CapabilityNotSupportedException(GameCapability.presence);

  /// Clears any published presence.
  Future<void> clearPresence() =>
      throw CapabilityNotSupportedException(GameCapability.presence);

  // ─── Friends ─────────────────────────────────────────────────────────────

  /// Returns the signed-in player's friends.
  Future<List<PlayerProfile>> getFriends() =>
      throw CapabilityNotSupportedException(GameCapability.friends);

  // ─── Invitations ──────────────────────────────────────────────────────────

  /// Sends a game invitation to [friendId] with optional [payload].
  ///
  /// **Note:** Reserved capability ([GameCapability.invitations]); not yet implemented.
  Future<void> sendInvitation(String friendId, {String? payload}) =>
      throw CapabilityNotSupportedException(GameCapability.invitations);

  // ─── Lobbies ──────────────────────────────────────────────────────────────

  /// Creates a new game lobby with [maxPlayers].
  ///
  /// **Note:** Reserved capability ([GameCapability.lobbies]); not yet implemented.
  Future<void> createLobby({int maxPlayers = 4, String? name}) =>
      throw CapabilityNotSupportedException(GameCapability.lobbies);

  /// Joins an existing game lobby by [lobbyId].
  ///
  /// **Note:** Reserved capability ([GameCapability.lobbies]); not yet implemented.
  Future<void> joinLobby(String lobbyId) =>
      throw CapabilityNotSupportedException(GameCapability.lobbies);

  /// Leaves the current lobby [lobbyId].
  ///
  /// **Note:** Reserved capability ([GameCapability.lobbies]); not yet implemented.
  Future<void> leaveLobby(String lobbyId) =>
      throw CapabilityNotSupportedException(GameCapability.lobbies);

  // ─── Matchmaking ──────────────────────────────────────────────────────────

  /// Starts a matchmaking search.
  ///
  /// **Note:** Reserved capability ([GameCapability.matchmaking]); not yet implemented.
  Future<void> startMatchmaking({Map<String, dynamic>? attributes}) =>
      throw CapabilityNotSupportedException(GameCapability.matchmaking);

  /// Cancels an active matchmaking search.
  ///
  /// **Note:** Reserved capability ([GameCapability.matchmaking]); not yet implemented.
  Future<void> cancelMatchmaking() =>
      throw CapabilityNotSupportedException(GameCapability.matchmaking);

  // ─── Overlays ─────────────────────────────────────────────────────────────

  /// Opens the platform-native achievements UI overlay.
  ///
  /// **Note:** Reserved capability ([GameCapability.overlays]); not yet implemented.
  Future<void> showAchievementsUI() =>
      throw CapabilityNotSupportedException(GameCapability.overlays);

  /// Opens the platform-native leaderboards UI overlay for [leaderboardId].
  ///
  /// **Note:** Reserved capability ([GameCapability.overlays]); not yet implemented.
  Future<void> showLeaderboardsUI({String? leaderboardId}) =>
      throw CapabilityNotSupportedException(GameCapability.overlays);

  /// Opens a generic or provider-specific native overlay (e.g. settings, friends list).
  ///
  /// **Note:** Reserved capability ([GameCapability.overlays]); not yet implemented.
  Future<void> showOverlay({String? overlayId}) =>
      throw CapabilityNotSupportedException(GameCapability.overlays);

  // ─── Identity Tokens ──────────────────────────────────────────────────────

  /// Retrieves a platform-signed identity token or session ticket for server verification.
  ///
  /// Gated by [GameCapability.identityTokens]. The format depends on the
  /// provider (Steam: hex ticket, Epic: JWT).
  Future<String?> getIdentityToken() =>
      throw CapabilityNotSupportedException(GameCapability.identityTokens);

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  /// Releases any resources the provider holds (timers, HTTP clients, native
  /// SDK handles, event streams). Safe to call more than once. The default
  /// implementation is a no-op so providers without resources need not
  /// override it.
  Future<void> dispose() async {}
}
