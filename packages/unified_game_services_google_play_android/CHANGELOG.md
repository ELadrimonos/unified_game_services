# Changelog

## 0.2.0

- Writes (`unlockAchievement`, `incrementAchievement`, `revealAchievement`, `setAchievementStepsAtLeast`, `submitScore`) now use the SDK's `*Immediate` variants and await their `Task`, so failures (unknown id, signed out, offline) throw `NotSignedInException`/`PlatformOperationException` instead of silently succeeding. Behavior change: no offline queueing.
- Bindings regenerated with jnigen 1.0.1 (config moved from `jnigen.yaml` to `tool/jnigen.dart`); the existing provider API is unchanged.
- `GameCapability.overlays`: `showAchievementsUI()` and `showLeaderboardsUI({leaderboardId})` open the native Play Games screens through the unified API (`GameServices.showAchievementsUI()` reaches them on Android; the REST tier has no system UI and does not advertise `overlays`). `showOverlay()` throws `PlatformOperationException`.
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
