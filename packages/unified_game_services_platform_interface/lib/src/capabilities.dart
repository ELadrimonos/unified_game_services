/// @docImport 'events.dart';
/// @docImport 'exceptions.dart';
/// @docImport 'models/lobby.dart';
/// @docImport 'platform_interface/platform_interface.dart';
library;

/// A feature a game service provider may or may not support.
///
/// Providers advertise their supported capabilities through
/// [UnifiedGameServicesPlatform.capabilities]; callers can test for one with
/// [UnifiedGameServicesPlatform.supports]. Providers throw a
/// [CapabilityNotSupportedException] from an operation whose capability they
/// do not advertise.
enum GameCapability {
  /// Unlocking, revealing and reading achievements.
  ///
  /// Gates [UnifiedGameServicesPlatform.getAchievements],
  /// [UnifiedGameServicesPlatform.unlockAchievement],
  /// [UnifiedGameServicesPlatform.incrementAchievement] and
  /// [UnifiedGameServicesPlatform.revealAchievement].
  achievements,

  /// Submitting scores and reading leaderboards.
  ///
  /// Gates [UnifiedGameServicesPlatform.submitScore],
  /// [UnifiedGameServicesPlatform.getLeaderboard] and
  /// [UnifiedGameServicesPlatform.getPlayerScore].
  leaderboards,

  /// Reading and writing numeric player statistics.
  ///
  /// Gates [UnifiedGameServicesPlatform.getStats],
  /// [UnifiedGameServicesPlatform.getStat],
  /// [UnifiedGameServicesPlatform.setStat] and
  /// [UnifiedGameServicesPlatform.incrementStat].
  stats,

  /// Storing and retrieving save data in the provider's cloud.
  ///
  /// Gates [UnifiedGameServicesPlatform.saveData],
  /// [UnifiedGameServicesPlatform.loadData],
  /// [UnifiedGameServicesPlatform.listSaves] and
  /// [UnifiedGameServicesPlatform.deleteSave].
  cloudSave,

  /// Reading the player's friends / social graph.
  ///
  /// Gates [UnifiedGameServicesPlatform.getFriends].
  friends,

  /// Publishing rich presence (current activity) information.
  ///
  /// Gates [UnifiedGameServicesPlatform.setPresence] and
  /// [UnifiedGameServicesPlatform.clearPresence].
  presence,

  /// Invitations sent to or received from friends / platform overlays.
  ///
  /// An invitation is always to a lobby: see
  /// [UnifiedGameServicesPlatform.sendInvitation] and
  /// [InvitationReceivedEvent].
  invitations,

  /// Creating, joining, searching and managing game lobbies/rooms.
  ///
  /// A lobby belongs to one provider and is never fanned out; see [Lobby].
  lobbies,

  /// Matchmaking queues and session creation.
  ///
  /// **Note:** Reserved capability; methods in the API are not yet
  /// implemented.
  matchmaking,

  /// Opening platform-native UI overlays (achievements, leaderboards, access
  /// point).
  ///
  /// Implemented by Google Play Android
  /// ([UnifiedGameServicesPlatform.showAchievementsUI],
  /// [UnifiedGameServicesPlatform.showLeaderboardsUI]).
  overlays,

  /// Retrieving platform-signed identity tokens or session tickets for
  /// server-to-server auth.
  ///
  /// Gates [UnifiedGameServicesPlatform.getIdentityToken]. Implemented by
  /// Steam (Web API auth ticket, hex) and Epic (EOS Connect ID token, a JWT).
  /// The token's format depends on
  /// [UnifiedGameServicesPlatform.providerId].
  identityTokens,
}
