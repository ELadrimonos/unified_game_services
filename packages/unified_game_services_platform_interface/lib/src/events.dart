import 'models/achievement.dart';
import 'models/player_profile.dart';
import 'models/rich_presence.dart';
import 'models/stat.dart';

/// Base type for events emitted by [UnifiedGameServicesPlatform.events].
///
/// This is a sealed hierarchy: switch over a [GameServiceEvent] to handle each
/// concrete kind exhaustively.
sealed class GameServiceEvent {
  /// When the event occurred.
  final DateTime timestamp;

  const GameServiceEvent({required this.timestamp});
}

/// Emitted after a player successfully signs in.
class UserSignedInEvent extends GameServiceEvent {
  /// The player who signed in.
  final PlayerProfile player;

  const UserSignedInEvent({required this.player, required super.timestamp});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSignedInEvent &&
          other.player == player &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(player, timestamp);

  @override
  String toString() =>
      'UserSignedInEvent(player: $player, timestamp: $timestamp)';
}

/// Emitted after the active player signs out.
class UserSignedOutEvent extends GameServiceEvent {
  const UserSignedOutEvent({required super.timestamp});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSignedOutEvent && other.timestamp == timestamp;

  @override
  int get hashCode => timestamp.hashCode;

  @override
  String toString() => 'UserSignedOutEvent(timestamp: $timestamp)';
}

/// Emitted when an achievement is unlocked.
class AchievementUnlockedEvent extends GameServiceEvent {
  /// The achievement that was unlocked.
  final Achievement achievement;

  const AchievementUnlockedEvent({
    required this.achievement,
    required super.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AchievementUnlockedEvent &&
          other.achievement == achievement &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(achievement, timestamp);

  @override
  String toString() =>
      'AchievementUnlockedEvent(achievement: $achievement, '
      'timestamp: $timestamp)';
}

/// Emitted after a score is submitted to a leaderboard.
class ScoreSubmittedEvent extends GameServiceEvent {
  /// Identifier of the leaderboard the score was submitted to.
  final String leaderboardId;

  /// The submitted score.
  final int score;

  const ScoreSubmittedEvent({
    required this.leaderboardId,
    required this.score,
    required super.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScoreSubmittedEvent &&
          other.leaderboardId == leaderboardId &&
          other.score == score &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(leaderboardId, score, timestamp);

  @override
  String toString() =>
      'ScoreSubmittedEvent(leaderboardId: $leaderboardId, score: $score, '
      'timestamp: $timestamp)';
}

/// Emitted when a player statistic changes.
class StatUpdatedEvent extends GameServiceEvent {
  /// The stat after the update.
  final Stat stat;

  const StatUpdatedEvent({required this.stat, required super.timestamp});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatUpdatedEvent &&
          other.stat == stat &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(stat, timestamp);

  @override
  String toString() => 'StatUpdatedEvent(stat: $stat, timestamp: $timestamp)';
}

/// Emitted when the player's rich presence changes.
class PresenceChangedEvent extends GameServiceEvent {
  /// The new presence, or `null` if presence was cleared.
  final RichPresence? presence;

  const PresenceChangedEvent({this.presence, required super.timestamp});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PresenceChangedEvent &&
          other.presence == presence &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(presence, timestamp);

  @override
  String toString() =>
      'PresenceChangedEvent(presence: $presence, timestamp: $timestamp)';
}
