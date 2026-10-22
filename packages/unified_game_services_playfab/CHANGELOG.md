# Changelog

## 0.2.0

- Fix: `getStat`, `setStat` and `incrementStat` now map the key through `resolveStatId`, so `UnifiedStatTable` mappings apply; `StatUpdatedEvent` carries the resolved name.
- **Breaking:** removed `PlayFabProvider.registerWith(...)`; construct the provider (`PlayFabProvider(...)`) and pass it to `GameServices.initialize(providers: [...])`.
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

## 0.1.0

Initial release.

- PlayFab provider over the PlayFab Client API (pure Dart, REST): Custom ID
  login, leaderboards (statistics), player stats, cloud save (User Data) and
  profiles.
- Injectable `http.Client` for testing (`PlayFabProvider.withClient`).
