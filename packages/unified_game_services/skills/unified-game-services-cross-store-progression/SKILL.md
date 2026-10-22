---
name: unified-game-services-cross-store-progression
description: >-
  Use when designing achievements, stats or leaderboards for a game that ships on
  several stores with unified_game_services 0.2.0, defining UnifiedAchievementTable,
  UnifiedStatTable or UnifiedLeaderboardTable / ProviderIdMap, adding incremental
  or progress achievements, choosing score units, or debugging ids, stats or
  scores that behave differently per store.
---

# Design progression that works on every store

Each store has its own dashboard, id format and semantics. Design progression
once in your game's terms, then map it per store. Configure dashboards and code
together; neither is correct alone.

## 1. One id source of truth

- Pick stable unified keys in `snake_case` (`first_win`, `speedrun_any`).
  Never rename or reuse a shipped key; retire it instead.
- Declare keys as constants and all three tables in one file; gameplay code uses
  the constants only.

```dart
abstract final class AchievementIds {
  static const firstWin = 'first_win';
  static const collector = 'collector';
  static const all = [firstWin, collector];
}

final kAchievements = UnifiedAchievementTable({
  AchievementIds.firstWin: ProviderIdMap(
    steam: 'ACH_WIN_ONE_GAME',
    epic: 'first_win',
    googlePlay: 'CgkI123456789EAIQAQ', // covers both REST and Android tiers
    gameCenter: 'com.studio.game.first_win',
    gameJolt: '123456',
  ),
  // ...
});
```

- `googlePlay` is the fallback for `googlePlayRest` and `googlePlayAndroid`; set
  a tier-specific key only when they differ. Custom providers go in
  `custom: {'my_backend': '...'}` keyed by their `providerId`.
- **Unmapped ids pass through unchanged.** A missing row or typo is not caught;
  the store rejects or ignores the native id at runtime. Add a unit test that
  every key has an entry for every provider each build ships:

```dart
test('every achievement is mapped for every shipped store', () {
  for (final key in AchievementIds.all) {
    for (final store in ['steam', 'epic', 'google_play', 'game_center']) {
      expect(kAchievements.mappings[key], contains(store), reason: '$key/$store');
    }
  }
});
```

- Pass tables to `GameServices.initialize` / `UnifiedGameServices`, not to
  provider constructors. Reads come back with the unified `id` and the original
  in `nativeId`.

## 2. Know what each store can do

Summary for design decisions. The full per-method behavior of each provider
(throws, no-ops, ignored scopes, sign-in semantics) is in the
`unified-game-services-provider-behaviors` skill.

| Provider | Achievements | Progress (`incrementAchievement`) | Stats | Leaderboards |
| --- | --- | --- | --- | --- |
| Steam | yes | throws; drive a backing stat | int32; `setStat` replaces | yes |
| Epic (EOS) | yes | throws; drive a backing stat | int; `setStat` **ingests** per aggregation | yes, backed by a stat |
| Google Play | yes | native steps | none | yes |
| Game Center | yes | steps = **percentage points** | none | yes |
| GameJolt | yes (trophies) | throws; all-or-nothing | none | yes (score tables) |
| PlayFab | none | none | yes | yes |

Consequences:

- The only portable achievement operation is `unlockAchievement`. Design every
  achievement so it is correct as an unlock.
- The same `incrementAchievement(id, 5)` means 5 steps on Google Play and 5 % on
  Game Center, and fails on Steam/Epic/GameJolt. Never fan it out with one number.
- Stores without stats cannot hold your progress: the **authoritative progress
  lives in your own save** (local + cloud save or your backend), never only in a
  store.

## 3. Progress achievements ("collect 100 coins")

1. Keep the counter in your save.
2. When it crosses the threshold, call `unlockAchievement(id)`; that works
   everywhere and is idempotent.
3. Optionally mirror progress for store-native progress bars, per provider with
   converted units:
   - Steam: stat-backed achievement configured in Steamworks; write the
     absolute counter with `setStat`.
   - Epic: achievement unlocked by a stat threshold in the Dev Portal; ingest
     only the delta since last checkpoint with `incrementStat` (or `setStat`,
     which also adds).
   - Google Play: `incrementAchievement` with native steps on that provider.
   - Game Center: `incrementAchievement` with percentage points.
   Call those through the specific provider, not the fan-out.
4. On sign-in, re-send unlocks for every threshold already crossed in the save,
   then `syncAchievements()` to copy unlocks between registered stores.

## 4. Stats

- Integers only. Steam and Epic truncate `num` to an integer; store times in
  milliseconds, distances in centimetres, etc.
- `setStat` does not mean the same thing everywhere: Steam **replaces** the value,
  Epic **adds** it according to the stat's aggregation (SUM/MAX/MIN/LATEST).
  Pick per stat:
  - Counter (kills, coins earned): `incrementStat(key, by: delta)` once per
    checkpoint; Epic aggregation SUM. Non-idempotent: never retry blindly.
  - Best value (max combo): `setStat` only when the value improves; Epic
    aggregation MAX, Steam replaces. Never send a lower value.
  - Never use stats for values that can decrease on Epic.
- Steam `incrementStat` is a non-atomic read-modify-write; do not call it
  concurrently for the same key.

## 5. Leaderboards

- Scores are `int`. Use one unit for every store (ms for times), and configure
  each board's sort order (ascending for times, descending for points) and
  display format identically in every dashboard. The library cannot fix a
  mismatched sort order.
- Epic boards rank an aggregated stat: the Epic id in the table is the **stat
  name**, and the board's aggregation decides what the submit does.
- Stores keep the best score per their sort order; submitting a worse score is
  harmless. Use `formattedScore`/`displayScore` for UI.
- One unified key per board concept; do not encode store-specific variants into
  keys.

## 6. Dashboard parity checklist

For every key, on every store the game ships to:

- [ ] Achievement / stat / board exists with the mapped native id.
- [ ] Hidden flag, icon, localized name/description and unlock rule match.
- [ ] Stat type is integer and aggregation matches its usage (Epic).
- [ ] Board sort order and units match.
- [ ] Published or released to testers (Steamworks publish, Play Console
  testers, Epic sandbox/deployment, App Store Connect).
- [ ] Verified live by reading back with `getAchievementOverview()` /
  `getLeaderboardFromAll(id)` using test accounts. Report stores that were not
  verified live.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| Using native ids (`ACH_WIN_ONE_GAME`) in gameplay | Unified constants + tables. |
| A store missing from a row, no test | Mapping-completeness test per shipped store. |
| `incrementAchievement` fanned out with one number | Unlock at threshold; per-provider increments with converted units. |
| `setStat(total)` on Epic | Epic adds; ingest deltas or use MAX aggregation. |
| Float stats / seconds as `double` scores | Integers in the smallest unit. |
| Progress stored only in a store | Your save is the source of truth. |
