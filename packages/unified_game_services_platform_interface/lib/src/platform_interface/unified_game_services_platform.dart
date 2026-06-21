part of 'platform_interface.dart';

/// The interface every game service provider implements.
///
/// Concrete providers (Google Play Games, Game Center, Steam, Epic, Xbox,
/// GameJolt, …) extend this class and register themselves via [instance].
///
/// Methods are grouped by [GameCapability]. The base class provides default
/// implementations that throw [UnimplementedError], so a provider only needs
/// to override the operations it actually supports. Operations whose
/// capability is unsupported should throw [CapabilityNotSupportedException];
/// declare support through [capabilities].
abstract class UnifiedGameServicesPlatform extends PlatformInterface {
  UnifiedGameServicesPlatform() : super(token: _token);

  static final Object _token = Object();

  static UnifiedGameServicesPlatform _instance =
      UnsupportedUnifiedGameServices();

  /// The currently registered provider.
  static UnifiedGameServicesPlatform get instance => _instance;

  /// Registers [instance] as the active provider.
  ///
  /// Platform implementations should set this in their `registerWith` method.
  static set instance(UnifiedGameServicesPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ─── Capabilities ────────────────────────────────────────────────────────

  /// The set of capabilities this provider supports.
  ///
  /// Defaults to empty; providers override to advertise their features.
  Set<GameCapability> get capabilities => const {};

  /// Whether this provider supports [capability].
  bool supports(GameCapability capability) =>
      capabilities.contains(capability);

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
      throw UnimplementedError('getAchievements() has not been implemented.');

  /// Unlocks the achievement identified by [achievementId].
  Future<void> unlockAchievement(String achievementId) =>
      throw UnimplementedError('unlockAchievement() has not been implemented.');

  /// Adds [steps] of progress to an incremental achievement.
  Future<void> incrementAchievement(String achievementId, int steps) =>
      throw UnimplementedError(
          'incrementAchievement() has not been implemented.');

  /// Reveals a hidden achievement without unlocking it.
  Future<void> revealAchievement(String achievementId) =>
      throw UnimplementedError('revealAchievement() has not been implemented.');

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  /// Submits [score] to the leaderboard identified by [leaderboardId].
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) =>
      throw UnimplementedError('submitScore() has not been implemented.');

  /// Fetches a page of [leaderboardId], scoped by [timeScope] and
  /// [collection], up to [maxResults] entries.
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) =>
      throw UnimplementedError('getLeaderboard() has not been implemented.');

  /// Returns the signed-in player's own entry on [leaderboardId], or `null`.
  Future<LeaderboardEntry?> getPlayerScore(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
  }) =>
      throw UnimplementedError('getPlayerScore() has not been implemented.');

  // ─── Stats ───────────────────────────────────────────────────────────────

  /// Returns all numeric stats for the signed-in player.
  Future<List<Stat>> getStats() =>
      throw UnimplementedError('getStats() has not been implemented.');

  /// Returns a single stat by [key], or `null` if it does not exist.
  Future<Stat?> getStat(String key) =>
      throw UnimplementedError('getStat() has not been implemented.');

  /// Sets the stat [key] to [value].
  Future<void> setStat(String key, num value) =>
      throw UnimplementedError('setStat() has not been implemented.');

  /// Increments the stat [key] by [by] (default `1`).
  Future<void> incrementStat(String key, {num by = 1}) =>
      throw UnimplementedError('incrementStat() has not been implemented.');

  // ─── Cloud save ────────────────────────────────────────────────────────────

  /// Writes [data] to the cloud save [slot].
  Future<void> saveData(String slot, Uint8List data) =>
      throw UnimplementedError('saveData() has not been implemented.');

  /// Loads the cloud save [slot], or `null` if it does not exist.
  Future<CloudSave?> loadData(String slot) =>
      throw UnimplementedError('loadData() has not been implemented.');

  /// Lists metadata for every cloud save slot.
  Future<List<CloudSaveMetadata>> listSaves() =>
      throw UnimplementedError('listSaves() has not been implemented.');

  /// Deletes the cloud save [slot].
  Future<void> deleteSave(String slot) =>
      throw UnimplementedError('deleteSave() has not been implemented.');

  // ─── Rich presence ───────────────────────────────────────────────────────

  /// Publishes [presence] as the player's current activity.
  Future<void> setPresence(RichPresence presence) =>
      throw UnimplementedError('setPresence() has not been implemented.');

  /// Clears any published presence.
  Future<void> clearPresence() =>
      throw UnimplementedError('clearPresence() has not been implemented.');

  // ─── Friends ─────────────────────────────────────────────────────────────

  /// Returns the signed-in player's friends.
  Future<List<PlayerProfile>> getFriends() =>
      throw UnimplementedError('getFriends() has not been implemented.');
}
