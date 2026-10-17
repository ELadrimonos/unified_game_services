# Changelog

## 0.2.0

- **Breaking:** removed `GooglePlayGamesFlutter.registerWith(...)`; use `GooglePlayGamesFlutter.create(...)` and pass the result to `GameServices.initialize(providers: [...])`.
- `GameServices.showAchievementsUI()` / `showLeaderboardsUI()` (`GameCapability.overlays`) open the native Play Games screens on Android; the REST tier has no system UI and does not advertise `overlays`. (This package returns the provider for the current platform, so it needs no extra code.)
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

## 0.1.0

Initial release.

- Flutter adapter for the Google Play Games family: one call
  (`GooglePlayGamesFlutter.registerWith` / `.create`) auto-resolves the
  Android `Activity` from the running Flutter engine via `jni_flutter`.
- Off Android — including Flutter web — it delegates to the REST tier;
  builds for web verified with `flutter build web`.
