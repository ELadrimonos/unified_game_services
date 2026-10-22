---
name: unified-game-services-provider-behaviors
description: >-
  Use when a unified_game_services 0.2.0 facade call behaves differently per
  provider (Steam, Epic, Game Center, Google Play REST/Android, GameJolt,
  PlayFab): a write that adds instead of replacing, a call that throws or does
  nothing on one store, sign-in/sign-out/isSignedIn meaning different things,
  missing leaderboard or player data, ignored time scopes, or deciding whether
  one facade call is safe to fan out across stores.
---

# Know what each provider really does behind the facade

The facade gives every provider the same method names, not the same semantics.
Before relying on a fan-out, check the row for every provider the build
registers. This is a reference; it does not replace each provider's setup skill.

`supports(cap)` means the provider advertises the capability, **not** that every
method of that capability works. Rows marked *throws* raise
`CapabilityNotSupportedException` (or the noted exception); in a fan-out they show
up in `result.failed`, and in a single-provider read they propagate.

## 1. Session

| Provider | `signIn()` | `signOut()` | `isSignedIn()` means |
| --- | --- | --- | --- |
| Steam | Inits the SDK, loads stats (10 s). `SteamRestartRequiredException` if not launched via Steam. | **throws** `PlatformOperationException` (sign out in the client) | SDK initialized locally |
| Epic | Device ID (anonymous), Dev Auth Tool or Launcher exchange code; 30 s timeout | Local only; no `EOS_Auth_Logout` | Local session |
| Game Center | **throws** `SignInFailedException` if GameKit must show its UI; the host must authenticate first | — | GameKit's live state |
| Google Play Android | Shows the native sign-in UI; returns id + display name (no avatar), `null` if the profile read failed | **throws** `PlatformOperationException` (no sign-out in v2) | Live Play Services query |
| Google Play REST | Runs the `AuthStrategy` (may be interactive) | Drops local token; not revoked | Token held, may be expired |
| GameJolt | Verifies username + game token | Local flag only | Local flag |
| PlayFab | `LoginWithCustomID` (creates account by default) | Drops ticket; not invalidated | Ticket held |

- Never treat `signIn()`'s profile as available everywhere; read
  `getCurrentPlayer()` per provider. Avatars are missing on Epic and Google
  Play Android (`avatarUrl` is `null`).
- Profile `id` formats differ: steamID64, Epic ProductUserId (Connect),
  `gamePlayerID`, Play player id, GameJolt numeric id, PlayFab id. Never compare
  ids across providers; use them only with their `providerId`.
- An Epic **anonymous Device ID** login has no Epic account: friends, presence
  and cloud save throw. Use exchange code (Launcher) or Dev Auth in production.

## 2. Achievements

| Provider | `unlock` | `incrementAchievement(id, n)` | `reveal` | Read path |
| --- | --- | --- | --- | --- |
| Steam | API name; fails if stats not loaded | **throws**; drive the backing stat | no-op (revealed on unlock) | no progress reported |
| Epic | Portal id | **throws** `PlatformOperationException`; ingest backing stat | no-op (revealed on unlock) | definitions + progress |
| Game Center | reports 100 %, system banner | adds `n` **percentage points** (non-atomic read+write) | reports 0 % | progress as steps/100 |
| Google Play REST | ok | adds `n` **native steps**, idempotent `requestId` | ok | definitions + progress |
| Google Play Android | `unlockImmediate`, native toast; **fails offline** (no queue) | native steps | ok | definitions + progress |
| GameJolt | numeric trophy id | **throws** (all-or-nothing) | no-op | no hidden flag, no progress |
| PlayFab | — not advertised — | | | |

- Only `unlockAchievement` is portable. Never fan out `incrementAchievement`:
  the same `n` means steps, percent, or an error.
- `revealAchievement` is a no-op on Steam, Epic and GameJolt: hidden
  achievements there appear only once unlocked.
- Provider-only helpers: `GooglePlayGamesProvider` /
  `GooglePlayAndroidProvider.setAchievementStepsAtLeast` (idempotent, never
  decreases); `SteamProvider.clearAchievement` / `resetAllStats` (testing only).

## 3. Stats

