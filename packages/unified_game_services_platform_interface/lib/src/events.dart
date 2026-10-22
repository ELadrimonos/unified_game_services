/// @docImport 'capabilities.dart';
/// @docImport 'platform_interface/platform_interface.dart';
library;

import 'models/achievement.dart';
import 'models/lobby.dart';
import 'models/player_profile.dart';
import 'models/rich_presence.dart';
import 'models/stat.dart';

/// Base type for events emitted by [UnifiedGameServicesPlatform.events].
///
/// This is a sealed hierarchy: switch over a [GameServiceEvent] to handle each
/// concrete kind exhaustively.
///
/// ```dart
/// String describe(GameServiceEvent event) => switch (event) {
///   UserSignedInEvent(:final player) => 'in: ${player.displayName}',
///   UserSignedOutEvent() => 'out',
///   AchievementUnlockedEvent(:final achievement) => achievement.title,
///   ScoreSubmittedEvent(:final score) => 'score $score',
///   StatUpdatedEvent(:final stat) => '${stat.key}=${stat.value}',
///   PresenceChangedEvent(:final presence) => presence?.state ?? 'cleared',
///   InvitationReceivedEvent(:final senderId) => 'invite from $senderId',
/// };
/// ```
sealed class GameServiceEvent {
  /// When the event occurred.
  final DateTime timestamp;

  /// Creates an event that occurred at [timestamp].
  const GameServiceEvent({required this.timestamp});
}

/// Emitted after a player successfully signs in.
class UserSignedInEvent extends GameServiceEvent {
  /// The player who signed in.
  final PlayerProfile player;

  /// Creates an event for [player] signing in at [timestamp].
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
  /// Creates an event for a sign-out at [timestamp].
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

  /// Creates an event for [achievement] being unlocked at [timestamp].
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

  /// Creates an event for [score] being submitted to [leaderboardId] at
  /// [timestamp].
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

  /// Creates an event for [stat] changing at [timestamp].
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

  /// Creates an event for a presence change at [timestamp].
  ///
  /// Omit [presence] (or pass `null`) when the presence was cleared.
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

/// Emitted when a game invitation is received.
///
/// Accept it by passing [joinToken] to [UnifiedGameServicesPlatform.joinLobby]
/// on the provider named by [providerId]. Gated by
/// [GameCapability.invitations].
class InvitationReceivedEvent extends GameServiceEvent {
  /// [PlayerProfile.id] of the sender.
  final String senderId;

  /// The token to pass to [UnifiedGameServicesPlatform.joinLobby] (see
  /// [Lobby.joinToken]).
  final String joinToken;

  /// [UnifiedGameServicesPlatform.providerId] of the provider that delivered
  /// the invitation.
  final String providerId;

  /// Creates an event for an invitation from [senderId] received at
  /// [timestamp].
  ///
  /// [joinToken] and [providerId] identify the lobby and the provider to
  /// join it through.
  const InvitationReceivedEvent({
    required this.senderId,
    required this.joinToken,
    required this.providerId,
    required super.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvitationReceivedEvent &&
          other.senderId == senderId &&
          other.joinToken == joinToken &&
          other.providerId == providerId &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(senderId, joinToken, providerId, timestamp);

  @override
  String toString() =>
      'InvitationReceivedEvent(senderId: $senderId, joinToken: $joinToken, '
      'providerId: $providerId, timestamp: $timestamp)';
}

/// Emitted when the player asks to join someone through a provider's own UI
/// (an accepted invitation, a "Join" button on a friend's presence).
///
/// Pass [joinToken] to `joinLobby`; the lobby may live in a different provider
/// than the one that delivered this event.
class JoinRequestedEvent extends GameServiceEvent {
  /// The token to pass to `joinLobby`.
  final String joinToken;

  /// `providerId` of the provider that delivered the request.
  final String providerId;

  const JoinRequestedEvent({
    required this.joinToken,
    required this.providerId,
    required super.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JoinRequestedEvent &&
          other.joinToken == joinToken &&
          other.providerId == providerId &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(joinToken, providerId, timestamp);

  @override
  String toString() =>
      'JoinRequestedEvent(joinToken: $joinToken, providerId: $providerId, '
      'timestamp: $timestamp)';
}

/// Base type of the events about a [Lobby]; each carries the updated snapshot.
sealed class LobbyEvent extends GameServiceEvent {
  /// The lobby after the change.
  final Lobby lobby;

  const LobbyEvent({required this.lobby, required super.timestamp});
}

/// A member joined [lobby].
class LobbyMemberJoinedEvent extends LobbyEvent {
  /// The member who joined.
  final LobbyMember member;

  const LobbyMemberJoinedEvent({
    required super.lobby,
    required this.member,
    required super.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LobbyMemberJoinedEvent &&
          other.lobby == lobby &&
          other.member == member &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(lobby, member, timestamp);

  @override
  String toString() =>
      'LobbyMemberJoinedEvent(lobby: $lobby, member: $member, '
      'timestamp: $timestamp)';
}

/// A member left [lobby] (left, disconnected or was removed).
class LobbyMemberLeftEvent extends LobbyEvent {
  /// The member who left.
  final LobbyMember member;

  const LobbyMemberLeftEvent({
    required super.lobby,
    required this.member,
    required super.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LobbyMemberLeftEvent &&
          other.lobby == lobby &&
          other.member == member &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(lobby, member, timestamp);

  @override
  String toString() =>
      'LobbyMemberLeftEvent(lobby: $lobby, member: $member, '
      'timestamp: $timestamp)';
}

/// The lobby's data, visibility or a member's data changed.
class LobbyDataChangedEvent extends LobbyEvent {
  const LobbyDataChangedEvent({required super.lobby, required super.timestamp});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LobbyDataChangedEvent &&
          other.lobby == lobby &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(lobby, timestamp);

  @override
  String toString() =>
      'LobbyDataChangedEvent(lobby: $lobby, timestamp: $timestamp)';
}

/// The lobby has a new owner ([Lobby.ownerId]).
class LobbyOwnerChangedEvent extends LobbyEvent {
  /// [PlayerProfile.id] of the previous owner.
  final String previousOwnerId;

  const LobbyOwnerChangedEvent({
    required super.lobby,
    required this.previousOwnerId,
    required super.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LobbyOwnerChangedEvent &&
          other.lobby == lobby &&
          other.previousOwnerId == previousOwnerId &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(lobby, previousOwnerId, timestamp);

  @override
  String toString() =>
      'LobbyOwnerChangedEvent(lobby: $lobby, '
      'previousOwnerId: $previousOwnerId, timestamp: $timestamp)';
}

/// The lobby no longer exists (the last member left or it was destroyed).
class LobbyClosedEvent extends LobbyEvent {
  const LobbyClosedEvent({required super.lobby, required super.timestamp});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LobbyClosedEvent &&
          other.lobby == lobby &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(lobby, timestamp);

  @override
  String toString() => 'LobbyClosedEvent(lobby: $lobby, timestamp: $timestamp)';
}
