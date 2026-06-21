import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Thrown by [UnifiedGameServices] when a fan-out operation fails on one or
/// more providers.
///
/// The operation is always attempted on every targeted provider; the errors
/// from those that failed are collected here. Providers that succeeded are not
/// rolled back.
class AggregateGameServiceException extends GameServiceException {
  AggregateGameServiceException(this.operation, this.errors)
      : super('$operation failed on ${errors.length} provider(s).');

  /// Name of the fan-out operation (e.g. `unlockAchievement`).
  final String operation;

  /// The errors thrown by the providers that failed.
  final List<Object> errors;

  @override
  String toString() =>
      'AggregateGameServiceException: $message\n'
      '${errors.map((e) => '  - $e').join('\n')}';
}
