/// How the provider obtains an OAuth 2.0 access token for the Games REST API.
///
/// The provider never performs OAuth mechanics itself — it holds an
/// [AuthStrategy] and asks it for a bearer token, refreshing on demand. This
/// keeps the data plane (REST) identical across platforms while the way a token
/// is acquired varies: a browser loopback flow on desktop/CLI, a stored
/// refresh token on a server, or a native silent token brokered by the host on
/// Android.
///
/// Implementations must map their own failures onto the
/// [GameServiceException] hierarchy — typically [SignInFailedException] when an
/// interactive sign-in fails or is cancelled, and [NotSignedInException] when a
/// token cannot be produced without interaction.
abstract interface class AuthStrategy {
  /// Returns a valid access token, performing or refreshing sign-in as needed.
  ///
  /// When [forceRefresh] is `true` the strategy must discard any cached token
  /// and obtain a fresh one (the REST client calls this once after a `401`).
  Future<String> getAccessToken({bool forceRefresh = false});

  /// Whether a token is currently held (no network call).
  bool get isAuthenticated;

  /// Drops any cached credentials. Interactive strategies should require a new
  /// sign-in afterwards.
  Future<void> signOut();
}
