# unified_game_services_google_play

Auto-selecting Google Play Games provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services). Use
this and forget platform compatibility: it picks the **native** Play Games SDK
provider on Android (native toasts/overlay, no OAuth) and the **REST** provider
everywhere else (desktop, CLI, server). Pure Dart, no Flutter.

Wraps:
- [`unified_game_services_google_play_android`](../unified_game_services_google_play_android) — Android, Play Games v2 Java SDK via `package:jni`.
- [`unified_game_services_google_play_rest`](../unified_game_services_google_play_rest) — all platforms, REST Games API v1 + OAuth.

## Usage

```dart
import 'package:unified_game_services_google_play/unified_game_services_google_play.dart';

// On Android: pass the Activity jobject. Elsewhere: pass an AuthStrategy.
GooglePlayGames.registerWith(
  activity: androidActivity,                       // Android only
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

The pick is a runtime `Platform.isAndroid` check — Dart has no compile-time OS
guard, so the `jni` dependency is linked into every build but only executes on
Android. The native side carries the read-path limitation documented in
`unified_game_services_google_play_android` (writes fire native UI;
`Task`-result reads are pending). For full reads on Android today, also
register the REST provider in the facade.

## License

MIT — see [LICENSE](LICENSE). Independent, unofficial; not affiliated with any
platform vendor. See the repository `NOTICE.md`.
