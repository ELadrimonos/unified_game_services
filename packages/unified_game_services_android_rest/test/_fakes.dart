import 'package:unified_game_services_android_rest/unified_game_services_android_rest.dart';

/// A deterministic [AuthStrategy] for tests.
///
/// Returns [token] normally and [refreshedToken] after a forced refresh,
/// counting how many times each happened.
class FakeAuthStrategy implements AuthStrategy {
  FakeAuthStrategy({this.token = 'tok', this.refreshedToken = 'tok2'});

  final String token;
  final String refreshedToken;

  int calls = 0;
  int refreshes = 0;
  bool signedOut = false;

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    calls++;
    if (forceRefresh) {
      refreshes++;
      return refreshedToken;
    }
    return token;
  }

  @override
  bool get isAuthenticated => !signedOut;

  @override
  Future<void> signOut() async => signedOut = true;
}
