# Changelog

## 0.2.0

- **Breaking:** removed `PlayFabProvider.registerWith(...)`; construct the provider (`PlayFabProvider(...)`) and pass it to `GameServices.initialize(providers: [...])`.
- **Lobbies:** `GameCapability.lobbies` via the Multiplayer Lobby REST API (create, join, leave, get, find, update, member data), entity-token handling, `lobbySearchKeys`, polling events. See the README for the REST-only limits.
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

## 0.1.0

Initial release.

- PlayFab provider over the PlayFab Client API (pure Dart, REST): Custom ID
  login, leaderboards (statistics), player stats, cloud save (User Data) and
  profiles.
- Injectable `http.Client` for testing (`PlayFabProvider.withClient`).
