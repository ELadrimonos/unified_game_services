/// @docImport 'achievement.dart';
/// @docImport 'leaderboard.dart';
/// @docImport 'stat.dart';
/// @docImport '../platform_interface/platform_interface.dart';
library;

import '../internal/equality.dart';

/// A player as represented by a game service provider.
///
/// A profile is identity only; scores live on [LeaderboardEntry] and stats on
/// [Stat]. Fields beyond [id] and [displayName] are optional because providers
/// expose different amounts of data.
///
/// Returned by [UnifiedGameServicesPlatform.signIn],
/// [UnifiedGameServicesPlatform.getCurrentPlayer] and
/// [UnifiedGameServicesPlatform.getFriends].
class PlayerProfile {
  /// Provider-scoped unique identifier for the player.
  final String id;

  /// Human-readable name shown in UI.
  final String displayName;

  /// URL of the player's avatar, if the provider exposes one.
  final String? avatarUrl;

  /// Whether the player is currently online, or `null` if unknown.
  final bool? isOnline;

  /// Provider title/rank/level label (e.g. "Level 42"), if any.
  final String? title;

  /// Whether this profile is a friend of the signed-in player, or `null` if
  /// unknown.
  final bool? isFriend;

  /// Provider-specific fields with no unified equivalent.
  ///
  /// Empty by default. Keys and value types are defined by each provider and
  /// are not portable.
  final Map<String, dynamic> extra;

  /// [UnifiedGameServicesPlatform.providerId] of the provider this came from.
  ///
  /// Set by the `UnifiedGameServices` facade on reads; `null` when the object
  /// was built by a provider or by hand.
  final String? providerId;

  /// Creates a profile for the player with provider-scoped [id] shown as
  /// [displayName].
  ///
  /// The remaining fields are optional because providers expose different
  /// amounts of data; [extra] defaults to empty.
  const PlayerProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isOnline,
    this.title,
    this.isFriend,
    this.extra = const {},
    this.providerId,
  });

  /// Returns a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the current value, so a field cannot be reset to
  /// `null` through this method; build a new instance for that.
  PlayerProfile copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    bool? isOnline,
    String? title,
    bool? isFriend,
    Map<String, dynamic>? extra,
    String? providerId,
  }) => PlayerProfile(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isOnline: isOnline ?? this.isOnline,
    title: title ?? this.title,
    isFriend: isFriend ?? this.isFriend,
    extra: extra ?? this.extra,
    providerId: providerId ?? this.providerId,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerProfile &&
          other.id == id &&
          other.displayName == displayName &&
          other.avatarUrl == avatarUrl &&
          other.isOnline == isOnline &&
          other.title == title &&
          other.isFriend == isFriend &&
          mapEquals(other.extra, extra) &&
          other.providerId == providerId;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    avatarUrl,
    isOnline,
    title,
    isFriend,
    mapHash(extra),
    providerId,
  );

  @override
  String toString() =>
      'PlayerProfile(id: $id, displayName: $displayName, '
      'avatarUrl: $avatarUrl, isOnline: $isOnline, title: $title, '
      'isFriend: $isFriend, extra: $extra, providerId: $providerId)';
}
