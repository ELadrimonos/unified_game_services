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

### Per-store builds (Steam-only, Epic-only, …)

Want a Steam-only build and an Epic-only build — and don't care about Google
Play in the Steam one? You don't need Flutter flavors. This is a federated
plugin: the facade only fans out to the providers you **register at runtime**, so
"Steam-only" just means "register only `SteamProvider`". A provider you never
construct never runs.

The one thing that genuinely differs per store is the **native runtime lib**.
Steam/Epic/GameCenter reach the OS over FFI, so the host ships a platform lib
(`steam_api64.dll`/`libsteam_api.dylib` + `steam_appid.txt`;
`EOSSDK-Win64-Shipping.dll`/`libEOSSDK-Mac-Shipping.dylib`). These are large,
license-gated, and not cross-redistributable — that, not the Dart code, is the
real reason to split builds. Google Play is REST (no native lib), so leaving it
out of a Steam build costs nothing: just don't register it.

Strategies, cheapest first:

1. **Runtime switch** — one binary, pick the store via `--define`:
   `dart run --define=STORE=epic example/per_store_builds.dart`. Simplest;
   unused Dart deps still ship. Fine for dev.
2. **`const bool.fromEnvironment` guards** — one entry point, but the FFI
   providers are **tree-shaken out** of builds that don't opt in. A `const` flag
   makes the branch a compile-time constant; unset → const-`false` → the
   compiler proves the provider unreachable and drops its whole `dart:ffi`
   closure:
   ```dart
   const kEnableSteam = bool.fromEnvironment('ENABLE_STEAM');
   if (kEnableSteam) providers.add(SteamProvider(appId: 480)); // only reference
   ```
   `dart compile exe … --define=ENABLE_STEAM=true` includes it; a plain
   `flutter build appbundle` (flag unset) removes it. **Reference each FFI
   provider only inside its guard** — a single reference outside re-anchors the
   symbol and defeats the shake. This is the closest thing to "automatic per-
   platform" (Dart has no OS-conditional import), verified: toggling the flags
   changed a compiled binary by ~260 KB of FFI closure.
3. **Entry points** — `bin/main_steam.dart` + `bin/main_epic.dart`, each
   importing only its provider. Dart tree-shaking drops the other's code.
   Recommended for pure-Dart/CLI targets; package the matching native lib per
   build.
4. **Flutter flavors / separate app packages** — real dependency + asset
   separation. Use when a Flutter app must bundle only one store's native lib +
   credentials per variant.

Examples: [`example/per_store_builds.dart`](example/per_store_builds.dart)
(strategy 1, doubles as a strategy-3 entry point) and
[`example/treeshake_per_store.dart`](example/treeshake_per_store.dart)
(strategy 2, single entry point + tree-shaking).

#### Steam/Epic are desktop-only

The FFI providers (Steam, Epic) run **only on desktop** (Windows/macOS/Linux) —
never mobile or web. You don't have to guard them manually:

- **Web** — each FFI package exports an **inert stub** (`if (dart.library.io)`),
  so importing it never breaks `flutter build web` / `dart compile js`;
  constructing it throws `UnsupportedError`.
- **Mobile (Android/iOS)** — `dart:ffi` compiles, but the constructor throws
  `UnsupportedError` (the native runtime lib isn't there). The native libs are
  **never auto-bundled** — nothing ships to a mobile/web build automatically.

The stub/runtime guards keep bad builds from crashing cryptically, but a runtime
gate does **not** tree-shake — the FFI **Dart** is still compiled into a mobile
bundle as dead code. Dart has no OS-conditional import to drop it automatically;
to exclude it, make the symbol unreachable at compile time with a
`const bool.fromEnvironment` guard (strategy 2 above — the closest to automatic)
or a per-platform entry point that never imports Steam/Epic (strategy 3/4).

**Respect third-party redistributables.** The Steamworks / EOS runtime libs are
license-gated and not cross-redistributable — ship each only under your own
Steam/Epic agreement, bundle it only in the matching desktop build, and **never
commit it** to source control.

## Related packages

| Package | Role |
|---------|------|
| `unified_game_services` | This package — the app-facing facade. |
| `unified_game_services_platform_interface` | Shared contract + models (for provider authors). |
| `unified_game_services_steam` | Steam provider (FFI). |
| `unified_game_services_epic` | Epic Online Services provider (FFI). |
| `unified_game_services_gamejolt` | GameJolt provider (REST). |

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
any platform vendor. Third-party credits, trademark notices, and the Steamworks
SDK redistribution terms are in the repository's `NOTICE.md`.

