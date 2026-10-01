# Changelog

## 0.2.0

- **Breaking:** removed the global platform instance (`UnifiedGameServicesPlatform.instance`, `getInstance`, `tryGetInstance`) and `UnsupportedUnifiedGameServices`. The global now lives on the `UnifiedGameServices` facade.
- **Breaking:** `UnifiedGameServicesPlatform.providerId` is now abstract: every
  provider must return a stable `snake_case` id (never `runtimeType`).
  `UnsupportedUnifiedGameServices` uses `unsupported`. Each implementation has
  its own id (e.g. `google_play_rest` / `google_play_android`).
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
