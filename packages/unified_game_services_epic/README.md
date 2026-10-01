# unified_game_services_epic

Epic Online Services (EOS) provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services),
backed by the **EOS C SDK via pure-Dart `dart:ffi`**. Desktop only
(Windows/macOS/Linux).

## Platform support — desktop only

EOS is `dart:ffi`, so it runs **only on Windows, macOS and Linux** — **not** on
Android, iOS or web. Build each store target for the platform it ships on.

| Platform | Behaviour |
|----------|-----------|
| Windows / macOS / Linux | Full support. |
| Web | The package entry point exports an **inert `EpicProvider` stub** on web (`if (dart.library.io)` selects the real FFI provider). Importing the package never breaks `flutter build web` / `dart compile js`, but the constructor throws `UnsupportedError` — do **not** register Epic on web. `EpicCredentials` stays available everywhere. |
| Android / iOS | `dart:ffi` compiles, but the EOS runtime lib does not exist there, so the constructor throws `UnsupportedError` — do **not** register Epic on mobile. |

To keep the FFI code out of a mobile/web bundle entirely (not just inert), use a
per-platform entry point that never imports this package for those targets — see
the [per-store builds section](https://pub.dev/packages/unified_game_services#per-store-builds-steam-only-epic-only-)
in the facade README.

## Why SDK-first (not REST)

Unlike the Google Play provider — where the REST Games API is the primary
cross-platform tier — **the EOS Web API does not expose achievements,
leaderboards, stats, cloud save or presence over REST.** Those live only in the
EOS C SDK. The Web API surfaces just friends (read-only) and account/display
-name lookups. So the real Epic provider is the **FFI/C-SDK tier**, the same
"host supplies the native runtime" shape as Steam and Game Center.

| Capability      | EOS REST | EOS C SDK |
|-----------------|:--------:|:---------:|
| Achievements    |    ✗     | `EOS_HAchievements` |
| Stats           |    ✗     | `EOS_HStats` |
| Leaderboards    |    ✗     | `EOS_HLeaderboards` (aggregate ingested stats) |
| Cloud save      |    ✗     | `EOS_HPlayerDataStorage` |
| Presence        |    ✗     | `EOS_HPresence` |
| Friends (read)  |    ✓     | `EOS_HFriends` |
| Profile lookup  |    ✓     | `EOS_HUserInfo` |

## Host responsibilities

Like Steam, this package is **not zero-config** — by design (Epic's SDK is
license-gated and not redistributable):

1. **Ship the EOS runtime library** next to your executable, downloaded from
   the [EOS SDK](https://onlineservices.epicgames.com/sdk):
   - Windows: `EOSSDK-Win64-Shipping.dll`
   - macOS: `libEOSSDK-Mac-Shipping.dylib`
   - Linux: `libEOSSDK-Linux-Shipping.so`

   …or pass an explicit `libraryPath` to `EpicProvider`.
2. **Supply `EpicCredentials`** from the Epic Developer Portal: `productId`,
   `sandboxId`, `deploymentId`, `clientId`, `clientSecret` (+ optional
   `encryptionKey` for cloud save). Never commit `clientSecret`.

```dart
final services = UnifiedGameServices(providers: [
  EpicProvider(
    credentials: EpicCredentials(
      productId: '…', sandboxId: '…', deploymentId: '…',
      clientId: '…', clientSecret: '…',
    ),
  ),
]);

await services.signIn();                                   // anonymous Device ID → PUID
await services.unlockAchievement('ACHIEVEMENT_ID');
await services.submitScore(leaderboardId: 'STAT_NAME', score: 100);
await services.getAchievements();                          // read path (definitions + state)
```

(Or make it the global facade with `GameServices.initialize(providers:
[EpicProvider(...)])` and use `GameServices.instance` anywhere.)

## Sign-in: anonymous vs Epic Account Services (EAS)

`signIn()` picks the login method from how the provider was constructed:

| Construction | Login method | Identity | Real profile + friends |
|--------------|--------------|----------|:----------------------:|
| (nothing extra) | Device ID (anonymous) | `ProductUserId` only | ✗ |
| `devAuthHost` + `devAuthCredentialName` | `EOS_LCT_Developer` (Dev Auth Tool) | EpicAccountId → PUID | ✓ |
| `exchangeCode` / `launchArgs` (Epic Launcher) | `EOS_LCT_ExchangeCode` | EpicAccountId → PUID | ✓ |

EAS performs the full **Auth → Connect** flow: `EOS_Auth_Login` →
`EOS_Auth_CopyUserAuthToken` → `EOS_Connect_Login` (`EOS_ECT_EPIC`), running
`EOS_Connect_CreateUser` on first-time login. Only after an EAS login do
`getCurrentPlayer()` return the **real Epic display name** and `getFriends()`
return the player's Epic friends. The anonymous Device ID path has no Epic
account, so `getFriends()` throws `CapabilityNotSupportedException`.

```dart
// Real Epic login during development, via the EOS Developer Authentication Tool
// (run it from Tools/ in the SDK; no launcher or packaging needed):
final provider = EpicProvider(
  credentials: EpicCredentials(/* … */),
  devAuthHost: '127.0.0.1:6300',          // host:port the tool listens on
  devAuthCredentialName: 'MyCredential',  // credential name logged in the tool
);
final me = await provider.signIn();       // me.displayName == real Epic name
final friends = await provider.getFriends();
```

In production the Epic Launcher passes the exchange code on the command line
(`-AUTH_PASSWORD=…`); forward `main()`'s arguments via
`EpicProvider(launchArgs: args, …)`.

> **EAS needs Dev Portal setup.** The Auth interface requires an **Epic Account
> Services Application** with completed Brand settings and the **Client
> associated to it** with a policy granting the requested scopes (Basic Profile,
> Friends, Presence). A client configured only for Game Services returns
> `EOS_InvalidRequest` (error 1012, "Client is not configured correctly").

> **No avatar.** The EOS C SDK does not expose a player avatar — `EOS_UserInfo`
> only carries display name, country, nickname and preferred language — so
> `PlayerProfile.avatarUrl` is always null. Avatars are only reachable via the
> EAS Web API.

## Implemented surface (and current gaps)

EOS calls are asynchronous: they complete inside `EOS_Platform_Tick`, which the
provider pumps on a `Timer`. Completions are correlated to Dart `Future`s by the
`ClientData` token.

**Implemented today:**
- **Sign-in** — three methods (see the table above): anonymous Device ID,
  `EOS_LCT_Developer` (Dev Auth Tool), and `EOS_LCT_ExchangeCode` (Epic
  Launcher). EAS logins run the full Auth → Connect flow, including
  `EOS_Connect_CreateUser` for first-time login.
- **Real profile** — `getCurrentPlayer()` returns the Epic display name after an
  EAS login (`EOS_UserInfo_QueryUserInfo` + `CopyUserInfo`).
- **Friends** — `getFriends()` (`EOS_Friends_QueryFriends` →
  `GetFriendsCount`/`GetFriendAtIndex` → per-friend `EOS_UserInfo`). EAS only.
- `unlockAchievement` (`EOS_Achievements_UnlockAchievements`).
- `getAchievements` **read path** — `QueryDefinitions` +
  `QueryPlayerAchievements` + `CopyPlayerAchievementByIndex`.
- `setStat` / `incrementStat` / `submitScore` via `EOS_Stats_IngestStat`. EOS
  *aggregates* ingested stats per the portal-defined rule (SUM/LATEST/MIN/MAX);
  leaderboards rank a backing stat, so `submitScore` ingests that stat.
- `getStats` / `getStat` **read path** — `QueryStats` + `GetStatsCount` +
  `CopyStatByIndex`.
- `getLeaderboard` / `getPlayerScore` **read path** —
  `QueryLeaderboardRanks` + `GetLeaderboardRecordCount` +
  `CopyLeaderboardRecordByIndex`. `getPlayerScore` currently scans the ranks
  page (top 100) for the local player; a player below that is not found
  (a dedicated `QueryLeaderboardUserScores` path is a TODO).

- **Cloud save** (`EOS_HPlayerDataStorage`) — `saveData` / `loadData` /
  `listSaves` / `deleteData`.
- **Presence** (`EOS_HPresence`) — `setPresence`.

**Not implemented yet (documented gaps):**
- **No avatar** — the SDK does not expose one (`PlayerProfile.avatarUrl` is
  always null).
- `getPlayerScore` scans the top-100 ranks page rather than using a dedicated
  `QueryLeaderboardUserScores` path (TODO).

### Debug logging

Pass `debugLogging: true` to `EpicProvider(...)` to print verbose FFI/EOS traces
(callback firing, result codes, the EOS native log). Off by default.

### Bindings are ffigen-generated — struct offsets unverified

`lib/src/eos_bindings.dart` is **ffigen-generated** from the public EOS API
reference, so the package compiles without the license-gated headers. Struct
field offsets and the `*_API_LATEST` ApiVersion constants are
**version-sensitive and unverified** — they work at runtime for the exercised
paths, but before shipping, regenerate against your downloaded SDK for
verified output:

```sh
EOS_SDK_DIR=/path/to/EOS-SDK ./tool/regenerate_bindings.sh
# or from the repo root:
melos run epic:gen
```

The SDK headers/libs are **not** committed (`.eos-sdk/` is gitignored) — same
posture as the Steamworks and GameKit bindings in this repo.

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
any platform vendor. The EOS SDK is governed by Epic's
[Developer Agreement](https://onlineservices.epicgames.com/en-US/services/terms/agreements)
and is not redistributed here.
