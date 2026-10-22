import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// A subset of `EOS_EResult` codes (the SDK's universal result enum).
///
/// Values are stable across SDK versions (Epic does not renumber them). Only
/// the codes this provider distinguishes are named. [mapEosResult] turns any
/// other non-zero code into a [PlatformOperationException] carrying the raw
/// code.
abstract final class EosResult {
  /// `EOS_Success`: the operation completed.
  static const int success = 0;

  /// `EOS_NoConnection`: the SDK could not reach the EOS backend.
  static const int noConnection = 1;

  /// `EOS_InvalidCredentials`: the supplied credentials were rejected.
  static const int invalidCredentials = 2;

  /// `EOS_InvalidUser`: no user matches the credentials.
  ///
  /// A Connect login returns this, with a continuance token, for a first-time
  /// user who still has to be created.
  static const int invalidUser = 3;

  /// `EOS_InvalidAuth`: the auth token is missing or invalid.
  static const int invalidAuth = 4;

  /// `EOS_AccessDenied`: the caller is not allowed to perform the operation.
  static const int accessDenied = 5;

  /// `EOS_MissingPermissions`: the login scopes or Dev Portal permissions
  /// do not cover the operation.
  static const int missingPermissions = 6;

  /// `EOS_TooManyRequests`: the backend is rate limiting the caller.
  static const int tooManyRequests = 8;

  /// `EOS_AlreadyPending`: an equivalent operation is already in flight.
  static const int alreadyPending = 9;

  /// `EOS_InvalidParameters`: an option struct held an invalid value.
  static const int invalidParameters = 10;

  /// `EOS_NotConfigured`: the feature is not configured in the Dev Portal.
  static const int notConfigured = 14;

  /// `EOS_Canceled`: the operation was canceled before it finished.
  static const int canceled = 17;

  /// `EOS_NotFound`: the requested item does not exist.
  static const int notFound = 18;

  /// `EOS_OperationWillRetry`: the SDK failed the operation but will retry it.
  static const int operationWillRetry = 19;

  /// `EOS_TimedOut`: the operation timed out inside the SDK.
  static const int timedOut = 27;

  /// `EOS_InvalidProductUserID`: the ProductUserId is missing or invalid.
  static const int invalidProductUserId = 34;

  /// `EOS_ServiceFailure`: the EOS backend reported an internal failure.
  static const int serviceFailure = 35;

  /// `EOS_InvalidState`: the object is not in a state that allows the
  /// operation.
  static const int invalidState = 38;

  /// Whether [code] is `EOS_Success`.
  static bool isSuccess(int code) => code == success;
}

/// Maps an `EOS_EResult` [code] from operation [op] to a
/// [GameServiceException].
///
/// Returns `null` for `EOS_Success`. Connectivity, timeout, rate-limit, retry
/// and service-failure codes become [NetworkException]; credential and user
/// errors become [SignInFailedException]; [EosResult.invalidProductUserId]
/// becomes [NotSignedInException]; everything else becomes
/// [PlatformOperationException] with the raw code in `code`.
GameServiceException? mapEosResult(int code, String op) {
  switch (code) {
    case EosResult.success:
      return null;
    case EosResult.noConnection:
    case EosResult.timedOut:
    case EosResult.tooManyRequests:
    case EosResult.operationWillRetry:
    case EosResult.serviceFailure:
      return NetworkException('EOS $op: network error (code $code).');
    case EosResult.invalidCredentials:
    case EosResult.invalidAuth:
    case EosResult.invalidUser:
      return SignInFailedException('EOS $op failed: invalid credentials.');
    case EosResult.invalidProductUserId:
      return const NotSignedInException();
    case EosResult.accessDenied:
    case EosResult.missingPermissions:
      return PlatformOperationException(
        'EOS $op: access denied (code $code).',
        code: '$code',
      );
    default:
      return PlatformOperationException(
        'EOS $op failed (code $code).',
        code: '$code',
      );
  }
}

/// Throws the exception [mapEosResult] returns when [code] is not
/// `EOS_Success`.
void checkEosResult(int code, String op) {
  final ex = mapEosResult(code, op);
  if (ex != null) throw ex;
}
