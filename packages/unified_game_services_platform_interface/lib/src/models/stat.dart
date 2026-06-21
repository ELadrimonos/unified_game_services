import 'package:dart_mappable/dart_mappable.dart';

part 'stat.mapper.dart';

/// A numeric player statistic (e.g. `kills`, `distance_travelled`).
///
/// Values are stored as [num] to cover both integer and floating-point stats.
@MappableClass()
class Stat with StatMappable {
  /// Provider-scoped key identifying the stat.
  final String key;

  /// Current value.
  final num value;

  /// Localized display name, if the provider exposes one.
  final String? displayName;

  const Stat({
    required this.key,
    required this.value,
    this.displayName,
  });

  /// The value as an [int] (truncated).
  int get asInt => value.toInt();

  /// The value as a [double].
  double get asDouble => value.toDouble();
}
