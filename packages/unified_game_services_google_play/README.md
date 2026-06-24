# unified_game_services_google_play

Auto-selecting Google Play Games provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services). Use
this and forget platform compatibility: it picks the **native** Play Games SDK
provider on Android (native toasts/overlay, no OAuth) and the **REST** provider
everywhere else (desktop, CLI, server). Pure Dart, no Flutter.

Wraps:
- [`unified_game_services_google_play_android`](../unified_game_services_google_play_android) — Android, Play Games v2 Java SDK via `package:jni`.
- [`unified_game_services_google_play_rest`](../unified_game_services_google_play_rest) — all platforms, REST Games API v1 + OAuth.

## Which package do I use?

| Your app | Package |
| --- | --- |
| **Flutter app** (any platform) | [`unified_game_services_google_play_flutter`](../unified_game_services_google_play_flutter) — auto-resolves the Activity; no `jni_flutter` wiring. |
| **Non-Flutter, multi-platform** (game engine / CLI / server) — native on Android, REST elsewhere | **this package** (`unified_game_services_google_play`) |
| **Android only**, non-Flutter host, want native toasts | [`unified_game_services_google_play_android`](../unified_game_services_google_play_android) |
| **Non-Android only** (desktop / CLI / server, REST) | [`unified_game_services_google_play_rest`](../unified_game_services_google_play_rest) |

> **Building a Flutter app? Use `unified_game_services_google_play_flutter`
> instead** — it wires the Android `Activity` resolver for you. This package
> needs you to supply that resolver yourself (see below), which a Flutter app
> should not do by hand.

## Usage

```dart
import 'package:unified_game_services_google_play/unified_game_services_google_play.dart';

// On Android: pass an activityResolver (invoked fresh before each native call).
// Elsewhere: pass an AuthStrategy.
GooglePlayGames.registerWith(
  activityResolver: () => androidActivity,         // Android only
  auth: LoopbackOAuthStrategy(clientId: '<id>'),   // desktop/CLI/server
  achievementIds: {'first_win': 'CgkI...'},
  leaderboardIds: {'global': 'CgkI...'},
);

// Same unified calls regardless of platform:
final games = UnifiedGameServices();
await games.unlockAchievement('first_win');        // native toast on Android
await games.submitScore(leaderboardId: 'global', score: 1500);
```

`GooglePlayGames.create(...)` returns the provider without registering it.
`GooglePlayGames.usesNative` reports the current platform's choice.

## Note on the selection

On web, `package:jni` (FFI, no web support) is excluded from the build via a
`dart.library.io` conditional import, so only the REST path compiles — the
facade runs on web. On native, the pick is a runtime `Platform.isAndroid`
check: `jni` is linked but only executes on Android. The native side carries
the read-path limitation documented in
`unified_game_services_google_play_android` (writes fire native UI;
`Task`-result reads are pending). For full reads on Android today, also
register the REST provider in the facade.

## License

MIT — see [LICENSE](LICENSE). Independent, unofficial; not affiliated with any
platform vendor. See the repository `NOTICE.md`.
