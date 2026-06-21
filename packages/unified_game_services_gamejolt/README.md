# unified_game_services_gamejolt

GameJolt provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services), using
the [GameJolt Game API v1.2](https://gamejolt.com/game-api/doc) over REST. Pure
Dart, no Flutter dependency — runs anywhere, including servers and CLIs.

## Capabilities

| Capability | GameJolt API |
|------------|--------------|
| achievements | Trophies |
| leaderboards | Score tables |
| cloudSave | Data store |
| friends | Friends + Users |

GameJolt has no numeric stats or rich-presence text API, so those capabilities
are not advertised. Online presence is available as a provider-specific
[sessions](#provider-specific-sessions) API.

## Install

```yaml
dependencies:
  unified_game_services: ^1.0.0
  unified_game_services_gamejolt: ^1.0.0
```

## Credentials

You need the **game** keys and a **player** token:

- **Game ID** + **Private Key** — GameJolt dashboard → your game → *Game API*.
- **Username** + **Game Token** — the player's GameJolt profile → *Game Token*
  (not the account password).

## Usage

```dart
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';

final services = UnifiedGameServices(providers: [
  GameJoltProvider(
    gameId: '123456',
    privateKey: '••••',
    username: 'player_name',
    userToken: 'player_game_token',
  ),
]);

await services.signIn();
await services.unlockAchievement('123456');               // trophy id
await services.submitScore(leaderboardId: '654321', score: 1500);
final board = await services.getLeaderboard('654321');
```

### Provider-specific: sessions

GameJolt sessions track online presence (playing + active/idle). Reach them via
`UnifiedGameServicesPlatform.getInstance<GameJoltProvider>()` or
`services.provider<GameJoltProvider>()`:

```dart
final gj = services.provider<GameJoltProvider>()!;
await gj.startSessionHeartbeat(); // open + auto-ping under the ~120s timeout
// …play…
await gj.stopSessionHeartbeat();
```

## Examples & tooling

- [`example/interactive_login.dart`](example/interactive_login.dart) — log in
  with a real profile and test every feature from a menu.
- [`tool/smoke_test.dart`](tool/README.md) — non-interactive live check
  (`melos run gamejolt:smoke`).

See [`example/README.md`](example/README.md) for step-by-step credential setup.

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
any platform vendor. Third-party credits, trademark notices, and the Steamworks
SDK redistribution terms are in the repository's `NOTICE.md`.

