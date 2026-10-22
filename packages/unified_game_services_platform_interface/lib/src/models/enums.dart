/// @docImport '../capabilities.dart';
/// @docImport '../platform_interface/platform_interface.dart';
library;

/// The time window a leaderboard query is scoped to.
///
/// Passed to [UnifiedGameServicesPlatform.getLeaderboard] and
/// [UnifiedGameServicesPlatform.getPlayerScore]. Not every provider supports
/// every scope; unsupported scopes typically fall back to [allTime].
enum LeaderboardTimeScope {
  /// All scores ever submitted.
  allTime,

  /// Scores submitted in the current week.
  weekly,

  /// Scores submitted today.
  daily,
}

/// The set of players a leaderboard query is restricted to.
///
/// Passed to [UnifiedGameServicesPlatform.getLeaderboard].
enum LeaderboardCollection {
  /// Every player on the platform.
  global,

  /// Only the signed-in player's friends (requires [GameCapability.friends]).
  ///
  /// Providers that cannot restrict a query to friends may ignore this.
  friends,
}

/// How a leaderboard ranks scores.
enum LeaderboardOrder {
  /// Higher scores rank better (e.g. points).
  highToLow,

  /// Lower scores rank better (e.g. lap times).
  lowToHigh,
}
