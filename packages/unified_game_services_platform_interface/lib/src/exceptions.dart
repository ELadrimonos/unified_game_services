import 'capabilities.dart';

/// Base type for all errors thrown by the unified game services API.
///
/// Providers should translate their native/SDK errors into one of the
/// subtypes so callers can handle failures uniformly across platforms.
class GameServiceException implements Exception {
  /// Human-readable description of what went wrong.
  final String message;

  /// Optional provider-specific error code.
  final String? code;

  /// The underlying error this wraps, if any.
  final Object? cause;

  const GameServiceException(this.message, {this.code, this.cause});

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
  const NotSignedInException([
    super.message = 'No player is signed in.',
    Object? cause,
  ]) : super(cause: cause);
}

/// Thrown when sign-in fails or is cancelled by the player.
class SignInFailedException extends GameServiceException {
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

  CapabilityNotSupportedException(this.capability, {Object? cause})
      : super(
          'Capability "${capability.name}" is not supported by this provider.',
          cause: cause,
        );
}

/// Thrown when an operation fails due to connectivity problems.
class NetworkException extends GameServiceException {
  const NetworkException([
    super.message = 'A network error occurred.',
    Object? cause,
  ]) : super(cause: cause);
}

/// Thrown for provider/SDK failures with no more specific subtype.
class PlatformOperationException extends GameServiceException {
  const PlatformOperationException(super.message, {super.code, super.cause});
}
