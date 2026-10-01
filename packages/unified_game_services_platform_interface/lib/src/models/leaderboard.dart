import '../internal/equality.dart';
import 'enums.dart';
import 'player_profile.dart';

/// A single ranked row in a [Leaderboard].
class LeaderboardEntry {
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

  /// Returns a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the current value, so a field cannot be reset to
  /// `null` through this method; build a new instance for that.
  LeaderboardEntry copyWith({
    int? rank,
    PlayerProfile? player,
    int? score,
    String? formattedScore,
    DateTime? achievedAt,
  }) => LeaderboardEntry(
    rank: rank ?? this.rank,
    player: player ?? this.player,
    score: score ?? this.score,
    formattedScore: formattedScore ?? this.formattedScore,
    achievedAt: achievedAt ?? this.achievedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardEntry &&
          other.rank == rank &&
          other.player == player &&
          other.score == score &&
          other.formattedScore == formattedScore &&
          other.achievedAt == achievedAt;

  @override
  int get hashCode =>
      Object.hash(rank, player, score, formattedScore, achievedAt);

  @override
  String toString() =>
      'LeaderboardEntry(rank: $rank, player: $player, score: $score, '
      'formattedScore: $formattedScore, achievedAt: $achievedAt)';
}

/// A leaderboard and a page of its ranked entries.
class Leaderboard {
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

  /// [UnifiedGameServicesPlatform.providerId] of the provider this came from.
  ///
  /// Set by the `UnifiedGameServices` facade on reads; `null` when the object
  /// was built by a provider or by hand.
  final String? providerId;

  const Leaderboard({
    required this.id,
    this.displayName,
    this.order = LeaderboardOrder.highToLow,
    this.timeScope = LeaderboardTimeScope.allTime,
    this.collection = LeaderboardCollection.global,
    this.entries = const [],
    this.playerEntry,
    this.providerId,
  });

  /// Returns a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the current value, so a field cannot be reset to
  /// `null` through this method; build a new instance for that.
  Leaderboard copyWith({
    String? id,
    String? displayName,
    LeaderboardOrder? order,
    LeaderboardTimeScope? timeScope,
    LeaderboardCollection? collection,
    List<LeaderboardEntry>? entries,
    LeaderboardEntry? playerEntry,
    String? providerId,
  }) => Leaderboard(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    order: order ?? this.order,
    timeScope: timeScope ?? this.timeScope,
    collection: collection ?? this.collection,
    entries: entries ?? this.entries,
    playerEntry: playerEntry ?? this.playerEntry,
    providerId: providerId ?? this.providerId,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Leaderboard &&
          other.id == id &&
          other.displayName == displayName &&
          other.order == order &&
          other.timeScope == timeScope &&
          other.collection == collection &&
          listEquals(other.entries, entries) &&
          other.playerEntry == playerEntry &&
          other.providerId == providerId;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    order,
    timeScope,
    collection,
    listHash(entries),
    playerEntry,
    providerId,
  );

  @override
  String toString() =>
      'Leaderboard(id: $id, displayName: $displayName, order: $order, '
      'timeScope: $timeScope, collection: $collection, '
      'entries: ${entries.length}, playerEntry: $playerEntry, '
      'providerId: $providerId)';
}
