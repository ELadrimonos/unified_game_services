/// @docImport '../platform_interface/platform_interface.dart';
library;

/// The player's current activity, published to friends.
///
/// Providers expose different subsets of these fields; only [state] is
/// required. Published with [UnifiedGameServicesPlatform.setPresence].
class RichPresence {
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

  /// Creates a presence with the activity line [state].
  ///
  /// [details], [startedAt], [partySize] and [partyMax] are optional.
  const RichPresence({
    required this.state,
    this.details,
    this.startedAt,
    this.partySize,
    this.partyMax,
  });

  /// Returns a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the current value, so a field cannot be reset to
  /// `null` through this method; build a new instance for that.
  RichPresence copyWith({
    String? state,
    String? details,
    DateTime? startedAt,
    int? partySize,
    int? partyMax,
  }) => RichPresence(
    state: state ?? this.state,
    details: details ?? this.details,
    startedAt: startedAt ?? this.startedAt,
    partySize: partySize ?? this.partySize,
    partyMax: partyMax ?? this.partyMax,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RichPresence &&
          other.state == state &&
          other.details == details &&
          other.startedAt == startedAt &&
          other.partySize == partySize &&
          other.partyMax == partyMax;

  @override
  int get hashCode =>
      Object.hash(state, details, startedAt, partySize, partyMax);

  @override
  String toString() =>
      'RichPresence(state: $state, details: $details, startedAt: $startedAt, '
      'partySize: $partySize, partyMax: $partyMax)';
}
