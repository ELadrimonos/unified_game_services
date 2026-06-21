import 'package:dart_mappable/dart_mappable.dart';

part 'player_profile.mapper.dart';

/// A player as represented by a game service provider.
///
/// A profile is identity only; scores live on [LeaderboardEntry] and stats on
/// [Stat]. Fields beyond [id] and [displayName] are optional because providers
/// expose different amounts of data.
@MappableClass()
class PlayerProfile with PlayerProfileMappable {
  /// Provider-scoped unique identifier for the player.
  final String id;

  /// Human-readable name shown in UI.
  final String displayName;

  /// URL of the player's avatar, if the provider exposes one.
  final String? avatarUrl;

  /// Whether the player is currently online, if known.
  final bool? isOnline;

  /// Provider title/rank/level label (e.g. "Level 42"), if any.
  final String? title;

  /// Whether this profile is a friend of the signed-in player.
  final bool? isFriend;

  /// Provider-specific fields with no unified equivalent.
  final Map<String, dynamic> extra;

  const PlayerProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isOnline,
    this.title,
    this.isFriend,
    this.extra = const {},
  });
}
