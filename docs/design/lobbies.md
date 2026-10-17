# Lobbies & matchmaking (design for 0.3.0)

Status: implemented for core, PlayFab and Steam (Steam verified on Linux, PlayFab
only against recorded request shapes). Not done: the Discord IPC provider,
Epic lobbies, `PlayFabLogin` for cross-store login, and matchmaking.

SDK details (Steam, EOS, Discord, PlayFab) are written from memory and must be
checked against each SDK's docs before implementing a provider.

## Goal

A game that ships on Steam, Epic and mobile wants **one lobby that players on
different stores can share**. Store SDKs cannot do that: a Steam lobby only holds
Steam users. So the main path is:

- **Backend providers** (PlayFab, or your own via a custom provider) own lobbies
  and matchmaking.
- **Store providers** (Steam, Epic, Game Center, Google Play) keep providing
  identity, friends, achievements, leaderboards, cloud save.
- Store providers *may* also implement `lobbies` for games that stay inside one
  store. The contract is the same.

## Rules

1. **A lobby belongs to exactly one provider.** Lobby calls are never fanned out.
   They go to one provider and return a value.
2. **Routing:** `on:` if given, otherwise the first registered provider that
   advertises `lobbies`. Operations on an existing lobby route by
   `lobby.providerId`, so you never pass `on:` twice.
3. **Return convention:** fan-out writes return `MultiProviderOperationResult`
   (failures are data). Single-target calls, including reads and lobby calls,
   return the value and throw `GameServiceException` on failure.
4. **Unsupported:** `CapabilityNotSupportedException`, as everywhere else.
5. **Search is part of `lobbies`.** No separate capability.
6. **Out of scope:** chat, voice, kick, ownership transfer, game networking.

## Models

```dart
enum LobbyVisibility { private, friendsOnly, public }

class LobbyMember {
  final PlayerProfile player;
  final Map<String, String> data; // per-member data (ready flag, loadout...)
}

class Lobby {
  final String id;
  final String providerId;
  final String joinToken;          // opaque string that joinLobby accepts; safe to
                                   // put in presence/invites (see Discord below)
  final String ownerId;            // a LobbyMember.player.id
  final List<LobbyMember> members; // empty in search summaries
  final int? memberCount;          // set for summaries; use Lobby.size
  final int maxMembers;
  final LobbyVisibility visibility;
  final Map<String, String> data;  // string -> string, lowest common denominator
}

enum LobbyFilterOp { equals, notEquals, lessThan, greaterThan }

class LobbyFilter {
  final String key;
  final LobbyFilterOp op;
  final String value;              // numeric ops parse it as a number
}
```

Hand-written immutable classes with `copyWith`, `==`, `hashCode`, `toString`,
as in `CLAUDE.md`.

Why strings: Steam, Discord and PlayFab are string-only; EOS attributes are
typed and convert at the provider boundary.

Why no `isLocked`/`joinable`: not common to all four. Add later if two providers
need it.

## Platform interface (provider side)

```dart
Future<Lobby> createLobby({
  int maxMembers = 4,
  LobbyVisibility visibility = LobbyVisibility.friendsOnly,
  Map<String, String> data = const {},
  Map<String, String> memberData = const {},
});
/// [joinToken] is `Lobby.joinToken`: the lobby id on Steam/EOS, the connection
/// string on PlayFab, the secret on Discord.
Future<Lobby> joinLobby(String joinToken, {Map<String, String> memberData});
Future<void> leaveLobby(String lobbyId);
Future<Lobby?> getLobby(String lobbyId);
Future<List<Lobby>> findLobbies({List<LobbyFilter> filters, int maxResults = 25});

/// Owner only. A null value removes the key.
Future<Lobby> updateLobby(String lobbyId, {
  Map<String, String?>? data, LobbyVisibility? visibility, int? maxMembers,
});
Future<Lobby> setMemberData(String lobbyId, Map<String, String?> data);

Future<void> sendInvitation(String lobbyId, String userId);
```

Every method has a default body that throws
`CapabilityNotSupportedException(GameCapability.lobbies)`.

Minimal set for a custom provider: `createLobby`, `joinLobby`, `leaveLobby`,
`getLobby`, `findLobbies`. `updateLobby`, `setMemberData` and invitations can
come later. A Supabase-backed provider is rows plus realtime.

## Facade

```dart
final lobby = await GameServices.createLobby(maxMembers: 4, data: {'mode': 'ranked'});
final open  = await GameServices.findLobbies(filters: [
  LobbyFilter('mode', LobbyFilterOp.equals, 'ranked'),
]);
final joined = await GameServices.joinLobby(open.first.id, on: playfab);
await GameServices.setMemberData(joined, {'ready': 'true'});
await GameServices.leaveLobby(joined);
```

`joinLobby` takes an id, so it needs `on:` unless the default provider is the
right one. Everything after that takes the `Lobby` and routes itself.

## Events

New members of the sealed `GameServiceEvent` hierarchy. Each carries the
updated `Lobby`:

- `LobbyMemberJoinedEvent(lobby, member)`
- `LobbyMemberLeftEvent(lobby, member)`
- `LobbyDataChangedEvent(lobby)` (lobby or member data)
- `LobbyOwnerChangedEvent(lobby, previousOwnerId)`
- `LobbyClosedEvent(lobby)`
- `InvitationReceivedEvent` gains `joinToken` and `providerId`
- `JoinRequestedEvent(joinToken, from)`: someone accepted an invite or clicked
  "Join" on your presence (Discord app/overlay, Steam friends list)
