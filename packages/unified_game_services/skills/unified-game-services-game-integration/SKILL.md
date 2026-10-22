---
name: unified-game-services-game-integration
description: >-
  Use when integrating unified_game_services 0.2.0 into a game's architecture:
  where to initialize, when to sign in, calling achievements/scores/stats from
  gameplay, handling MultiProviderOperationResult failures, offline play,
  retries, events, provider-specific extras, shutdown/dispose, or testing game
  code that uses GameServices.
---

# Integrate game services into a game

Work in the consumer game. These rules keep store services from blocking,
crashing or coupling gameplay. They apply to Flutter, Flame, CLI and custom
engine hosts alike.

## 1. Put one boundary between gameplay and stores

Gameplay emits domain facts ("level 3 cleared in 41.2 s", "boss defeated");
one game-side service translates them into game-service calls. Gameplay never
imports provider packages, never calls `GameServices` directly, and never knows
which store is running.

```dart
class ProgressionService {
  ProgressionService(this._services, this._pending);
  final UnifiedGameServices _services;
  final PendingWrites _pending; // persisted, app-owned

  Future<void> onLevelCleared(int level, Duration time) async {
    await _write(
      'unlock:${AchievementIds.firstClear}',
      () => _services.unlockAchievement(AchievementIds.firstClear),
    );
    await _write(
      'score:${LeaderboardIds.speedrun}:${time.inMilliseconds}',
      () => _services.submitScore(
        leaderboardId: LeaderboardIds.speedrun,
        score: time.inMilliseconds,
      ),
    );
  }

  /// Sends an idempotent write; providers that fail are queued under [key].
  Future<void> _write(
    String key,
    Future<MultiProviderOperationResult<void>> Function() send,
  ) async {
    try {
      final result = await send();
      for (final f in result.failed) {
        await _pending.add(key, providerId: f.providerId, error: f.error);
      }
    } on CapabilityNotSupportedException {
      // Gating bug: this build has no provider for the feature. Log, don't crash.
    }
  }
}
```

Inject a `UnifiedGameServices` into this service. Use the static `GameServices`
facade only at the composition root (or in small games without DI).

## 2. Initialize once, sign in in the background

- Call `GameServices.initialize(providers: ..., achievements: ..., ...)` once,
  at startup, before the first frame or game loop tick. Provider order matters:
  the first is `primary` and the default source for reads.
- **Never block startup or the main menu on sign-in.** Start
  `signIn()` without awaiting it on the critical path; the game must be fully
  playable when every store is offline or unavailable.
- `signIn()` returns a `MultiProviderOperationResult<PlayerProfile?>`; it does not
  throw for provider failures. Show per-store status from `result.succeeded` /
  `result.failed`, not a single global "signed in" flag.
- After sign-in succeeds, flush pending writes (§4) and optionally call
  `syncAchievements()` to back-fill unlocks across the registered stores.

## 3. Gate features by capability, not by store

- `supports(cap)`: show a feature if any provider has it (writes fan out).
- `supportsEverywhere(cap)`: require it from every provider (e.g. a UI that
  promises the same data on each store).
- `providersFor(cap)`: the exact set a write will reach.
- Hide UI the build cannot serve. A fan-out with no capable provider throws
  `CapabilityNotSupportedException`; that is a bug in your gating, not a
  runtime condition to swallow.
- Reach store-only extras with `GameServices.provider<SteamProvider>()` (nullable)
  inside store-specific code, never in shared code (it re-anchors the provider;
  see the per-store builds skill).

## 4. Treat every write as fallible and handle it

Writes (`unlockAchievement`, `submitScore`, `setStat`, `incrementStat`,
`saveData`, `setPresence`, ...) return a `MultiProviderOperationResult`.
Awaiting one does **not** throw for provider errors, so an unchecked result
silently loses data.

- Inspect `result.failed`; log each `providerId` + `error` (a
  `GameServiceException`: `NotSignedIn`, `Network`, `PlatformOperation`, ...).
- Persist failed **idempotent** writes and retry after the next successful
  sign-in: unlocks (unlocking twice is harmless) and best-score submissions
  (stores keep the best according to the board's sort order).
- Never blindly retry **non-idempotent** writes: `incrementStat` and
  `incrementAchievement` would double-count. Keep the authoritative total in
  your own save and re-`setStat` the absolute value where the store replaces,
  or record the delta once with an idempotency key you track yourself.
- Retry only the failed providers: call the provider directly
  (`p.unlockAchievement(id)` for `p` in the failed set), not the fan-out, which
  would re-send to stores that already succeeded.
- `throwIfAnyFailed()` is for scripts and tests, not gameplay.

Reads (`getAchievements`, `getLeaderboard`, ...) use the primary provider (or
`from:`) and **do** throw; wrap them where UI calls them and show a retry state.
Use `*FromAll` / `getAchievementOverview()` when the UI shows several stores.

## 5. Keep calls off the hot path

- Never call game services per frame or per input. Aggregate in memory and
  write at checkpoints: level end, pause, save, quit.
- Several stores persist each stat write remotely or with rate limits (e.g.
  Steam stores stats on every `setStat`). Batch stat updates per checkpoint.
- Do not await services inside the game loop; fire from the progression
  service and let results arrive asynchronously.

## 6. Events

- Subscribe to `GameServices.events` once, from the composition root or the
  progression service. Keep the `StreamSubscription` and cancel it on shutdown.
- `GameServiceEvent` is `sealed`: `switch` exhaustively so a new event type is a
  compile error, not a silent drop.
- Use `UserSignedOutEvent` to stop writes and show offline status; use
  `JoinRequestedEvent` / `InvitationReceivedEvent` to route into lobby joins.
- Do not treat `AchievementUnlockedEvent` as proof of a successful remote write
  on every store; check the operation result.

## 7. Shut down exactly once

- One owner calls `GameServices.dispose()` (or `services.dispose()`) when the
  game exits: Flutter desktop `AppLifecycleListener(onExitRequested: ...)`, the
  engine's quit hook, or the end of `main` for CLIs. It disposes every provider
  (stops native pumps, leaves lobbies, shuts SDKs down) and returns a result.
- Flush pending writes and cancel event subscriptions **before** disposing.
- Do not dispose on pause/background; mobile and desktop games resume. Never
  reuse a disposed facade or provider.
- `GameServices.reset()` only clears the global reference; it does not
  dispose. Use it in tests.

## 8. Test game code without stores

- Inject `UnifiedGameServices(providers: [FakeProvider()])` built from a small
  `UnifiedGameServicesPlatform` subclass that records calls and can be told to
  fail (see the platform interface's custom provider skill).
- Test the failure path: a provider failing must queue the write and keep
  gameplay running.
- When code uses the static facade, call `GameServices.reset()` in `tearDown`.
- Mocks prove your wiring, not store configuration. Report live-store
  verification separately.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| `await GameServices.signIn();` before `runApp` / the first frame | Start sign-in in the background. |
| `await services.unlockAchievement(id);` and nothing else | Check `result.failed`; queue for retry. |
| Retrying `incrementStat` after a failure | Keep totals locally; never re-send deltas blindly. |
| Gameplay classes calling `GameServices` or importing providers | Route through one progression service. |
| `dispose()` on app pause, or from two places | One owner, at exit only. |
| `GameServices.reset()` as shutdown | `reset()` does not dispose; call `dispose()`. |
