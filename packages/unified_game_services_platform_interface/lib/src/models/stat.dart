import '../internal/equality.dart';

/// A numeric player statistic (e.g. `kills`, `distance_travelled`).
///
/// Values are stored as [num] to cover both integer and floating-point stats.
class Stat {
  /// Unified key: the key from the `UnifiedStatTable` the stat was requested
  /// with, otherwise the native key itself. See [nativeKeys] for the native keys.
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

  /// The native key of this stat on each provider, keyed by `providerId`.
  ///
  /// Read-only. Holds the row of the `UnifiedStatTable` for [key], plus the
  /// native key the [providerId] provider itself used. Set by the
  /// `UnifiedGameServices` facade on reads; empty when the object was built by
  /// a provider or by hand.
  final Map<String, String> nativeKeys;

  /// The native key on the provider this came from ([providerId]), or `null`
  /// when unknown.
  String? get nativeKey => providerId == null ? null : nativeKeys[providerId];

  const Stat({
    required this.key,
    required this.value,
    this.displayName,
    this.providerId,
    this.nativeKeys = const {},
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
    Map<String, String>? nativeKeys,
  }) => Stat(
    key: key ?? this.key,
    value: value ?? this.value,
    displayName: displayName ?? this.displayName,
    providerId: providerId ?? this.providerId,
    nativeKeys: nativeKeys ?? this.nativeKeys,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Stat &&
          other.key == key &&
          other.value == value &&
          other.displayName == displayName &&
          other.providerId == providerId &&
          mapEquals(other.nativeKeys, nativeKeys);

  @override
  int get hashCode =>
      Object.hash(key, value, displayName, providerId, mapHash(nativeKeys));

  @override
  String toString() =>
      'Stat(key: $key, value: $value, displayName: $displayName, '
      'providerId: $providerId, nativeKeys: $nativeKeys)';
}
