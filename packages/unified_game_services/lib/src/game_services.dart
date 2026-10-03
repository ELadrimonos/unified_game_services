import 'dart:typed_data';

import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'multi_provider_result.dart';
import 'unified_achievement.dart';
import 'unified_game_services_base.dart';

/// Static, app-wide entry point: initialize once, then call from anywhere.
///
/// ```dart
/// GameServices.initialize(providers: [
///   SteamProvider(appId: 480),
///   GameJoltProvider(gameId: '…', privateKey: '…', username: '…', userToken: '…'),
/// ]);
///
/// await GameServices.signIn();
/// final result = await GameServices.submitScore(leaderboardId: 'global', score: 4200);
/// final achievements = await GameServices.getAchievements();
/// ```
///
/// Every method delegates to the global [UnifiedGameServices] ([instance]);
/// see it for the semantics (fan-out writes return a
/// [MultiProviderOperationResult], reads use the primary provider or `from:`).
/// For several independent facades or dependency injection, build
/// [UnifiedGameServices] directly instead.
abstract final class GameServices {
  static UnifiedGameServices? _instance;

  /// Creates the global [UnifiedGameServices] over [providers], stores it as
  /// [instance] and returns it.
  ///
  /// Replaces any previous global **without disposing it**; call [dispose]
  /// first if it holds resources. Throws [ArgumentError] if [providers] is
  /// empty.
  static UnifiedGameServices initialize({
    required List<UnifiedGameServicesPlatform> providers,
    UnifiedAchievementTable? achievements,
    UnifiedLeaderboardTable? leaderboards,
    UnifiedStatTable? stats,
  }) => _instance = UnifiedGameServices(
    providers: providers,
    achievements: achievements,
    leaderboards: leaderboards,
    stats: stats,
  );

  /// The global facade. Throws [StateError] before [initialize] (or after
  /// [reset]).
  static UnifiedGameServices get instance =>
      _instance ??
      (throw StateError(
        'GameServices has not been initialized. Call '
        'GameServices.initialize(providers: [...]) first.',
      ));

  /// The global facade, or `null` if [initialize] has not been called.
  static UnifiedGameServices? get maybeInstance => _instance;

  /// Clears the global facade (does not dispose it). Mainly for tests.
  static void reset() => _instance = null;

  /// See [UnifiedGameServices.providers].
  static List<UnifiedGameServicesPlatform> get providers => instance.providers;

  /// See [UnifiedGameServices.primary].
  static UnifiedGameServicesPlatform get primary => instance.primary;

  /// See [UnifiedGameServices.capabilities].
  static Set<GameCapability> get capabilities => instance.capabilities;

  /// See [UnifiedGameServices.events].
  static Stream<GameServiceEvent> get events => instance.events;

  /// See [UnifiedGameServices.supports].
  static bool supports(GameCapability capability) =>
      instance.supports(capability);

  /// See [UnifiedGameServices.supportsEverywhere].
  static bool supportsEverywhere(GameCapability capability) =>
      instance.supportsEverywhere(capability);

  /// See [UnifiedGameServices.providersFor].
  static List<UnifiedGameServicesPlatform> providersFor(
    GameCapability capability,
  ) => instance.providersFor(capability);

  /// See [UnifiedGameServices.provider].
  static T? provider<T extends UnifiedGameServicesPlatform>() =>
      instance.provider<T>();

  // ─── Authentication ────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.signIn].
  static Future<MultiProviderOperationResult<PlayerProfile?>> signIn() =>
      instance.signIn();

  /// See [UnifiedGameServices.signOut].
  static Future<MultiProviderOperationResult<void>> signOut() =>
      instance.signOut();

  /// See [UnifiedGameServices.getCurrentPlayer].
  static Future<PlayerProfile?> getCurrentPlayer({
    UnifiedGameServicesPlatform? from,
  }) => instance.getCurrentPlayer(from: from);

  // ─── Achievements ──────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.getAchievements].
  static Future<List<Achievement>> getAchievements({
    UnifiedGameServicesPlatform? from,
  }) => instance.getAchievements(from: from);

  /// See [UnifiedGameServices.getUnifiedAchievements].
  static Future<AchievementOverview> getUnifiedAchievements() =>
      instance.getUnifiedAchievements();

  /// See [UnifiedGameServices.syncAchievements].
  static Future<MultiProviderOperationResult<void>> syncAchievements() =>
      instance.syncAchievements();

  /// See [UnifiedGameServices.unlockAchievement].
  static Future<MultiProviderOperationResult<void>> unlockAchievement(
    String achievementId,
  ) => instance.unlockAchievement(achievementId);