- `JoinRequestReceivedEvent(user, reply)`: someone asks to join *you*; answer with
  `reply(accept: true/false)` (Discord "Ask to join")

Owner leaving: the provider decides (Steam and EOS migrate, PlayFab is
configurable). The game only sees `LobbyOwnerChangedEvent` or
`LobbyClosedEvent`. REST providers poll internally and emit the same events.

## Discord: presence, "Ask to join" and invites

Discord matters because players invite and join from the Discord app or overlay,
without opening the game first. The mechanism is **rich presence with a party
and a join secret**, not the lobby API itself. Per Discord's docs, an activity
needs a party id, a party size with room left, and a non-empty join secret;
the secret is only handed to users an existing member accepts. Using a lobby id
or secret as the join secret is the documented pattern.

That is exactly `Lobby.joinToken`, and it decouples the two jobs:

- the **lobby** can live in PlayFab (cross-store),
- the **Discord provider** only owns presence, invites and join events.

```dart
final lobby = await GameServices.createLobby(on: playfab);
await GameServices.setPresence(RichPresence(
  state: 'In lobby', details: 'Ranked',
  partyId: lobby.id, partySize: 1, partyMax: lobby.maxMembers,
  joinToken: lobby.joinToken,          // Discord puts this in the join secret
));

GameServices.events.whereType<JoinRequestedEvent>().listen((e) async {
  await GameServices.joinLobby(e.joinToken, on: playfab);
});
```

Changes to existing unified API: `RichPresence` gains optional `partyId` and
`joinToken` (it already had `partySize`/`partyMax`). Providers without join support ignore them
(Steam `connect` string and EOS presence join info map to the same fields).
A convenience `GameServices.advertiseLobby(lobby)` can set presence from a lobby
in one call.

Provider shape (to verify): classic Discord Rich Presence works over the local
Discord client's IPC socket (`SET_ACTIVITY`, and `ACTIVITY_JOIN`,
`ACTIVITY_JOIN_REQUEST` events). That is plain sockets, so a **pure Dart
`DiscordProvider` needs no native library**, desktop only. The Discord Social SDK
(C++, lobbies with chat/voice, mobile) would be a later FFI tier, like Google
Play REST then Android. Mobile invites use a deep link configured in the
developer portal.

Priority: because Discord needs only presence plus join events, it can ship
**before** lobbies are complete, and it is the cheapest second real provider.

## PlayFab authentication

PlayFab's Multiplayer Lobby API uses an **entity token**, not the Client session
ticket that `PlayFabProvider` stores today. The login responses include an entity
token, and `Authentication/GetEntityToken` exchanges or refreshes one. So
`PlayFabClient` needs to keep and refresh the entity token (and the title-player
entity id) and send it with lobby calls. Also `Authentication/ValidateEntityToken`
lets *your* server verify a client token, which is the server side of
`identityTokens` for PlayFab.

## Cross-store identity (why `identityTokens` matters)

A PlayFab lobby only works across stores if a Steam player and an Epic player
are both PlayFab players. Today `PlayFabProvider` signs in with
`LoginWithCustomID` only. Proposal, following the pattern of
`AuthStrategy` in Google Play REST:

```dart
PlayFabProvider(
  titleId: '...',
  login: PlayFabLogin.steam(() => GameServices.getIdentityToken(from: steam)),
);
```

Candidates: `customId` (today), `steam(ticketProvider)`, and Epic via OpenID
Connect. Whether PlayFab accepts the EOS ID token directly must be verified. The
Steam ticket from `getIdentityToken()` expires after 2 minutes, so the provider
asks for a fresh one at each login.

## Matchmaking (after lobbies)

Not designed in detail here. Constraint on the lobby model: a match result must
be convertible to a `Lobby` (members, owner, data) so a game handles matchmade
and hand-made groups the same way. Sketch:
`startMatchmaking(queue, attributes) -> MatchmakingTicket`,
`cancelMatchmaking(ticket)`, events `MatchFoundEvent(lobby)` and
`MatchmakingFailedEvent`.

## Implementation order

1. Models, platform methods, facade, events, `RichPresence.party/joinToken`,
   tests with a fake provider.
2. **PlayFab** (REST, testable in CI with `MockClient`). Includes entity token
   handling and `PlayFabLogin`.
3. **Discord** (IPC presence, join events): validates `joinToken` end to end with
   a lobby that lives in another provider.
4. **Steam** (`ISteamMatchmaking`), to prove a second, very different SDK fits
   the contract without breaking it.
5. EOS lobbies, Discord Social SDK lobbies.
6. Matchmaking.

The roadmap's 1.0 criterion (two real providers without breaking changes) is met
by steps 2 and 4.

## Parties

A party is a `Lobby` with `kind: LobbyKind.party`: same operations, usually
`private`, kept between activities. There is no separate capability. Providers
store the kind under the reserved lobby-data key `ugs_kind` and hide it from
`Lobby.data`. Matchmaking will take a `Lobby` (typically a party) as the group
that queues together. Revisit if two real providers expose a party API that
differs from their lobbies (Xbox is the likely one).

## Open questions

- Does PlayFab accept the EOS ID token for login? The route would be
  `LoginWithOpenIdConnect` with an OpenID connection configured for Epic. A forum
  report suggests it is fiddly; not verified. Fallback: link by custom id.
- Does the Discord overlay's invite button reach the same `ACTIVITY_JOIN` event?
  Expected yes; verify with a real application id.
- Do we need `isLocked`? (Steam has `SetLobbyJoinable`.)
- Should `findLobbies` also be able to search friends' lobbies
  (PlayFab `FindFriendLobbies`, Steam friend lobbies)?