| Provider | `setStat(k, v)` | `incrementStat(k, by)` | `getStats()` |
| --- | --- | --- | --- |
| Steam | **replaces**, int32, stores remotely each call | read + write, non-atomic | only stats in the `UnifiedStatTable` (Steam cannot enumerate); empty without one |
| Epic | **adds** (`EOS_Stats_IngestStat`, per Portal aggregation) | same as `setStat` | raw EOS names |
| PlayFab | writes; result follows the statistic's aggregation | read + write, non-atomic | ok |
| Game Center, Google Play, GameJolt | — not advertised — | | |

- All truncate to integers.
- A fan-out `setStat('best', 50)` sets 50 on Steam but adds 50 on Epic. Use
  `incrementStat` for counters, and `setStat` only for MAX-style stats you send
  when the value improves.
- Google Play "events" (`recordEvent`) are increment-only counters on the REST
  provider only, not unified stats.

## 4. Leaderboards

| Provider | `submitScore` | `getLeaderboard` scope/collection | `getPlayerScore` |
| --- | --- | --- | --- |
| Steam | keep-best, board name | friends works; `timeScope` echoed only | ok at any rank |
| Epic | ingests into the backing **stat**; aggregation decides | both echoed only; always global | looked up by user id in the ranks EOS returns; `null` below them |
| Game Center | ok | both honored (today/week/all-time, friends) | ok at any rank |
| Google Play REST | keep-best per sort order | both honored; `maxResults` clamped to 1–30 | ok |
| Google Play Android | `submitScoreImmediate`, fails offline | both honored; `maxResults` clamped to 1–25 | ok at any rank |
| GameJolt | adds an entry to table id (numeric) | both echoed only; guests appear as `guest` | best score + global rank (2 requests) |
| PlayFab | writes the backing statistic | both echoed only; global | one-entry window; **may return a neighbour** if the player is absent |

- If the UI offers "weekly" or "friends" tabs, gate them per provider; most
  stores silently return the global all-time board.
- Check `Leaderboard.timeScope`/`collection` only as an echo of the request,
  not as proof the store filtered.

## 5. Cloud save

| Provider | Storage | Notes |
| --- | --- | --- |
| Steam | Steam Cloud file per slot | fails if Cloud is disabled for app/user; metadata = slot + size |
| Epic | Player Data Storage | needs Epic account login **and** `encryptionKey`; one transfer per file at a time |
| GameJolt | data store, base64 | `loadData` returns `null` on **any** error, not only "missing"; no sizes |
| PlayFab | user data, base64 | no sizes |
| Game Center, Google Play | — not advertised — | |

- Never treat `loadData == null` as "new player" on GameJolt: it may be a
  network error. Keep a local copy and a version in the payload.
- Fan-out `saveData` writes to every cloud-save provider; on load, pick one
  source (`from:`) or compare with `loadDataFromAll`.

## 6. Presence, friends, identity, overlays, lobbies

- **Presence**: Steam sends only `state`; Epic sends `state — details`
  (255 chars max, needs Epic account login); party size and `startedAt` are
  dropped by both. GameJolt "sessions" are a provider extra, not presence.
- **Friends**: Steam (regular friends), Epic (Epic account login only),
  GameJolt (2 requests), PlayFab. Not on Game Center or Google Play.
- **Identity tokens**: Steam = Web API ticket hex, valid ~2 min, verify with
  `AuthenticateUserTicket`; Epic = Connect ID token (JWT), verify against Epic's
  JWKS. Branch on `providerId` on the backend.
- **Overlays**: only Google Play Android (`showAchievementsUI`,
  `showLeaderboardsUI`); `showOverlay` throws there too.
- **Lobbies** never fan out. Steam searches public lobbies only; PlayFab needs
  `lobbySearchKeys`, polls for changes and has no owner migration.

## 7. Lifecycle

- `dispose()`: Steam shuts the API down; Epic releases the platform; REST
  providers close their HTTP client (even an injected one). GameJolt does not
  close an open session on the server: call `stopSessionHeartbeat()` first.
- Providers are not reusable after `dispose()`.

## How to apply

1. List the providers each build registers.
2. For every facade call the game makes, read its row for each of them.
3. Where semantics differ, call the provider directly
   (`GameServices.provider<T>()` in store-specific code) instead of fanning out,
   or gate the feature with `providersFor(cap)` plus a per-provider check.
4. Treat expected failures (`signOut` on Steam and Google Play Android, `incrementAchievement` on
   Steam/Epic/GameJolt) as known and skip them, rather than logging them as
   errors every time.
