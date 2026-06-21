# unified_game_services

One Dart API for game services — achievements, leaderboards, stats, cloud save,
profiles and presence — across many providers (Steam, GameJolt, and your own
custom backends), with **no dependency on Flutter**.

Write your integration once and publish to several platforms at the same time.
Pure Dart, so it runs in Flutter apps, CLIs, servers and game engines alike.

## Features

- 🎮 Unified API: achievements, leaderboards, stats, cloud save, friends, presence.
- 🔌 Pluggable providers — target several at once.
- 🧩 Multi-provider fan-out: one `submitScore` writes to every capable provider.
- 🛠️ Bring your own backend (Supabase, Firebase, REST…) as a custom provider.
- 🪶 Pure Dart — no Flutter dependency.
- 🧪 Capability-gated, with a typed error hierarchy and an event stream.

## Install

```yaml
dependencies:
  unified_game_services: ^1.0.0
  # plus the provider(s) you need:
  unified_game_services_steam: ^1.0.0
  unified_game_services_gamejolt: ^1.0.0
```

This package re-exports the shared models, capabilities, events and exceptions,
so a single `import` is enough.

> **Provider setup differs.** Pure-REST providers like GameJolt are zero-config
> (just credentials). Native providers like Steam need a one-time native-library
> setup that pub.dev cannot deliver for you (Valve's SDK can't be redistributed)
> — run `dart run unified_game_services_steam:setup` and see the
> [Steam package README](https://pub.dev/packages/unified_game_services_steam).

## Usage

```dart
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';
import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';

final services = UnifiedGameServices(providers: [
  SteamProvider(appId: 480),
  GameJoltProvider(
    gameId: '…', privateKey: '…', username: '…', userToken: '…',
  ),
]);

await services.signIn();

// Writes fan out to every provider that supports the capability:
if (services.supports(GameCapability.achievements)) {
  await services.unlockAchievement('first_win'); // Steam + GameJolt
}
await services.submitScore(leaderboardId: 'global', score: 1500);

// Reads come from the primary provider (the first one), or pick with `from:`:
final achievements = await services.getAchievements();
final board = await services.getLeaderboard('global');

// Listen to events from all providers:
services.events.listen(print);
```

Single-provider mode: call `UnifiedGameServices()` with no arguments to use the
provider registered via `UnifiedGameServicesPlatform.instance`.

### Capabilities

Each provider advertises what it supports; gate calls with `supports`:

```dart
if (services.supports(GameCapability.cloudSave)) {
  await services.saveData('profile', bytes);
}
```

`GameCapability` covers `achievements`, `leaderboards`, `stats`, `cloudSave`,
`friends`, `presence`, `multiplayer`. A fan-out to a capability no provider
supports throws `CapabilityNotSupportedException`; partial failures throw
`AggregateGameServiceException`.

### Provider-specific features

Some providers expose extras beyond the unified API. Reach them with the typed
accessor:

```dart
final gj = services.provider<GameJoltProvider>();
await gj?.startSessionHeartbeat();
```

### Custom providers

Back the API with your own database/service by extending
`UnifiedGameServicesPlatform`. See
[`example/custom_provider.dart`](example/custom_provider.dart) for a complete
template (illustrated with Supabase).

## Related packages

| Package | Role |
|---------|------|
| `unified_game_services` | This package — the app-facing facade. |
| `unified_game_services_platform_interface` | Shared contract + models (for provider authors). |
| `unified_game_services_steam` | Steam provider (FFI). |
| `unified_game_services_gamejolt` | GameJolt provider (REST). |

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
any platform vendor. Third-party credits, trademark notices, and the Steamworks
SDK redistribution terms are in the repository's `NOTICE.md`.

