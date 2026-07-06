# Changelog

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
