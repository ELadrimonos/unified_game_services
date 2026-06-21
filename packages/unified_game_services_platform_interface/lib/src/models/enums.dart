import 'package:dart_mappable/dart_mappable.dart';

part 'enums.mapper.dart';

/// The time window a leaderboard query is scoped to.
///
/// Not every provider supports every scope; unsupported scopes typically fall
/// back to [allTime].
@MappableEnum()
enum LeaderboardTimeScope {
  /// All scores ever submitted.
  allTime,

  /// Scores submitted in the current week.
  weekly,

  /// Scores submitted today.
  daily,
}

/// The set of players a leaderboard query is restricted to.
@MappableEnum()
enum LeaderboardCollection {
  /// Every player on the platform.
  global,

  /// Only the signed-in player's friends (requires [GameCapability.friends]).
  friends,
}

/// How a leaderboard ranks scores.
@MappableEnum()
enum LeaderboardOrder {
  /// Higher scores rank better (e.g. points).
  highToLow,

  /// Lower scores rank better (e.g. lap times).
  lowToHigh,
}
