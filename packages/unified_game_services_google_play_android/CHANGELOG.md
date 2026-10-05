# Changelog

## 0.2.0

- Bindings regenerated with jnigen 1.0.1 (config moved from `jnigen.yaml` to `tool/jnigen.dart`); the existing provider API is unchanged.
- Added provider-specific `showAchievementsUi()` and `showLeaderboardsUi({leaderboardId})`, opening the native Play Games screens.
- **Breaking:** removed `GooglePlayAndroidProvider.registerWith(...)`; construct the provider (`GooglePlayAndroidProvider(...)`) and pass it to `GameServices.initialize(providers: [...])`.
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

## 0.1.0

Initial release.

- Native Google Play Games provider via the Play Games v2 Java SDK over
  `package:jni` (pure Dart, no Flutter). Android only.
- Writes (`unlock`/`increment`/`reveal`/`submitScore`) go through the
  on-device client and fire the native toasts/overlay; runtime-verified on a
  Flutter Android host.
- Reads are pending a jnigen `Task<T>` fix and throw
  `CapabilityNotSupportedException` pointing at the REST provider.
