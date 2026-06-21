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

## Requirements

Steam integration needs native bits the integrating app provides:

- The **Steam client** running and logged in (the signed-in user is the identity
  — Steam has no username/password login).
- The **Steamworks redistributable** next to your executable:
  `steam_api64.dll` (Windows), `libsteam_api.so` (Linux), or
  `libsteam_api.dylib` (macOS).
- A **`steam_appid.txt`** with your app id (or pass `appId`).

> The published `steamworks` ships **Windows** bindings. For Linux/macOS,
> regenerate them with the bundled tool — see
> [`tool/README.md`](tool/README.md) — and add a `dependency_overrides` entry.

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

See the repository for license details.
