# Changelog

## 0.1.0

Initial release.

- Google Play Games provider over the REST Games API v1 (pure Dart, no
  Flutter): achievements and leaderboards.
- Pluggable `AuthStrategy`: `LoopbackOAuthStrategy` (auth-code + PKCE +
  127.0.0.1 loopback for desktop/CLI), `StoredCredentialStrategy`
  (refresh/brokered tokens) and `NativeSilentTokenStrategy` (host-brokered
  silent tokens). Single automatic refresh-and-retry on 401.
- Loopback server ignores unrelated requests (e.g. `/favicon.ico`) instead of
  aborting the sign-in.
- Injectable `http.Client` for testing
  (`GooglePlayGamesProvider.withClient`).
