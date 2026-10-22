# Unified Game Services

A multi-platform abstraction layer for game services — achievements,
leaderboards, stats, cloud save, player profiles, friends and rich presence —
behind a single Dart API.

> **Pure Dart, no Flutter.** No package here depends on Flutter (`plugin_platform_interface`
> is fine — it's pure Dart itself). One sanctioned exception:
> `unified_game_services_google_play_flutter`, a Flutter-only adapter for
> plug-and-play Activity resolution. Everything else runs in plain Dart apps,
> CLIs, servers, and custom game engines — Flutter included, but never required.

Start with the app-facing facade:
[`packages/unified_game_services`](packages/unified_game_services) — its
README covers install, usage, per-store builds, and Flutter desktop flavors.

## Packages

| Package | What it is | Status |
|---|---|---|
| `unified_game_services` | App-facing facade — multi-provider fan-out | ✅ |
| `unified_game_services_platform_interface` | Shared contract + models (for provider authors) | ✅ |
| `unified_game_services_steam` | Steam (Steamworks via FFI), desktop only | ✅ runtime-verified (macOS; lobbies, invitations and identity ticket on Linux) |
| `unified_game_services_epic` | Epic Online Services (EOS C SDK via FFI), desktop only | ✅ runtime-verified (macOS); leaderboard `getPlayerScore` scans top-100 only |
| `unified_game_services_game_center` | Apple Game Center (GameKit via Objective-C FFI), macOS/iOS | ⚠️ implemented, not yet runtime-verified (needs a paid Apple Developer account + Game Center–enabled App Store Connect record) |
| `unified_game_services_gamejolt` | GameJolt (REST Game API v1.2) | ✅ verified with tests + live |
| `unified_game_services_playfab` | PlayFab (REST Client + Multiplayer Lobby API) | ✅ verified with tests; lobbies not yet tried against a live title |
| `unified_game_services_google_play_rest` | Google Play Games via REST — cross-platform, achievements + leaderboards only | ✅ verified with tests |
| `unified_game_services_google_play_android` | Google Play Games via the on-device Play Games v2 Java SDK (JNI), Android only | ✅ writes verified on-device; reads blocked on a jnigen `Task<T>` generics bug |
| `unified_game_services_google_play` | Auto-selects native on Android, REST elsewhere (incl. web) | ✅ |
| `unified_game_services_google_play_flutter` | Flutter adapter — auto-resolves the Android `Activity`, zero wiring | ✅ verified (native sign-in overlay + `flutter build web`) |
| `unified_game_services_xbox_pc` | Xbox on PC (Microsoft GDK) | 📋 research placeholder, not implemented |

`games_services` (the popular Flutter plugin) isn't used as a dependency
anywhere here — it requires Flutter + platform channels, which violates the
pure-Dart constraint above.

## Usage

```dart
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';
import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';

final services = UnifiedGameServices(
  providers: [
    SteamProvider(appId: 480),
    GameJoltProvider(
      gameId: '…',
      privateKey: '…',
      username: '…',
      userToken: '…',
    ),
  ],
);

await services.signIn();
await services.unlockAchievement('first_win'); // fans out to every capable provider
await services.submitScore(leaderboardId: 'global', score: 1500);
```

See the [facade README](packages/unified_game_services/README.md) for
capability gating, custom providers, multi-provider fan-out semantics, and
per-store build strategies.

## Development

This is a [melos](https://melos.invertase.dev/) workspace.

```sh
dart pub get                 # bootstrap (Flutter SDK on PATH required — see below)
melos run analyze            # dart analyze --fatal-infos, all packages
melos run format-check        # dart format --set-exit-if-changed .
melos run test                # dart test in packages that have a test/ dir
```

`unified_game_services_google_play_flutter` depends on `flutter` + `jni_flutter`,
so root bootstrap needs the Flutter SDK on `PATH` even though every other
package stays pure Dart. Provider-specific codegen (Steamworks, EOS, GameKit, Play Games JNI bindings)
needs the matching vendor SDK — see each provider's README; Steam and Epic
have `melos run steam:gen` / `melos run epic:gen`, Game Center and
Google Play Android use their own `tool/regenerate_bindings.sh` directly.

Contributor and architecture details live in [`CLAUDE.md`](CLAUDE.md).

## License & credits

**MIT** — see the [`LICENSE`](LICENSE) file.

This is an **independent, unofficial** library. It is not affiliated with or
endorsed by any platform vendor (Valve, Game Jolt, Epic Games, Microsoft,
Google, Apple). All trademarks belong to their respective owners and are used
only to identify the service each provider integrates with.

The repository bundles **no vendor SDK or native binary** it lacks permission
to redistribute — Steamworks, EOS, GameKit and the Play Games SDK are all
supplied by the host application at build/runtime, never committed here.

Third-party credits, trademark notices, and SDK redistribution terms: see
[`NOTICE.md`](NOTICE.md).
