# Steam examples

## Real integration playground (Spacewar / appId 480)

`interactive_login.dart` initializes Steam with the public **Spacewar** test app
(appId `480`) and lets you exercise achievements, scores, leaderboards and
friends against the real Steam backend from a menu.

```sh
dart run example/interactive_login.dart
```

> Steam has **no username/password login**. The identity is whoever is signed
> into the running Steam client; `signIn()` just warms that player's stats and
> returns their profile.

## Requirements

1. **Steam client running** and logged in.
2. **Steamworks native library** beside the executable for your OS:
   `steam_api64.dll` (Windows), `libsteam_api.so` (Linux) or
   `libsteam_api.dylib` (macOS). The easiest way to get it (and the per-platform
   bindings) is:
   ```sh
   melos run steam:gen -- --sdk /path/to/steamworks_sdk
   ```
   which copies the lib into `example/` and writes `steam_appid.txt`. You can
   also copy the lib manually from the Steamworks SDK
   (`redistributable_bin/<platform>/`).
3. **`steam_appid.txt`** containing `480` in the working directory (the gen tool
   writes this; otherwise create it yourself).

The published `steamworks` package ships Windows bindings; Linux/macOS need the
regenerated bindings + a `dependency_overrides` entry — see
[`../tool/README.md`](../tool/README.md).

## Spacewar test content

| Kind | Ids |
|------|-----|
| Achievements | `ACH_WIN_ONE_GAME`, `ACH_WIN_100_GAMES`, `ACH_TRAVEL_FAR_ACCUM`, `ACH_TRAVEL_FAR_SINGLE` |
| Leaderboards | `Feet Traveled`, `Quickest Win` |

Use menu option **7** (reset all stats + achievements) to start fresh between
runs. Reference: <https://partner.steamgames.com/doc/sdk/api/example>.
