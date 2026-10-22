/// @docImport '../platform_interface/platform_interface.dart';
/// @docImport '../platform_interface/unified_id_table.dart';
library;

import '../internal/equality.dart';
import 'enums.dart';
import 'player_profile.dart';

/// A single ranked row in a [Leaderboard].
class LeaderboardEntry {
  /// 1-based rank of this entry within the queried scope.
  final int rank;

  /// The player who owns this score.
  final PlayerProfile player;

  /// The raw numeric score.
  final int score;

  /// Provider-formatted score for display (e.g. "1:23.45", "1,500 pts").
  ///
  /// `null` when the provider gives no formatting; [displayScore] then falls
  /// back to the raw [score].
  final String? formattedScore;

  /// When the score was achieved, if known.
  final DateTime? achievedAt;

  /// Creates a leaderboard row.
  ///
  /// [rank] is 1-based; [formattedScore] and [achievedAt] are optional.
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
///
/// Returned by [UnifiedGameServicesPlatform.getLeaderboard].
class Leaderboard {
  /// Unified identifier: the key from the [UnifiedLeaderboardTable] the board
  /// was requested with, otherwise the native id itself. See [nativeIds] for
  /// the native ids.
  final String id;

  /// Localized display name, if the provider exposes one.
  final String? displayName;

  /// Whether higher or lower scores rank better.
  final LeaderboardOrder order;

  /// The time window these [entries] were queried for.
  final LeaderboardTimeScope timeScope;

  /// The player set these [entries] were queried for.
  final LeaderboardCollection collection;

  /// Ranked entries, ordered best-first according to [order].
  final List<LeaderboardEntry> entries;

  /// The signed-in player's own entry, or `null` if the provider did not
  /// return one.
  ///
  /// Meant to surface the player's rank when it falls outside [entries].
  final LeaderboardEntry? playerEntry;

  /// [UnifiedGameServicesPlatform.providerId] of the provider this came from.
  ///
  /// Set by the `UnifiedGameServices` facade on reads; `null` when the object
  /// was built by a provider or by hand.
  final String? providerId;

  /// The native id of this leaderboard on each provider, keyed by
  /// `providerId`.
  ///
  /// Read-only. Holds the row of the [UnifiedLeaderboardTable] for [id], plus
  /// the native id the [providerId] provider itself used. Set by the
  /// `UnifiedGameServices` facade on reads; empty when the object was built by
  /// a provider or by hand.
  final Map<String, String> nativeIds;

  /// The native id on the provider this came from ([providerId]), or `null`
  /// when unknown.
  String? get nativeId => providerId == null ? null : nativeIds[providerId];

  /// Creates a leaderboard page identified by [id].
  ///
  /// [entries] defaults to empty and [order], [timeScope] and [collection]
  /// to [LeaderboardOrder.highToLow], [LeaderboardTimeScope.allTime] and
  /// [LeaderboardCollection.global].
  const Leaderboard({
    required this.id,
    this.displayName,
    this.order = LeaderboardOrder.highToLow,
    this.timeScope = LeaderboardTimeScope.allTime,
    this.collection = LeaderboardCollection.global,
    this.entries = const [],
    this.playerEntry,
    this.providerId,
    this.nativeIds = const {},
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
    Map<String, String>? nativeIds,
  }) => Leaderboard(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    order: order ?? this.order,
    timeScope: timeScope ?? this.timeScope,
    collection: collection ?? this.collection,
    entries: entries ?? this.entries,
    playerEntry: playerEntry ?? this.playerEntry,
    providerId: providerId ?? this.providerId,
    nativeIds: nativeIds ?? this.nativeIds,
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
          other.providerId == providerId &&
          mapEquals(other.nativeIds, nativeIds);

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
    mapHash(nativeIds),
  );

  @override
  String toString() =>
      'Leaderboard(id: $id, displayName: $displayName, order: $order, '
      'timeScope: $timeScope, collection: $collection, '
      'entries: ${entries.length}, playerEntry: $playerEntry, '
      'providerId: $providerId, nativeIds: $nativeIds)';
}
