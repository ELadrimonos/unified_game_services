import 'package:dart_mappable/dart_mappable.dart';

import 'enums.dart';
import 'player_profile.dart';

part 'leaderboard.mapper.dart';

/// A single ranked row in a [Leaderboard].
@MappableClass()
class LeaderboardEntry with LeaderboardEntryMappable {
  /// 1-based rank of this entry within the queried scope.
  final int rank;

  /// The player who owns this score.
  final PlayerProfile player;

  /// Raw numeric score.
  final int score;

  /// Provider-formatted score for display (e.g. "1:23.45", "1,500 pts").
  ///
  /// Falls back to `score.toString()` when the provider gives no formatting.
  final String? formattedScore;

  /// When the score was achieved, if known.
  final DateTime? achievedAt;

  const LeaderboardEntry({
    required this.rank,
    required this.player,
    required this.score,
    this.formattedScore,
    this.achievedAt,
  });

  /// [formattedScore] if present, otherwise the raw score as a string.
  String get displayScore => formattedScore ?? score.toString();
}

/// A leaderboard and a page of its ranked entries.
@MappableClass()
class Leaderboard with LeaderboardMappable {
  /// Provider-scoped unique identifier.
  final String id;

  /// Localized display name, if the provider exposes one.
  final String? displayName;

  /// Whether higher or lower scores rank better.
  final LeaderboardOrder order;

  /// The time window these [entries] were queried for.
  final LeaderboardTimeScope timeScope;

  /// The player set these [entries] were queried for.
  final LeaderboardCollection collection;

  /// Ranked entries, ordered best-first.
  final List<LeaderboardEntry> entries;

  /// The signed-in player's own entry, if available and outside [entries].
  final LeaderboardEntry? playerEntry;

  const Leaderboard({
    required this.id,
    this.displayName,
    this.order = LeaderboardOrder.highToLow,
    this.timeScope = LeaderboardTimeScope.allTime,
    this.collection = LeaderboardCollection.global,
    this.entries = const [],
    this.playerEntry,
  });
}
