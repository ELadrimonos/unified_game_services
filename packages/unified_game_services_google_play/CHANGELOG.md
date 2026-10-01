# Changelog

## 0.2.0

- **Breaking:** removed `GooglePlayGames.registerWith(...)`; use `GooglePlayGames.create(...)` and pass the result to `GameServices.initialize(providers: [...])`.
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

## 0.1.0

Initial release.

- Auto-selecting Google Play Games factory: native Play Games v2 SDK on
  Android, REST elsewhere — including web (`package:jni` stays behind a
  `dart.library.io` conditional import so the facade compiles to JS).
- `activityResolver` typed `Object Function()` so the public API carries no
  `jni` types; resolved fresh before each native call.