  /// See [UnifiedGameServices.incrementAchievement].
  static Future<MultiProviderOperationResult<void>> incrementAchievement(
    String achievementId,
    int steps,
  ) => instance.incrementAchievement(achievementId, steps);

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.submitScore].
  static Future<MultiProviderOperationResult<void>> submitScore({
    required String leaderboardId,
    required int score,
  }) => instance.submitScore(leaderboardId: leaderboardId, score: score);

  /// See [UnifiedGameServices.getLeaderboard].
  static Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
    UnifiedGameServicesPlatform? from,
  }) => instance.getLeaderboard(
    leaderboardId,
    timeScope: timeScope,
    collection: collection,
    maxResults: maxResults,
    from: from,
  );

  // ─── Stats ─────────────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.setStat].
  static Future<MultiProviderOperationResult<void>> setStat(
    String key,
    num value,
  ) => instance.setStat(key, value);

  /// See [UnifiedGameServices.incrementStat].
  static Future<MultiProviderOperationResult<void>> incrementStat(
    String key, {
    num by = 1,
  }) => instance.incrementStat(key, by: by);

  /// See [UnifiedGameServices.getStat].
  static Future<Stat?> getStat(
    String key, {
    UnifiedGameServicesPlatform? from,
  }) => instance.getStat(key, from: from);

  // ─── Cloud save ────────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.saveData].
  static Future<MultiProviderOperationResult<void>> saveData(
    String slot,
    Uint8List data,
  ) => instance.saveData(slot, data);

  /// See [UnifiedGameServices.loadData].
  static Future<CloudSave?> loadData(
    String slot, {
    UnifiedGameServicesPlatform? from,
  }) => instance.loadData(slot, from: from);

  // ─── Presence ──────────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.setPresence].
  static Future<MultiProviderOperationResult<void>> setPresence(
    RichPresence presence,
  ) => instance.setPresence(presence);

  /// See [UnifiedGameServices.clearPresence].
  static Future<MultiProviderOperationResult<void>> clearPresence() =>
      instance.clearPresence();

  // ─── Friends ───────────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.getFriends].
  static Future<List<PlayerProfile>> getFriends({
    UnifiedGameServicesPlatform? from,
  }) => instance.getFriends(from: from);

  // ─── Invitations ──────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.sendInvitation].
  static Future<MultiProviderOperationResult<void>> sendInvitation(
    String friendId, {
    String? payload,
  }) => instance.sendInvitation(friendId, payload: payload);

  // ─── Lobbies ──────────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.createLobby].
  static Future<MultiProviderOperationResult<void>> createLobby({
    int maxPlayers = 4,
    String? name,
  }) => instance.createLobby(maxPlayers: maxPlayers, name: name);

  /// See [UnifiedGameServices.joinLobby].
  static Future<MultiProviderOperationResult<void>> joinLobby(String lobbyId) =>
      instance.joinLobby(lobbyId);

  /// See [UnifiedGameServices.leaveLobby].
  static Future<MultiProviderOperationResult<void>> leaveLobby(
    String lobbyId,
  ) => instance.leaveLobby(lobbyId);

  // ─── Matchmaking ──────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.startMatchmaking].
  static Future<MultiProviderOperationResult<void>> startMatchmaking({
    Map<String, dynamic>? attributes,
  }) => instance.startMatchmaking(attributes: attributes);

  /// See [UnifiedGameServices.cancelMatchmaking].
  static Future<MultiProviderOperationResult<void>> cancelMatchmaking() =>
      instance.cancelMatchmaking();

  // ─── Overlays ─────────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.showAchievementsUI].
  static Future<MultiProviderOperationResult<void>> showAchievementsUI() =>
      instance.showAchievementsUI();

  /// See [UnifiedGameServices.showLeaderboardsUI].
  static Future<MultiProviderOperationResult<void>> showLeaderboardsUI({
    String? leaderboardId,
  }) => instance.showLeaderboardsUI(leaderboardId: leaderboardId);

  /// See [UnifiedGameServices.showOverlay].
  static Future<MultiProviderOperationResult<void>> showOverlay({
    String? overlayId,
  }) => instance.showOverlay(overlayId: overlayId);

  // ─── Identity Tokens ──────────────────────────────────────────────────────

  /// See [UnifiedGameServices.getIdentityToken].
  static Future<String?> getIdentityToken({
    UnifiedGameServicesPlatform? from,
  }) => instance.getIdentityToken(from: from);

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// See [UnifiedGameServices.dispose]. Does not clear the global; call
  /// [reset] too if you will not reuse it.
  static Future<MultiProviderOperationResult<void>> dispose() =>
      instance.dispose();
}
