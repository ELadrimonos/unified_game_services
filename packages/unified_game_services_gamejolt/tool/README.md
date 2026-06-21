# GameJolt dev tooling

## `smoke_test.dart`

Live end-to-end check against the real GameJolt Game API — useful to confirm
credentials and the provider mapping outside of the mocked unit tests.

### Credentials (env vars)

| Var | Where to find it |
|-----|------------------|
| `GAMEJOLT_GAME_ID` | GameJolt dashboard → your game → Game API |
| `GAMEJOLT_PRIVATE_KEY` | same page (keep secret) |
| `GAMEJOLT_USERNAME` | a player's GameJolt username |
| `GAMEJOLT_USER_TOKEN` | that player's Game Token (profile → Game Token) |

### Run

```sh
export GAMEJOLT_GAME_ID=... GAMEJOLT_PRIVATE_KEY=... \
       GAMEJOLT_USERNAME=... GAMEJOLT_USER_TOKEN=...

# read-only: auth, profile, achievements, friends
dart run tool/smoke_test.dart

# opt-in side effects
dart run tool/smoke_test.dart --leaderboard 654321          # read-only fetch
dart run tool/smoke_test.dart --cloud --session             # WRITE: data store + session
dart run tool/smoke_test.dart --unlock 123456 --score 654321 1500  # WRITE

# or from the repo root
melos run gamejolt:smoke -- --cloud --session
```

Read-only by default. `--unlock`, `--score` and `--cloud` perform real writes
(unlock a trophy, submit a score, write/delete a data-store key `ugs_smoke_test`).
Exits non-zero if any step fails.
