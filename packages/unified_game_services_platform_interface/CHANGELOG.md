# Changelog

## 0.2.0

- Fix: `ProviderIdMap(googlePlay: ...)` entries were never applied, because no provider reports `google_play`. `UnifiedIdTable.forProvider` / `reverseForProvider` now fall back to the `google_play` entry for `google_play_rest` and `google_play_android`; a tier-specific entry still wins.
- **Breaking:** removed the global platform instance (`UnifiedGameServicesPlatform.instance`, `getInstance`, `tryGetInstance`) and `UnsupportedUnifiedGameServices`. The global now lives on the `UnifiedGameServices` facade.
- **Breaking:** `UnifiedGameServicesPlatform.providerId` is now abstract: every
  provider must return a stable `snake_case` id (never `runtimeType`).
  `UnsupportedUnifiedGameServices` uses `unsupported`. Each implementation has
  its own id (e.g. `google_play_rest` / `google_play_android`).
- **Breaking:** `GameCapability.multiplayer` removed in favor of `GameCapability.lobbies` and `GameCapability.matchmaking`.
- `Achievement.nativeIds`, `Leaderboard.nativeIds`, `Stat.nativeKeys`: read-only `providerId` → native id maps, set by the facade (`nativeId` / `nativeKey` getters give the source provider's own); `id`/`key` are the unified one. `UnifiedIdTable.nativeIdsFor` and `reverseForProvider` expose the table row and the native → unified inverse.
- **New Tables:** Added `UnifiedIdTable`, `UnifiedAchievementTable`, `UnifiedLeaderboardTable`, `UnifiedStatTable`, `ProviderId`, and `ProviderIdMap` for central ID mapping resolution.
- Added `statIds`, `resolveStatId()`, and `registerMappings()` to `UnifiedGameServicesPlatform`.
- Added reserved capability API stubs to `UnifiedGameServicesPlatform` (`sendInvitation`, `createLobby`, `joinLobby`, `leaveLobby`, `startMatchmaking`, `cancelMatchmaking`, `showAchievementsUI`, `showLeaderboardsUI`, `showOverlay`, `getIdentityToken`).
- Added `InvitationReceivedEvent` to the `GameServiceEvent` hierarchy.
- **Breaking:** `dart_mappable` removed. Models and events are now hand-written
  immutable classes with `copyWith`, `==` (deep for lists/maps), `hashCode` and
  `toString`. Gone: `toJson`/`toMap`/`fromJson`/`fromMap`, all `XMapper`,
  `XMappable`, `XCopyWith` and `XValueCopy` types, and the `type`
  discriminator of events. `copyWith` keeps the current value for a `null`
  argument (it cannot reset a field to `null`). No `build_runner` needed.
- `PlayerProfile`, `Achievement`, `Stat`, `Leaderboard` and `CloudSaveMetadata`
  gain an optional `providerId` (stamped by the facade; providers leave it null).

## 0.1.0

Initial release.

- Shared models (dart_mappable), sealed `GameServiceEvent` hierarchy,
  `GameCapability` set, normalized `GameServiceException` types and the
  `UnifiedGameServicesPlatform` base contract every provider extends.
- Unified-key → native-id aliasing for leaderboards and achievements
  (`leaderboardIds` / `achievementIds`).
- `dispose()` lifecycle hook (default no-op) so hosts can release provider
  resources through the unified API.
