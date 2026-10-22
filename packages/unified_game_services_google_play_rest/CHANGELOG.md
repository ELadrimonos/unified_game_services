# Changelog

## 0.2.0

- **Breaking:** removed `GooglePlayGamesProvider.registerWith(...)`; construct the provider (`GooglePlayGamesProvider(...)`) and pass it to `GameServices.initialize(providers: [...])`.
- Does not advertise `GameCapability.overlays` (a REST client cannot open system UI); `showAchievementsUI()` / `showLeaderboardsUI()` throw `CapabilityNotSupportedException`. Use the Android tier for the native screens.
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

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
