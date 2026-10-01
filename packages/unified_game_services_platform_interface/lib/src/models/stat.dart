/// A numeric player statistic (e.g. `kills`, `distance_travelled`).
///
/// Values are stored as [num] to cover both integer and floating-point stats.
class Stat {
  /// Provider-scoped key identifying the stat.
  final String key;

  /// Current value.
  final num value;

  /// Localized display name, if the provider exposes one.
  final String? displayName;

  /// [UnifiedGameServicesPlatform.providerId] of the provider this came from.
  ///
  /// Set by the `UnifiedGameServices` facade on reads; `null` when the object
  /// was built by a provider or by hand.
  final String? providerId;

  const Stat({
    required this.key,
    required this.value,
    this.displayName,
    this.providerId,
  });

  /// The value as an [int] (truncated).
  int get asInt => value.toInt();

  /// The value as a [double].
  double get asDouble => value.toDouble();

  /// Returns a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the current value, so a field cannot be reset to
  /// `null` through this method; build a new instance for that.
  Stat copyWith({
    String? key,
    num? value,
    String? displayName,
    String? providerId,
  }) => Stat(
    key: key ?? this.key,
    value: value ?? this.value,
    displayName: displayName ?? this.displayName,
    providerId: providerId ?? this.providerId,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Stat &&
          other.key == key &&
          other.value == value &&
          other.displayName == displayName &&
          other.providerId == providerId;

  @override
  int get hashCode => Object.hash(key, value, displayName, providerId);

  @override
  String toString() =>
      'Stat(key: $key, value: $value, displayName: $displayName, '
      'providerId: $providerId)';
}
