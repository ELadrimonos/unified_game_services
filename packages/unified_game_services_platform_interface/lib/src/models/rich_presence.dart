import 'package:dart_mappable/dart_mappable.dart';

part 'rich_presence.mapper.dart';

/// The player's current activity, published to friends.
///
/// Providers expose different subsets of these fields; only [state] is
/// required.
@MappableClass()
class RichPresence with RichPresenceMappable {
  /// Short, user-facing activity line (e.g. "Playing Ranked").
  final String state;

  /// Secondary detail line (e.g. "Map: Dust II"), if any.
  final String? details;

  /// When the current activity/session started, if tracked.
  final DateTime? startedAt;

  /// Current party size, if the player is in a party.
  final int? partySize;

  /// Maximum party size, if applicable.
  final int? partyMax;

  const RichPresence({
    required this.state,
    this.details,
    this.startedAt,
    this.partySize,
    this.partyMax,
  });
}
