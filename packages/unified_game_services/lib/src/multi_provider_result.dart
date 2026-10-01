import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// The outcome of one operation on one provider.
///
/// Either a success (with the provider's returned [value], `null` for `void`
/// operations) or a failure carrying the [error] the provider raised.
class ProviderOperationResult<T> {
  /// A successful outcome from [providerId].
  const ProviderOperationResult.success(this.providerId, [this.value])
    : success = true,
      error = null,
      stackTrace = null;

  /// A failed outcome from [providerId].
  const ProviderOperationResult.failure(
    this.providerId,
    GameServiceException this.error, [
    this.stackTrace,
  ]) : success = false,
       value = null;

  /// Wraps an arbitrary thrown [error] as a failure.
  ///
  /// A [GameServiceException] is kept as-is; anything else (an
  /// [UnimplementedError], a `StateError`, …) is wrapped in a
  /// [PlatformOperationException] whose `cause` is the original object.
  factory ProviderOperationResult.fromError(
    String providerId,
    Object error, [
    StackTrace? stackTrace,
  ]) => ProviderOperationResult.failure(
    providerId,
    error is GameServiceException
        ? error
        : PlatformOperationException(error.toString(), cause: error),
    stackTrace,
  );

  /// The [UnifiedGameServicesPlatform.providerId] of the provider.
  final String providerId;

  /// Whether the provider completed the operation.
  final bool success;

  /// What the provider returned. `null` on failure and for `void` operations.
  final T? value;

  /// What the provider threw. `null` on success.
  final GameServiceException? error;

  /// Stack trace of [error], when captured.
  final StackTrace? stackTrace;

  /// Whether the provider failed (`!success`).
  bool get failed => !success;

  @override
  String toString() => success
      ? 'ProviderOperationResult($providerId: ok)'
      : 'ProviderOperationResult($providerId: failed — $error)';
}

/// The per-provider outcomes of an operation the facade broadcast to several
/// providers.
///
/// A provider failing is **data**, not an exception: every attempted provider
/// has an entry in [results], in the facade's provider order. Providers that
/// succeeded are never rolled back when another fails.
///
/// ```dart
/// final result = await services.submitScore(leaderboardId: 'global', score: 4200);
/// for (final r in result.succeeded) print('${r.providerId} ok');
/// for (final r in result.failed) print('${r.providerId} failed: ${r.error}');
/// ```
class MultiProviderOperationResult<T> {
  /// Creates a result from the per-provider [results] of [operation].
  MultiProviderOperationResult(
    this.operation,
    Iterable<ProviderOperationResult<T>> results,
  ) : results = List.unmodifiable(results);

  /// Name of the facade operation (e.g. `submitScore`).
  final String operation;

  /// One entry per attempted provider, in provider order.
  final List<ProviderOperationResult<T>> results;

  /// Providers that completed the operation.
  Iterable<ProviderOperationResult<T>> get succeeded =>
      results.where((r) => r.success);

  /// Providers that failed, with their original errors.
  Iterable<ProviderOperationResult<T>> get failed =>
      results.where((r) => !r.success);

  /// Ids of the providers that succeeded.
  List<String> get successfulProviders =>
      succeeded.map((r) => r.providerId).toList(growable: false);

  /// Ids of the providers that failed.
  List<String> get failedProviders =>
      failed.map((r) => r.providerId).toList(growable: false);

  /// Whether every attempted provider succeeded.
  bool get allSucceeded => results.every((r) => r.success);

  /// Whether at least one attempted provider succeeded.
  bool get anySucceeded => results.any((r) => r.success);

  /// Whether at least one provider was attempted and all of them failed.
  bool get allFailed => results.isNotEmpty && results.every((r) => !r.success);

  /// The result of [providerId], or `null` if it was not attempted.
  ProviderOperationResult<T>? operator [](String providerId) {
    for (final r in results) {
      if (r.providerId == providerId) return r;
    }
    return null;
  }

  @override
  String toString() =>
      'MultiProviderOperationResult($operation: '
      '${succeeded.length} ok, ${failed.length} failed)';
}
