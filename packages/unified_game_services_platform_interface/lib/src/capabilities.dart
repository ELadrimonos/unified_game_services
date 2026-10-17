/// A feature a game service provider may or may not support.
///
/// Providers advertise their supported capabilities through
/// [UnifiedGameServicesPlatform.capabilities]. Calling an operation whose
/// capability is unsupported throws a [CapabilityNotSupportedException].
enum GameCapability {
  /// Unlocking, revealing and reading achievements.
  achievements,

  /// Submitting scores and reading leaderboards.
  leaderboards,

  /// Reading and writing numeric player statistics.
  stats,

  /// Storing and retrieving save data in the provider's cloud.
  cloudSave,

  /// Reading the player's friends / social graph.
  friends,

  /// Publishing rich presence (current activity) information.
  presence,

  /// Invitations sent to or received from friends / platform overlays.
  ///
  /// An invitation is always to a lobby: see `sendInvitation` and
  /// `InvitationReceivedEvent`.
  invitations,

  /// Creating, joining, searching and managing game lobbies/rooms.
  ///
  /// A lobby belongs to one provider and is never fanned out; see `Lobby`.
  lobbies,

  /// Matchmaking queues and session creation.
  ///
  /// **Note:** Reserved capability; methods in the API are not yet implemented.
  matchmaking,

  /// Opening platform-native UI overlays (achievements, leaderboards, access point).
  ///
  /// Implemented by Google Play Android (`showAchievementsUI`, `showLeaderboardsUI`).
  overlays,

  /// Retrieving platform-signed identity tokens or session tickets for server-to-server auth.
  ///
  /// Implemented by Steam (Web API auth ticket, hex) and Epic (EOS Connect ID
  /// token, a JWT). The token's format depends on `providerId`.
  identityTokens,
}
