# unified_game_services_google_play_flutter

Flutter adapter for the `unified_game_services` **Google Play Games** family.

The provider packages are pure Dart and require the host to hand them the
Android `Activity` jobject. This is the **only** package in the family that
depends on Flutter: it resolves that activity from the running Flutter engine
(via [`jni_flutter`]), giving you plug-and-play registration — no
`PlatformDispatcher` / `jni_flutter` wiring in your app code.

**If you are building a Flutter app, this is the package you want.**

## Which package do I use?

| Your app | Package |
| --- | --- |
| **Flutter app** (any platform) | **this package** (`unified_game_services_google_play_flutter`) |
| **Non-Flutter, multi-platform** (game engine / CLI / server) — native on Android, REST elsewhere | [`unified_game_services_google_play`](../unified_game_services_google_play) |
| **Android only**, non-Flutter host, want native toasts | [`unified_game_services_google_play_android`](../unified_game_services_google_play_android) |
| **Cloud REST tier** — any platform incl. Android (NDK), no native toasts | [`unified_game_services_google_play_rest`](../unified_game_services_google_play_rest) |

### Native screens (`overlays`)

On Android, `GameServices.showAchievementsUI()` and
`GameServices.showLeaderboardsUI(leaderboardId: ...)` open the native Play Games
screens. Off Android (the REST tier) they throw `CapabilityNotSupportedException`,
so gate with `GameServices.supports(GameCapability.overlays)` if you target both.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_google_play_flutter/unified_game_services_google_play_flutter.dart';

void main() {
  // Android: auto-resolves the Activity and wires the native Play Games
  // provider (native toasts/overlay). Off Android — including Flutter web —
  // pass `auth:` for the REST path.
  GameServices.initialize(providers: [
    GooglePlayGamesFlutter.create(
      achievementIds: {'firstWin': 'CgkI...'},
      leaderboardIds: {'highScores': 'CgkI...'},
    ),
  ]);
  runApp(const MyApp());
}

// Anywhere in the app:
final games = GameServices.instance; // the global facade from main()
await games.unlockAchievement('firstWin');
```

`GooglePlayGamesFlutter.create` returns the provider; hand it to
`GameServices.initialize(providers: [...])` (alongside other providers if
you use several).

This package re-exports the whole family API
(`unified_game_services_google_play`), so the single import above also gives you
`GooglePlayAndroidProvider`, `GooglePlayGamesProvider`, and the REST
`AuthStrategy` types.

## Why a separate package

The family enforces *pure Dart, no Flutter* so the providers work in CLIs,
servers, and non-Flutter game engines. `jni_flutter` is a Flutter plugin —
it cannot live in the pure-Dart packages. This adapter quarantines the Flutter
dependency: Flutter apps add it, everyone else uses the pure-Dart packages
directly and supplies their own `activityResolver`.

## Android setup

Same as the native provider: bundle the Play Games v2 aar and declare the app
id. See `example/` (carries the `play-services-games-v2` gradle dependency and
the `com.google.android.gms.games.APP_ID` manifest meta-data).

## Web & other platforms

`jni_flutter` / `package:jni` (no web support) sit behind a `dart.library.io`
conditional import, so this adapter compiles and runs on **Flutter web** (and
desktop): off Android it takes the REST path and needs an `auth:`
[`AuthStrategy`]. On web, broker a token (your own redirect-based OAuth or a
backend) and pass it via `StoredCredentialStrategy` — the interactive
`LoopbackOAuthStrategy` is desktop/CLI only.

[`jni_flutter`]: https://pub.dev/packages/jni_flutter
