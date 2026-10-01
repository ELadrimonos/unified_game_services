# Changelog

## 0.2.0

- **Breaking:** removed `GameJoltProvider.registerWith(...)`; construct the provider (`GameJoltProvider(...)`) and pass it to `GameServices.initialize(providers: [...])`.
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

## 0.1.0

Initial release.

- GameJolt provider over the Game API v1.2 (pure Dart, REST) — trophies as
  achievements, scoreboards as leaderboards, data store, user profiles.
- GameJolt-specific session API (`openSession`, `startSessionHeartbeat`,
  `closeSession`) kept off the unified interface by design.
- Signed requests (md5), injectable `http.Client` for testing
  (`GameJoltProvider.withClient`).
