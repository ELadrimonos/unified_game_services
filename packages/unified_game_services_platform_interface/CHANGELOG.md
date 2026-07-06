# Changelog

## 0.1.0

Initial release.

- Shared models (dart_mappable), sealed `GameServiceEvent` hierarchy,
  `GameCapability` set, normalized `GameServiceException` types and the
  `UnifiedGameServicesPlatform` base contract every provider extends.
- Unified-key → native-id aliasing for leaderboards and achievements
  (`leaderboardIds` / `achievementIds`).
- `dispose()` lifecycle hook (default no-op) so hosts can release provider
  resources through the unified API.
