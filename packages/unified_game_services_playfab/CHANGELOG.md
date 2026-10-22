# Changelog

## 0.2.0

- Fix: `getStat`, `setStat` and `incrementStat` now map the key through `resolveStatId`, so `UnifiedStatTable` mappings apply; `StatUpdatedEvent` carries the resolved name.
- **Breaking:** removed `PlayFabProvider.registerWith(...)`; construct the provider (`PlayFabProvider(...)`) and pass it to `GameServices.initialize(providers: [...])`.
- **Lobbies:** `GameCapability.lobbies` through the Multiplayer Lobby REST API:
  create (lobby or party), join, leave, get, find, update, member data, with
  entity-token handling (`GetEntityToken`, refreshed before it expires) and
  polling for lobby events. See the README for the REST-only limits:
  - `lobbySearchKeys` maps your data keys onto PlayFab's `string_key1..30` /
    `number_key1..30`; only mapped keys are filterable.
  - Lobbies use `UseConnections: false` and owner migration `None` (no PubSub),
    so PlayFab never reassigns ownership.
  - `invitations` is not advertised (invites need PubSub); share
    `Lobby.joinToken`, which is the connection string.
  - Members and owners are identified by entity id (`PlayFabProvider.entityId`).
  - `dispose()` leaves the lobbies it joined.
  - Not yet exercised against a live PlayFab title.
- `PlayFabClient` gains `useEntityToken` on `post`, `setEntity`, `entityToken`,
  `entityId` and `entityType`. A failed request now sets
  `PlatformOperationException.code` to PlayFab's numeric `errorCode`.
- Unsupported operations (for example achievements) now throw
  `CapabilityNotSupportedException` instead of `UnimplementedError`.
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

## 0.1.0

Initial release.

- PlayFab provider over the PlayFab Client API (pure Dart, REST): Custom ID
  login, leaderboards (statistics), player stats, cloud save (User Data) and
  profiles.
- Injectable `http.Client` for testing (`PlayFabProvider.withClient`).
