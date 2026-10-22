# Changelog

## 0.2.0

- Ship a Game Center setup agent skill and update the README to use facade ID tables and operation results.
- **Breaking:** removed `GameCenterProvider.registerWith(...)`; construct the provider (`GameCenterProvider(...)`) and pass it to `GameServices.initialize(providers: [...])`.
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

## 0.1.0

Initial release.

- Apple Game Center provider backed by GameKit through pure-Dart Objective-C
  FFI (`package:objective_c`) — no Flutter dependency. macOS and iOS only.
- Authentication, achievements (read/unlock/progress) and leaderboards
  (submit + paged reads with time scope / collection).
- Defensive timeouts on all GameKit completions (30s reads, 60s sign-in) with
  a clear error when the host's main run loop is not being pumped.
- Committed ffigen bindings; regenerate with `tool/regenerate_bindings.sh`
  (macOS + Xcode).
