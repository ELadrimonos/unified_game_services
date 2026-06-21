# unified_game_services_playfab

PlayFab provider for
[`unified_game_services`](https://github.com/ELadrimonos/unified_game_services),
using the **PlayFab Client API** over REST. Pure Dart — no Flutter, no native
SDK — so it runs anywhere Dart does.

## PlayFab is not Xbox Live

PlayFab is Microsoft's cross-platform backend-as-a-service. A PlayFab title ships
on mobile, PC, console and web, and its Client API is plain HTTPS — which is why
it fits this package's pure-Dart constraint. Native **Xbox Live** (GDK,
title-scoped services) is a different product and remains deferred; see the root
`CLAUDE.md`.

## Capabilities

| Capability     | Backed by                         |
| -------------- | --------------------------------- |
| `leaderboards` | Player Statistics (`GetLeaderboard`/`UpdatePlayerStatistics`) |
| `stats`        | Player Statistics                 |
| `cloudSave`    | User Data (`Get`/`UpdateUserData`)|
| `friends`      | `GetFriendsList`                  |

**Achievements are intentionally unsupported.** PlayFab has no first-class
achievements API — they are conventionally built on statistics in app/server
logic — so `GameCapability.achievements` is not advertised and the achievement
operations stay unimplemented rather than being faked. Rich presence and
multiplayer are likewise omitted.

## Usage

```dart
import 'package:unified_game_services_playfab/unified_game_services_playfab.dart';

final provider = PlayFabProvider(
  titleId: 'ABCD1',                       // public Title ID (Game Manager)
  customId: 'stable-player-id',           // app-chosen, stable per player
  displayName: 'Ada',
  leaderboardIds: {'high': 'HighScore'},  // unified key → statistic name
);

await provider.signIn();                  // LoginWithCustomID
await provider.submitScore(leaderboardId: 'high', score: 4200);
final board = await provider.getLeaderboard('high');
```

Register it as the active provider instead of holding the reference:

```dart
PlayFabProvider.registerWith(titleId: 'ABCD1', customId: 'stable-player-id');
```

### Auth

Sign-in uses `LoginWithCustomID`: pass a stable, app-chosen `customId` per player
(`CreateAccount: true` by default registers it on first use). Only the public
`titleId` is needed — the secret key belongs to the *Server* API and is never
used here. The session ticket is stored on the client and attached as
`X-Authorization` on subsequent calls.

## Credentials

1. Create a title at <https://developer.playfab.com>.
2. Copy its **Title ID** from the Game Manager dashboard.
3. Choose how players are identified (a device id, your own account id, …) and
   pass it as `customId`.

API reference: <https://learn.microsoft.com/en-us/gaming/playfab/api-references/>
