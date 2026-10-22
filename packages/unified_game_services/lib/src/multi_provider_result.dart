import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// The outcome of one operation on one provider: an [OperationSuccess] or an
/// [OperationFailure].
///
/// These are the entries of [MultiProviderOperationResult.results]. Sealed, so a `switch` is exhaustive and each branch gets typed data:
///
/// ```dart
/// switch (result) {
///   case OperationSuccess(:final providerId, :final value):
///     print('$providerId -> $value');
///   case OperationFailure(:final providerId, :final error):
///     print('$providerId failed: ${error.message}');
/// }
/// ```
sealed class ProviderOperationResult<T> {
  const ProviderOperationResult({required this.providerId});

  /// Wraps an arbitrary thrown [error] from [providerId] as an
  /// [OperationFailure].
  ///
  /// A [GameServiceException] is kept as-is; anything else (an
  /// [UnimplementedError] from a provider that does not override the
  /// operation, a `StateError`, …) is wrapped in a
  /// [PlatformOperationException] whose message is `error.toString()` and whose
  /// `cause` is the original object. [stackTrace] is kept for
  /// [OperationFailure.stackTrace].
  factory ProviderOperationResult.fromError(
    String providerId,
    Object error, [
    StackTrace? stackTrace,
  ]) => OperationFailure<T>(
    providerId: providerId,
    error: error is GameServiceException
        ? error
        : PlatformOperationException(error.toString(), cause: error),
    stackTrace: stackTrace,
  );

  /// The [UnifiedGameServicesPlatform.providerId] of the provider that produced
  /// this outcome.
  final String providerId;

  /// Whether the provider completed the operation.
  bool get isSuccess => this is OperationSuccess<T>;

  /// Whether the provider failed.
  bool get isFailure => this is OperationFailure<T>;

  /// The returned value, or `null` on failure.
  ///
  /// Also `null` for `void` operations and for operations whose successful
  /// value is itself nullable (such as `getCurrentPlayer`), so use [isSuccess]
  /// to tell those apart from a failure.
  T? get valueOrNull => switch (this) {
    OperationSuccess<T>(:final value) => value,
    OperationFailure<T>() => null,
  };

  /// The raised error, or `null` on success.
  GameServiceException? get errorOrNull => switch (this) {
    OperationSuccess<T>() => null,
    OperationFailure<T>(:final error) => error,
  };

  /// The returned value, or rethrows the provider's error on failure.
  ///
  /// The rethrown error keeps its original [OperationFailure.stackTrace] when
  /// one was captured.
  T getOrThrow() => switch (this) {
    OperationSuccess<T>(:final value) => value,
    OperationFailure<T>(:final error, :final stackTrace) =>
      Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current),
  };

  /// Calls [success] or [failure] depending on the outcome and returns what it
  /// returns.
  R when<R>({
    required R Function(T value) success,
    required R Function(GameServiceException error) failure,
  }) => switch (this) {
    OperationSuccess<T>(:final value) => success(value),
    OperationFailure<T>(:final error) => failure(error),
  };
}

/// [providerId] completed the operation and returned [value] (`null` for
/// `void` operations).
final class OperationSuccess<T> extends ProviderOperationResult<T> {
  /// A successful outcome from [providerId].
  const OperationSuccess({required super.providerId, required this.value});

  /// What the provider returned (`null` for `void` operations).
  final T value;

  @override
  String toString() => 'OperationSuccess($providerId: $value)';
}

/// [providerId] raised [error].
final class OperationFailure<T> extends ProviderOperationResult<T> {
  /// A failed outcome from [providerId].
  const OperationFailure({
    required super.providerId,
    required this.error,
    this.stackTrace,
  });

  /// What the provider threw, normalized to a [GameServiceException].
  final GameServiceException error;

  /// Stack trace of [error], when one was captured.
  final StackTrace? stackTrace;

  @override
  String toString() => 'OperationFailure($providerId: $error)';
}

