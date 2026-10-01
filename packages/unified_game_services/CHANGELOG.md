# Changelog

## 0.2.0

Core API stabilization.

- **Breaking:** the global instance is now `GameServices.initialize(providers: [...])` / `GameServices.instance` (+ `maybeInstance`, `reset()`). The constructor now requires a non-empty `providers` list (`ArgumentError` otherwise) and no longer falls back to `UnifiedGameServicesPlatform.instance`.
- **Breaking:** fan-out operations (`signIn`, `signOut`, `unlockAchievement`,
  `incrementAchievement`, `submitScore`, `setStat`, `incrementStat`, `saveData`,
  `setPresence`, `clearPresence`, `dispose`) now return a
  `MultiProviderOperationResult` instead of `Future<void>` (`signIn` no longer
  returns a `PlayerProfile?`; use `getCurrentPlayer()` or the per-provider
  result values). Provider failures no longer throw.
- **Breaking:** `AggregateGameServiceException` removed; per-provider errors live
  in `result.failed`.
- New `ProviderOperationResult` / `MultiProviderOperationResult` (`succeeded`,
  `failed`, `allSucceeded`, `anySucceeded`, `allFailed`, `[providerId]`).
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
