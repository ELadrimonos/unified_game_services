import 'package:dart_mappable/dart_mappable.dart';

import 'models/models.dart';

part 'events.mapper.dart';

/// Base type for events emitted by [UnifiedGameServicesPlatform.events].
///
/// This is a sealed hierarchy: switch over a [GameServiceEvent] to handle each
/// concrete kind exhaustively. The discriminator key `type` distinguishes
/// subtypes when (de)serialized.
@MappableClass(discriminatorKey: 'type')
sealed class GameServiceEvent with GameServiceEventMappable {
  /// When the event occurred.
  final DateTime timestamp;

  const GameServiceEvent({required this.timestamp});
}

/// Emitted after a player successfully signs in.
@MappableClass(discriminatorValue: 'userSignedIn')
class UserSignedInEvent extends GameServiceEvent with UserSignedInEventMappable {
  /// The player who signed in.
  final PlayerProfile player;

  const UserSignedInEvent({required this.player, required super.timestamp});
}

/// Emitted after the active player signs out.
@MappableClass(discriminatorValue: 'userSignedOut')
class UserSignedOutEvent extends GameServiceEvent
    with UserSignedOutEventMappable {
  const UserSignedOutEvent({required super.timestamp});
}

/// Emitted when an achievement is unlocked.
@MappableClass(discriminatorValue: 'achievementUnlocked')
class AchievementUnlockedEvent extends GameServiceEvent
    with AchievementUnlockedEventMappable {
  /// The achievement that was unlocked.
  final Achievement achievement;

  const AchievementUnlockedEvent({
    required this.achievement,
    required super.timestamp,
  });
}

/// Emitted after a score is submitted to a leaderboard.
@MappableClass(discriminatorValue: 'scoreSubmitted')
class ScoreSubmittedEvent extends GameServiceEvent
    with ScoreSubmittedEventMappable {
  /// Identifier of the leaderboard the score was submitted to.
  final String leaderboardId;

  /// The submitted score.
  final int score;

  const ScoreSubmittedEvent({
    required this.leaderboardId,
    required this.score,
    required super.timestamp,
  });
}

/// Emitted when a player statistic changes.
@MappableClass(discriminatorValue: 'statUpdated')
class StatUpdatedEvent extends GameServiceEvent with StatUpdatedEventMappable {
  /// The stat after the update.
  final Stat stat;

  const StatUpdatedEvent({required this.stat, required super.timestamp});
}

/// Emitted when the player's rich presence changes.
@MappableClass(discriminatorValue: 'presenceChanged')
class PresenceChangedEvent extends GameServiceEvent
    with PresenceChangedEventMappable {
  /// The new presence, or `null` if presence was cleared.
  final RichPresence? presence;

  const PresenceChangedEvent({this.presence, required super.timestamp});
}
