/// @docImport 'platform_interface/platform_interface.dart';
library;

import 'capabilities.dart';

/// Base type for all errors thrown by the unified game services API.
///
/// Providers should translate their native/SDK errors into one of the
/// subtypes so callers can handle failures uniformly across platforms:
///
/// - [NotSignedInException]: the operation needs a signed-in player.
/// - [SignInFailedException]: [UnifiedGameServicesPlatform.signIn] failed or
///   was cancelled.
/// - [CapabilityNotSupportedException]: the provider does not support the
///   required [GameCapability].
/// - [NetworkException]: connectivity problems.
/// - [PlatformOperationException]: any other provider/SDK failure.
class GameServiceException implements Exception {
  /// Human-readable description of what went wrong.
  final String message;

  /// Provider-specific error code, or `null` if the provider has none.
  final String? code;

  /// The underlying error this wraps, if any.
  final Object? cause;

  /// Creates an exception described by [message].
  ///
  /// [code] carries a provider-specific error code and [cause] the native
  /// error being wrapped.
  const GameServiceException(this.message, {this.code, this.cause});

  /// Describes this exception as `<runtimeType>: <message>`.
  ///
  /// Appends the [code] and the [cause], when present.
  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (code != null) buffer.write(' (code: $code)');
    if (cause != null) buffer.write('\nCaused by: $cause');
    return buffer.toString();
  }
}

/// Thrown when an operation requires an authenticated player but none is
/// signed in.
class NotSignedInException extends GameServiceException {
  /// Creates an exception with a default [message] of `No player is signed in.`
  ///
  /// [cause] is the underlying error, if any.
  const NotSignedInException([
    super.message = 'No player is signed in.',
    Object? cause,
  ]) : super(cause: cause);
}

/// Thrown when sign-in fails or is cancelled by the player.
class SignInFailedException extends GameServiceException {
  /// Creates an exception with a default [message] of `Sign-in failed.`
  ///
  /// [cause] is the underlying error, if any.
  const SignInFailedException([
    super.message = 'Sign-in failed.',
    Object? cause,
  ]) : super(cause: cause);
}

/// Thrown when a requested operation needs a [GameCapability] the active
/// provider does not support.
class CapabilityNotSupportedException extends GameServiceException {
  /// The capability that was required but unsupported.
  final GameCapability capability;

  /// Creates an exception for the unsupported [capability].
  ///
  /// The message names the capability. [cause] is the underlying
  /// error, if any.
  CapabilityNotSupportedException(this.capability, {super.cause})
    : super(
        'Capability "${capability.name}" is not supported by this provider.',
      );
}

/// Thrown when an operation fails due to connectivity problems.
class NetworkException extends GameServiceException {
  /// Creates an exception with a default [message] of
  /// `A network error occurred.`
  ///
  /// [cause] is the underlying error, if any (for example a socket or HTTP
  /// client exception).
  const NetworkException([
    super.message = 'A network error occurred.',
    Object? cause,
  ]) : super(cause: cause);
}

/// Thrown for provider/SDK failures with no more specific subtype.
///
/// Providers should use this as the fallback when mapping native errors.
class PlatformOperationException extends GameServiceException {
  /// Creates an exception described by [message].
  ///
  /// [code] carries the provider-specific error code and [cause] the native
  /// error being wrapped.
  const PlatformOperationException(super.message, {super.code, super.cause});
}
