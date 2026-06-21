# unified_game_services_steam

Steam provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services),
backed by the pure-Dart
[`steamworks`](https://pub.dev/packages/steamworks) FFI bindings — no Flutter
dependency.

## Capabilities

| Capability | Steam API |
|------------|-----------|
| achievements | `ISteamUserStats` (set/clear, enumerate) |
| stats | `ISteamUserStats` (int stats) |
| leaderboards | find / upload / download (async) |
| cloudSave | `ISteamRemoteStorage` |
| friends | `ISteamFriends` |
| presence | `ISteamFriends` rich presence |

## Native library — not bundled (important)

Steam is **not zero-config**, and this is inherent to Steamworks, not this
package: pub.dev ships Dart source only, and Valve's license forbids
redistributing the SDK, so the native `steam_api` library is **never delivered
with the package**. Every Steamworks integration (Unity, Godot, …) requires you
to add the native lib yourself.

### One-time dev setup

The transitive `steamworks` package bundles the official redistributables. Copy
the right one into your project and write a dev `steam_appid.txt` with:

```sh
dart run unified_game_services_steam:setup --app-id 480
```

Then make the dynamic loader find it at runtime (it does **not** search the
working directory on macOS/Linux):

| OS | What to do |
|----|------------|
| Windows | Keep `steam_api64.dll` next to the executable / run dir (searched automatically). |
| macOS | `DYLD_LIBRARY_PATH="$PWD" dart run …` or copy `libsteam_api.dylib` to `/usr/local/lib`. |
| Linux | `LD_LIBRARY_PATH="$PWD" dart run …`, copy `libsteam_api.so` to `/usr/local/lib`, or set an rpath. |

In an IDE, set the run config's **working directory** and add the
`DYLD_LIBRARY_PATH`/`LD_LIBRARY_PATH` **environment variable**.

Also: the **Steam client** must be running and logged in (the signed-in user is
the identity — Steam has no username/password login).

### Production

For a shipped build, distribute the native lib with your app (next to the
executable) under your own Steamworks agreement, and bake the app id into code
(`SteamProvider(appId: …)`, which calls `RestartAppIfNecessary`). **Do not ship
`steam_appid.txt`** — it is a development-only override.

### Cross-platform bindings

The published `steamworks` ships **Windows** bindings; the same Dart bindings
also work on macOS/Linux for the core API. If you hit ABI issues, regenerate
per-platform bindings with [`tool/README.md`](tool/README.md) and a
`dependency_overrides` entry.

## Install

```yaml
dependencies:
  unified_game_services: ^1.0.0
  unified_game_services_steam: ^1.0.0
```

## Usage

```dart
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

SteamProvider.registerWith(appId: 480); // 480 = Spacewar test app
final services = UnifiedGameServices(); // uses the registered provider

await services.signIn();
await services.unlockAchievement('ACH_WIN_ONE_GAME');
await services.submitScore(leaderboardId: 'Feet Traveled', score: 1500);
final board = await services.getLeaderboard('Feet Traveled');
```

### Steam-specific API

Beyond the unified API (reach via
`UnifiedGameServicesPlatform.getInstance<SteamProvider>()`):

- `clearAchievement(id)` — clear a single achievement.
- `resetAllStats(includeAchievements: true)` — reset for re-testing.

## Examples & tooling

- [`example/interactive_login.dart`](example/interactive_login.dart) — live
  Spacewar (480) playground.
- [`tool/generate_steamworks.dart`](tool/README.md) — regenerate bindings + copy
  the native lib (`melos run steam:gen`).

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
Valve. **Steam** and **Steamworks** are trademarks of Valve Corporation.

This provider is a thin wrapper over the BSD-3-Clause
[`steamworks`](https://github.com/aeb-dev/steamworks) FFI bindings (© 2022 Ahmet
Enes Bayraktar). It bundles **no** Valve SDK or native binary: Valve's license
forbids redistributing the Steamworks SDK, so the native library is copied out
of your local pub cache at setup time and you must ship it under your own
Steamworks agreement. Full third-party credits and trademark notices are in the
repository's `NOTICE.md`.

