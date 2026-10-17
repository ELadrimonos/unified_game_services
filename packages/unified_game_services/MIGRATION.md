# Migrating from 0.1 to 0.2

0.2.0 stabilizes the public API. These are the changes that need action, most
likely first. Each provider's `CHANGELOG.md` lists its own details.

## Register providers on the facade

`registerWith(...)` and `UnifiedGameServicesPlatform.instance` are gone. Build
the providers and hand them to the facade:

```dart
// 0.1
SteamProvider.registerWith(appId: 480);

// 0.2
GameServices.initialize(providers: [SteamProvider(appId: 480)]);
// or, without touching a global:
final services = UnifiedGameServices(providers: [SteamProvider(appId: 480)]);
```

`providers` must not be empty (`ArgumentError`). The first provider is the
`primary` one used for reads.

## Writes return a result instead of throwing

`signIn`, `signOut`, `unlockAchievement`, `incrementAchievement`, `submitScore`,
`setStat`, `incrementStat`, `saveData`, `setPresence`, `clearPresence` and
`dispose` now return a `MultiProviderOperationResult`. A provider failing does
not throw; look in the result:

```dart
final result = await GameServices.submitScore(leaderboardId: 'global', score: 10);
if (!result.allSucceeded) {
  for (final r in result.failed) print('${r.providerId}: ${r.error}');
}
```

- `signIn()` no longer returns a `PlayerProfile?`. Use `getCurrentPlayer()` or
  `result['steam']?.value`.
- `AggregateGameServiceException` is removed.
- It still throws `CapabilityNotSupportedException` when no provider supports
  the capability at all.

## Reads use unified ids

`Achievement.id`, `Leaderboard.id` and `Stat.key` are now the unified key from
your mapping tables (the native id when you have none). The provider's own id
is in `nativeIds` / `nativeKeys`. Pass the mapping tables to
`GameServices.initialize(achievements: ..., leaderboards: ..., stats: ...)`
instead of repeating ids on each provider.

## Errors

Anything a provider does not support throws `CapabilityNotSupportedException`
(it used to be `UnimplementedError`). Catch that, or check
`GameServices.supports(cap)` first.

## Models lost their JSON

`dart_mappable` is gone. Models are plain immutable classes with `copyWith`,
`==`, `hashCode` and `toString`. There is no `toJson` / `fromJson`; keep your own
mapping if you persisted them. `copyWith` cannot reset a field to `null`.

## Capabilities

`GameCapability.multiplayer` is replaced by `lobbies` and `matchmaking`.
`lobbies`, `invitations`, `identityTokens` and `overlays` (Google Play Android)
are implemented now; see the README. `createLobby`, `joinLobby`, `leaveLobby` and `sendInvitation` changed
signature: they take and return `Lobby` values and are not fanned out.
`InvitationReceivedEvent` now carries `senderId`, `joinToken` and `providerId`.

## If you wrote a provider

- `providerId` is abstract: return a stable `snake_case` string (never
  `runtimeType`).
- Override `capabilities` and the operations you support; the defaults throw
  `CapabilityNotSupportedException`.
- Remove any `registerWith`; there is no global platform instance.
