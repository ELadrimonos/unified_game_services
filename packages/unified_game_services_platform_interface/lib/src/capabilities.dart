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

  /// Real-time or asynchronous multiplayer sessions.
  multiplayer,
}
