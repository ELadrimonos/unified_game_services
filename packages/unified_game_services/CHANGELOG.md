# Changelog

## 0.2.0

Core API stabilization and multi-provider enhancements.

- **Breaking:** the global instance is now `GameServices.initialize(providers: [...])` / `GameServices.instance` (+ `maybeInstance`, `reset()`). The constructor now requires a non-empty `providers` list (`ArgumentError` otherwise) and no longer falls back to `UnifiedGameServicesPlatform.instance`.
- **Breaking:** fan-out operations (`signIn`, `signOut`, `unlockAchievement`,
  `incrementAchievement`, `submitScore`, `setStat`, `incrementStat`, `saveData`,
  `setPresence`, `clearPresence`, `dispose`) now return a
  `MultiProviderOperationResult` instead of `Future<void>` (`signIn` no longer
  returns a `PlayerProfile?`; use `getCurrentPlayer()` or the per-provider
  result values). Provider failures no longer throw.
- **Breaking:** `AggregateGameServiceException` removed; per-provider errors live
  in `result.failed`.
- **Breaking:** `GameCapability.multiplayer` removed in favor of dedicated `GameCapability.lobbies` and `GameCapability.matchmaking` capabilities.
- **Centralized Mappings:** Added `UnifiedAchievementTable`, `UnifiedLeaderboardTable`, and `UnifiedStatTable` (with `ProviderIdMap` / `ProviderId`). You can now pass global mapping tables directly to `GameServices.initialize(providers: [...], achievements: ..., leaderboards: ..., stats: ...)` or `UnifiedGameServices` constructor instead of repeating `achievementIds` / `leaderboardIds` on each provider.
- **Reserved Capabilities API:** Added reserved capability enum values and API stubs for future features:
  - `invitations`: `sendInvitation()` + `InvitationReceivedEvent`
  - `lobbies`: `createLobby()`, `joinLobby()`, `leaveLobby()`
  - `matchmaking`: `startMatchmaking()`, `cancelMatchmaking()`
  - `overlays`: `showAchievementsUI()`, `showLeaderboardsUI()`, `showOverlay()`
  - `identityTokens`: `getIdentityToken()`
- New `ProviderOperationResult` / `MultiProviderOperationResult` (`succeeded`,
  `failed`, `allSucceeded`, `anySucceeded`, `allFailed`, `[providerId]`).
- **Unified ids on reads:** `Achievement.id`, `Leaderboard.id` and `Stat.key`
  are now the unified key from the mapping tables (native id when unmapped), so
  the same item read from different providers matches. The provider's own id is
  exposed, read-only, in the new `nativeIds` (`Achievement`, `Leaderboard`) /
  `nativeKeys` (`Stat`): `providerId` → native id for every provider in the
  table row, plus the provider the object came from. `nativeId` / `nativeKey`
  are shortcuts for that provider's own entry. Set by the facade.
- **Cross-provider achievements:** `getUnifiedAchievements()` merges every
  provider's achievements by unified id (`UnifiedAchievement.unlockedOn`,
  `lockedOn`, `isUnlockedOn(providerId)`, …; providers that fail land in
  `AchievementOverview.failed`), and `syncAchievements()` unlocks on every
  provider what is already unlocked on another.
- Reads (`getAchievements`, `getFriends`, `getLeaderboard`, `getStat`, `loadData`,
  `getCurrentPlayer`) tag results with the source `providerId`.
- **Breaking (re-exported models):** `dart_mappable` is gone from the models
  and events — no `toJson`/`toMap`/`fromJson`/`fromMap`/`XMapper`; see the
  `unified_game_services_platform_interface` 0.2.0 changelog.
- New capability discovery: `capabilities` and `providersFor(capability)`.
- Requires `unified_game_services_platform_interface` 0.2.0 (`providerId`).

## 0.1.0

Initial release.

- Unified, multi-provider game-services facade: achievements, leaderboards,
  stats, cloud save, profiles, rich presence and friends behind one API.
- Write operations fan out to every capable provider; reads come from the
  primary provider (or one chosen with `from:`), with per-provider failures
  aggregated into `AggregateGameServiceException`.
- Capability gating (`supports` / `supportsEverywhere`), merged event stream,
  and typed access to provider-specific APIs via `provider<T>()`.
- `dispose()` fans out to every provider to release timers, HTTP clients and
  native SDK handles.
