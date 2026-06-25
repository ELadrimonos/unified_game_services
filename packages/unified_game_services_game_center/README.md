# unified_game_services_game_center

Apple Game Center provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services),
backed by **GameKit** through pure-Dart Objective-C FFI
([`package:objective_c`](https://pub.dev/packages/objective_c)). **No Flutter
dependency** — the same code runs in a Flutter app, a custom Dart game engine,
a CLI, or a server, as long as it runs on **macOS or iOS**.

## Supported capabilities

| Capability    | Supported | Notes |
|---------------|-----------|-------|
| Authentication | ✅ | `GKLocalPlayer` |
| Achievements   | ✅ | `GKAchievement` (+ `GKAchievementDescription`); progress is a 0–100 % mapped onto steps-out-of-100 |
| Leaderboards   | ✅ | `GKLeaderboard` (submit + entries, time-scope and friends/global collections) |
| Stats          | ❌ | GameKit has no portable numeric-stat concept |
| Cloud save     | ⏸️ | `GKSavedGame` — planned |
| Friends        | ⏸️ | `loadFriends` — planned |
| Rich presence  | ❌ | no GameKit equivalent |

## Runtime requirements (host-supplied)

GameKit talks to the OS Game Center service, and the OS — not this package —
imposes two requirements the host process must meet:

1. **A signed app bundle.** The executable must run inside a code-signed
   `.app`/`.ipa` whose bundle id is registered in App Store Connect, with the
   matching entitlements/provisioning. A bare `dart run` has no bundle, so
   GameKit refuses to authenticate (`GKErrorNotAuthenticated`). A Flutter
   macOS/iOS app already is such a bundle; a custom engine must package itself
   as one.
2. **A pumped main run loop.** GameKit delivers completion handlers on the main
   dispatch queue / `CFRunLoop`. The host must keep that run loop running for
   the returned `Future`s to complete. Flutter/AppKit apps do this already; a
   headless engine must pump `CFRunLoopRun()` on the main thread.

This mirrors how the Steam provider needs the Steam client running: the
capability is pure Dart, but the surrounding environment is the host's job.

## Usage

```dart
import 'package:unified_game_services_game_center/unified_game_services_game_center.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

GameCenterProvider.registerWith(
  leaderboardIds: {'global': 'com.example.game.highscores'},
  achievementIds: {'first_win': 'com.example.game.firstwin'},
);
final services = UnifiedGameServicesPlatform.instance;

final player = await services.signIn();
await services.unlockAchievement('first_win');
await services.submitScore(leaderboardId: 'global', score: 4200);
final board = await services.getLeaderboard('global', maxResults: 10);
```

See [`example/`](example/) for a complete sample.

## GameKit bindings

The committed `lib/src/gamekit_bindings.dart` is generated from the macOS SDK
GameKit headers with ffigen (see `ffigen_gamekit.yaml`). It is committed so
consumers don't need Xcode. To regenerate (macOS + Xcode required):

```sh
./tool/regenerate_bindings.sh
```

The committed `lib/src/gamekit_bindings.dart.m` holds the ffigen-generated
Objective-C block trampolines. The package's build hook (`hook/build.dart`)
compiles it into a dynamic library at consumer build time — so a consuming app
needs the Apple toolchain (`clang` via Xcode Command Line Tools) and a
native-assets-capable build (Flutter macOS/iOS, or `dart`/`dart test` on Dart
3.12+). No Apple SDK is shipped: the `.m` is our generated glue, and GameKit
itself is `dlopen`'d from the OS at runtime.

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
any platform vendor. Third-party credits, trademark notices, and the Steamworks
SDK redistribution terms are in the repository's `NOTICE.md`.
