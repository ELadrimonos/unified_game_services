import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// A subset of `EOS_EResult` codes (the SDK's universal result enum).
///
/// Values are stable across SDK versions (Epic does not renumber them). Only
/// the codes this provider distinguishes are named; everything else falls
/// through to a [PlatformOperationException] carrying the raw code.
abstract final class EosResult {
  static const int success = 0;
  static const int noConnection = 1;
  static const int invalidCredentials = 2;
  static const int invalidUser = 3;
  static const int invalidAuth = 4;
  static const int accessDenied = 5;
  static const int missingPermissions = 6;
  static const int tooManyRequests = 8;
  static const int alreadyPending = 9;
  static const int invalidParameters = 10;
  static const int notConfigured = 14;
  static const int canceled = 17;
  static const int notFound = 18;
  static const int operationWillRetry = 19;
  static const int timedOut = 27;
  static const int invalidProductUserId = 34;
  static const int serviceFailure = 35;
  static const int invalidState = 38;

  static bool isSuccess(int code) => code == success;
}

/// Maps an `EOS_EResult` [code] from operation [op] onto the unified
/// [GameServiceException] hierarchy. Returns `null` for `EOS_Success`.
GameServiceException? mapEosResult(int code, String op) {
  switch (code) {
    case EosResult.success:
      return null;
    case EosResult.noConnection:
    case EosResult.timedOut:
    case EosResult.tooManyRequests:
    case EosResult.operationWillRetry:
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

/// Throws the mapped exception when [code] is not `EOS_Success`.
void checkEosResult(int code, String op) {
  final ex = mapEosResult(code, op);
  if (ex != null) throw ex;
}