/// The per-provider outcomes of an operation the facade broadcast to several
/// providers.
///
/// A provider failing is **data**, not an exception: every attempted provider
/// has an entry in [results], in the facade's provider order, regardless of the
/// order in which they finished. The providers run concurrently, and ones that
/// succeeded are never rolled back when another fails. Which providers are
/// attempted depends on the operation: capability-gated writes and `*FromAll`
/// reads target only providers advertising the capability, while `signIn`,
/// `signOut` and `dispose` target every provider.
///
/// ```dart
/// final result = await services.submitScore(
///   leaderboardId: 'global',
///   score: 4200,
/// );
/// for (final ok in result.succeeded) {
///   print('${ok.providerId} ok');
/// }
/// for (final bad in result.failed) {
///   print('${bad.providerId}: ${bad.error}');
/// }
/// ```
///
/// Use [throwIfAnyFailed] for all-or-nothing handling.
final class MultiProviderOperationResult<T> {
  /// Creates a result from the per-provider [results] of [operation].
  MultiProviderOperationResult(
    this.operation,
    Iterable<ProviderOperationResult<T>> results,
  ) : results = List.unmodifiable(results);

  /// Name of the facade operation (e.g. `submitScore`), for diagnostics.
  final String operation;

  /// One entry per attempted provider, in provider order.
  ///
  /// Unmodifiable. Providers that were not attempted have no entry.
  final List<ProviderOperationResult<T>> results;

  /// Providers that completed the operation.
  Iterable<OperationSuccess<T>> get succeeded =>
      results.whereType<OperationSuccess<T>>();

  /// Providers that failed, with their original errors.
  Iterable<OperationFailure<T>> get failed =>
      results.whereType<OperationFailure<T>>();

  /// Values returned by the providers that succeeded, in provider order.
  ///
  /// Meaningful for reads; for `void` operations every value is `null`.
  Iterable<T> get values => succeeded.map((r) => r.value);

  /// Errors raised by the providers that failed.
  Iterable<GameServiceException> get errors => failed.map((r) => r.error);

  /// Ids of the providers that succeeded.
  List<String> get successfulProviders =>
      succeeded.map((r) => r.providerId).toList(growable: false);

  /// Ids of the providers that failed.
  List<String> get failedProviders =>
      failed.map((r) => r.providerId).toList(growable: false);

  /// Whether every attempted provider succeeded.
  ///
  /// Vacuously `true` when [results] is empty, which only happens for
  /// `UnifiedGameServices.syncAchievements` when nothing needed syncing.
  bool get allSucceeded => results.every((r) => r.isSuccess);

  /// Whether at least one attempted provider succeeded.
  bool get anySucceeded => results.any((r) => r.isSuccess);

  /// Whether at least one attempted provider failed.
  bool get anyFailed => results.any((r) => r.isFailure);

  /// Whether at least one provider was attempted and all of them failed.
  ///
  /// Unlike [allSucceeded], `false` when [results] is empty.
  bool get allFailed => results.isNotEmpty && results.every((r) => r.isFailure);

  /// The result of the provider with id [providerId], or `null` if it was not
  /// attempted.
  ProviderOperationResult<T>? operator [](String providerId) {
    for (final r in results) {
      if (r.providerId == providerId) return r;
    }
    return null;
  }

  /// Throws the first provider error (in provider order) unless every provider
  /// succeeded.
  ///
  /// For callers that want all-or-nothing semantics instead of inspecting
  /// [failed]. Any further failures are not thrown, and providers that
  /// succeeded are not rolled back. The error is rethrown with its original
  /// stack trace when available. Does nothing when [results] is empty.
  void throwIfAnyFailed() {
    for (final r in failed) {
      Error.throwWithStackTrace(r.error, r.stackTrace ?? StackTrace.current);
    }
  }

  @override
  String toString() =>
      'MultiProviderOperationResult($operation: '
      '${succeeded.length} ok, ${failed.length} failed)';
}
