# unified_game_services_epic

Epic Online Services (EOS) provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services),
backed by the **EOS C SDK via pure-Dart `dart:ffi`**. Desktop only
(Windows/macOS/Linux).

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
final provider = EpicProvider(
  credentials: EpicCredentials(
    productId: '…', sandboxId: '…', deploymentId: '…',
    clientId: '…', clientSecret: '…',
  ),
);
UnifiedGameServicesPlatform.instance = provider; // or EpicProvider.registerWith(...)

await provider.signIn();                                   // anonymous Device ID → PUID
await provider.unlockAchievement('ACHIEVEMENT_ID');
await provider.submitScore(leaderboardId: 'STAT_NAME', score: 100);
```

## Implemented surface (and current gaps)

EOS calls are asynchronous: they complete inside `EOS_Platform_Tick`, which the
provider pumps on a `Timer`. Completions are correlated to Dart `Future`s by the
`ClientData` token.

**Implemented today (write + auth path):**
- Anonymous **Device ID sign-in** → `ProductUserId` (PUID).
- `unlockAchievement` (`EOS_Achievements_UnlockAchievements`).
- `setStat` / `incrementStat` / `submitScore` via `EOS_Stats_IngestStat`. EOS
  *aggregates* ingested stats per the portal-defined rule (SUM/LATEST/MIN/MAX);
  leaderboards rank a backing stat, so `submitScore` ingests that stat.

**Not implemented yet (documented gaps):**
- **Read path** (`getAchievements`/`getStats`/`getLeaderboard`/…): needs the
  `Copy*`-based query result structs, which only the regenerated ffigen
  bindings provide. Calls throw a `PlatformOperationException` pointing here.
- **First-time anonymous login** (`EOS_Connect_CreateUser` continuance-token
  step), cloud save, friends, presence.

### Bindings are hand-authored — verify before shipping

`lib/src/eos_bindings.dart` is a **hand-authored** minimal FFI binding written
from the public EOS API reference, so the package compiles without the
license-gated headers. Struct field offsets and the `*_API_LATEST` ApiVersion
constants are **version-sensitive and unverified**. Before shipping, regenerate
against your downloaded SDK:

```sh
EOS_SDK_DIR=/path/to/EOS-SDK ./tool/regenerate_bindings.sh
# or from the repo root:
melos run epic:gen
```

This replaces the hand-authored file with ffigen output matching your exact SDK
version (and is the path to fill in the read-path gap). The SDK headers/libs are
**not** committed (`.eos-sdk/` is gitignored) — same posture as the Steamworks
and GameKit bindings in this repo.

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
any platform vendor. The EOS SDK is governed by Epic's
[Developer Agreement](https://onlineservices.epicgames.com/en-US/services/terms/agreements)
and is not redistributed here.
