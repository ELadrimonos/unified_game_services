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
| `lobbies`      | Multiplayer Lobby API (`Lobby/*`) |

**Achievements are intentionally unsupported.** PlayFab has no first-class
achievements API — they are conventionally built on statistics in app/server
logic — so `GameCapability.achievements` is not advertised and the achievement
operations stay unsupported rather than being faked. Rich presence,
invitations and matchmaking are likewise omitted.

## Lobbies

PlayFab is the intended place for **cross-store lobbies**: a Steam and an Epic
player can share one if both are PlayFab players. Lobby calls use the entity
token (refreshed automatically) and map like this:

- **Searchable data.** PlayFab only lets you filter on keys named
  `string_key1..30` / `number_key1..30`. Map your own keys onto them:

  ```dart
  PlayFabProvider(
    titleId: 'ABCD',
    customId: id,
    lobbySearchKeys: {'mode': 'string_key1', 'level': 'number_key1'},
  );
  // data: {'mode': 'ranked', 'level': '7', 'map': 'dust'}
  //   -> SearchData {string_key1, number_key1}, LobbyData {map}
  await GameServices.findLobbies(filters: [
    LobbyFilter('mode', LobbyFilterOp.equals, 'ranked'),
  ]);
  ```

  Filters on unmapped keys throw `ArgumentError`. Search results are summaries:
  `members` is empty, use `Lobby.size`.
- **No PubSub.** This provider is REST-only. Lobbies are created with
  `UseConnections: false` and owner migration `None` (otherwise they would not
  be searchable), so PlayFab never hands ownership to someone else for you.
  Events come from polling every `lobbyPollInterval` (default 5 s, `null`
  disables it; call `pollLobbies()` yourself).
- **Ids.** Members and owner are identified by their title-player *entity id*
  (`PlayFabProvider.entityId`), not their `PlayFabId`.
  `dispose()` leaves the lobbies it joined; if the app is killed instead, PlayFab
  does not notice (no PubSub), so the player stays listed as a member. `Lobby.joinToken` is the
  connection string; share it through your own channel or rich presence.

Not verified against a live PlayFab title yet; the tests use recorded request and
response shapes from the REST reference.

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

Make it the global facade instead of holding the reference:

```dart
GameServices.initialize(providers: [
  PlayFabProvider(titleId: 'ABCD1', customId: 'stable-player-id'),
]);
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
