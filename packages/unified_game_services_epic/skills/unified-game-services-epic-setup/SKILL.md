---
name: unified-game-services-epic-setup
description: Configure unified_game_services_epic 0.2.0 with the EOS desktop runtime, Developer Portal credentials, Device ID or Epic Account Services authentication, and facade wiring. Use when adding Epic Games support or diagnosing EOS loading, login, permissions, lifecycle, or cloud-save setup.
---

# Epic Games / EOS setup

Use this procedure for `unified_game_services_epic` **0.2.0**. This is a
pure-Dart EOS C SDK provider, not a REST client or Flutter plugin. Do not
invent auth modes or infer native support from the web stub/API summary.
These instructions are self-contained; no package-relative resources are needed.

## 1. Confirm the host and runtime

- Require Dart `^3.12.0`. Add `unified_game_services_epic: ^0.2.0` and
  `unified_game_services: ^0.2.0` to the host's dependencies for facade use.
  Add `unified_game_services_platform_interface: ^0.2.0` if importing its models.
- Target Windows, macOS or Linux. Check `EpicProvider.isSupported` before
  construction. Web imports are safe but construction throws `UnsupportedError`;
  Android/iOS construction also throws. Do not include Epic in those providers.
- Obtain the EOS SDK through Epic's authorized download process and follow its
  license terms. This package supplies neither SDK headers nor runtime binaries.
  Ship only permitted runtime artifacts; never commit the downloaded SDK.
- Match the runtime to the host OS and process architecture:

  | Host | Runtime filename |
  | --- | --- |
  | Windows | `EOSSDK-Win64-Shipping.dll` |
  | macOS | `libEOSSDK-Mac-Shipping.dylib` |
  | Linux | `libEOSSDK-Linux-Shipping.so` |

- Prefer an explicit `libraryPath` to the shared-library file for initial setup.
  Without it, the provider opens the filename above using the OS loader's search
  path; placement beside the executable is not a portable search-path guarantee.
  Verify packaged-host permissions, signing and dependent-library resolution.
- Construction does not load EOS. `signIn()` initializes it lazily; successful
  construction alone proves neither runtime loading nor backend connectivity.
- Treat generated struct layouts and `*_API_LATEST` constants as SDK-version
  sensitive and not universally verified. Before release, arrange binding
  regeneration against the chosen SDK in the package's source checkout and
  live validation of the exercised paths. Do not claim a specific EOS SDK
  version is certified by this package.

## 2. Configure the Developer Portal

1. Select the intended product, sandbox and deployment. Keep development and
   production environments separate and use IDs from the same configuration.
2. Create/select a product client and give its client policy only the Game
   Services permissions needed for Connect and the operations you will use.
   Configure achievement definitions, stats and leaderboard definitions before
   attempting those operations. Record each leaderboard's backing stat and
   aggregation rule (`SUM`, `LATEST`, `MIN` or `MAX`).
3. For either EAS login mode, configure an **Epic Account Services Application**,
   complete its Brand settings and associate the client. Enable Basic Profile,
   Friends and Presence permissions and ensure test accounts have access to the
   application/environment. The provider requests all three scopes; it exposes
   no scope-selection argument. A Game Services-only client is insufficient.
4. For cloud save, permit Player Data Storage and provision its 256-bit
   encryption key (64 hexadecimal characters). This implementation additionally
   requires EAS for **all** cloud-save operations, even though it addresses PDS
   by ProductUserId. `saveData` and `loadData` reject a null/empty key locally;
   `listSaves` and `deleteSave` do not perform that local key check.
5. Supply `EpicCredentials` with required strings `productId`, `sandboxId`,
   `deploymentId`, `clientId`, `clientSecret`. Optional fields are `encryptionKey`,
   `productName` (default `unified_game_services`) and `productVersion`
   (default `1.0.0`). Set the last two to your application identity.

## 3. Choose exactly one implemented login mode

`Future<PlayerProfile?> signIn()` selects the first matching mode:

| Priority | Constructor input | Result |
| --- | --- | --- |
| 1 | Both `devAuthHost` and `devAuthCredentialName` non-null | Developer Auth Tool, `EOS_LCT_Developer` |
| 2 | Non-empty resolved `exchangeCode` | Epic Launcher, `EOS_LCT_ExchangeCode` |
| 3 | Neither condition above | Anonymous Device ID through Connect |

- **Development EAS:** run the SDK Developer Authentication Tool, log in the
  test account, name its credential, then pass e.g. `devAuthHost: '127.0.0.1:6300'`
  and `devAuthCredentialName: 'MyCredential'`. Use the tool's actual port/name.
  Pass both or neither; normalize empty inputs to null. Never ship Dev Auth
  Tool configuration as production authentication.
- **Launcher EAS:** forward `main(List<String> args)` via `launchArgs: args`.
  Parsing recognizes `-AUTH_PASSWORD=<code>` case-insensitively. An explicit
  non-null `exchangeCode` overrides argument extraction, even if empty; an empty
  code falls back to anonymous login unless Dev Auth is selected. Use a fresh
  launcher code for a new login, not a persisted or replayed code.
- **Anonymous:** omit both Dev Auth fields and any exchange code. It yields a
  ProductUserId, not an Epic account. Do not silently accept this fallback when
  production requires EAS: verify the returned profile's identity metadata.
- EAS performs Auth login → copies the user access token → Connect login with
  `EOS_ECT_EPIC`; first-time Connect users are created automatically. Device ID
  also creates a Connect user when necessary. No account-portal, password,
  persistent-auth, custom external-token or account-linking API is exposed here.
- The profile `id` is the Connect ProductUserId in every mode. EAS adds
  `extra['epicAccountId']`; anonymous adds `extra['isAnonymous'] == true`.
  EAS resolves a display name; `avatarUrl` remains null. Friends, presence and
  cloud save throw `CapabilityNotSupportedException` after anonymous login.

## 4. Wire the 0.2.0 facade

Construct the provider and pass it to the facade. There is no `registerWith`.
This desktop CLI example reads host-supplied environment values; the provider
itself does not read environment variables or automatically discover the SDK.

```dart
import 'dart:io';
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_epic/unified_game_services_epic.dart';

String requiredEnv(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    throw StateError('Missing $name');
  }
  return value;
}

Future<void> main(List<String> args) async {
  if (!EpicProvider.isSupported) {
    throw UnsupportedError('EOS requires a desktop host');
  }
  final epic = EpicProvider(
    credentials: EpicCredentials(
      productId: requiredEnv('EOS_PRODUCT_ID'),
      sandboxId: requiredEnv('EOS_SANDBOX_ID'),
      deploymentId: requiredEnv('EOS_DEPLOYMENT_ID'),
      clientId: requiredEnv('EOS_CLIENT_ID'),
      clientSecret: requiredEnv('EOS_CLIENT_SECRET'),
      encryptionKey: Platform.environment['EOS_ENCRYPTION_KEY'],
      productName: 'MyGame',
      productVersion: '1.0.0',
    ),
    libraryPath: requiredEnv('EOS_LIBRARY_PATH'),
    launchArgs: args,
    debugLogging: false,
  );
  final services = GameServices.initialize(providers: [epic]);
  try {
    (await services.signIn()).throwIfAnyFailed();
    // Run the application here; gate features on capabilities AND login mode.
  } finally {
    final disposal = await services.dispose();
    GameServices.reset();
    disposal.throwIfAnyFailed();
  }
}
```

For development EAS, replace `launchArgs` with the two Dev Auth arguments above.
For an instance-scoped facade, use `UnifiedGameServices(providers: [epic])`
instead of global initialization. The stable provider ID is `epic`.
Facade sign-in and writes return `MultiProviderOperationResult`; inspect `failed`
or call `throwIfAnyFailed()` rather than assuming `await` throws provider failures.
Pass `UnifiedAchievementTable`, `UnifiedLeaderboardTable`, and `UnifiedStatTable`
to the facade with `ProviderIdMap(epic: 'native_id')` rows, not to the provider.
Unmapped IDs pass through; observe the board/stat distinction below.
The bundled Flutter example is a direct-provider diagnostic UI, not facade
registration: its host maps `EOS_SDK_DIR` to a binary path and enables logging.
Do not copy its debug/token-display behavior into production.

## 5. Respect operation semantics and lifecycle

- Await sign-in before operations. Advertised capabilities are achievements,
  leaderboards, stats, friends, presence, cloudSave and identityTokens; capability
  checks alone do not establish session permissions or EAS availability.
- `unlockAchievement(String achievementId)` and `getAchievements()` are
  implemented. `incrementAchievement(String achievementId, int steps)` throws
  `PlatformOperationException`; `revealAchievement(String achievementId)` is a
  no-op (EOS shows hidden achievements once unlocked).
  For incremental progress, ingest the configured backing stat instead.
- `setStat(String key, num value)` and `incrementStat(String key, {num by = 1})`
  **ingest**, not overwrite, and truncate values to integers. Stat keys resolve
  through the configured stat mapping; `getStat(String key)` uses it too.
- `submitScore(leaderboardId: 'STAT_NAME', score: 100)` ingests the backing
  **stat name**, while `getLeaderboard('BOARD_ID')` queries the **board ID**.
  Account for that distinction when mapping IDs. Read queries use global ranks;
  `timeScope` and `collection` do not filter EOS results. `getPlayerScore` only
  finds players within the ranks EOS returns, so a missing result does not
  prove the player has no score.
- Cloud calls are `saveData(String slot, Uint8List data)`,
  `loadData(String slot)`, `listSaves()` and `deleteSave(String slot)`;
  there is no `deleteData`. Serialize transfers for each filename. A missing
  load returns null. Import `dart:typed_data` for `Uint8List`.
- `setPresence(RichPresence presence)` maps state/details to online rich text,
  truncated to 255 characters; party sizes and start time are ignored.
  `clearPresence()` clears text and sets offline; call before signing out if needed.
- Keep the Dart event loop responsive. The provider pumps `EOS_Platform_Tick`
  in a timer and while waiting for operations; `tickInterval` defaults to 100 ms.
  The internal operation timeout is 30 seconds, not a configurable constructor
  parameter. Device-ID creation has a special timeout-as-duplicate fallback.
- `signOut()` clears local state and emits an event; it does **not** call
  `EOS_Auth_Logout`, revoke credentials or stop EOS. Do not describe it as logout
  from the Epic account or as token revocation.
- Stop new work and await in-flight operations before shutdown. Give cleanup
  one owner; await `epic.dispose()` exactly once (or let the owning facade do
  so, not both). It stops ticking, releases the platform, calls `EOS_Shutdown`
  and closes events. Never reuse the provider afterwards. Prefer one live Epic
  provider; SDK shutdown and logging have process/static effects.

## 6. Protect credentials and diagnose safely

- Keep client secrets, encryption keys, exchange codes and identity tokens out
  of source control, screenshots, command histories and telemetry. Inject them
  through host configuration/secret management. Environment values and compiled
  defines are not a secrecy boundary; client-shipped secrets remain extractable.
  Use least-privilege client policies, never privileged server credentials.
- Leave `debugLogging: false` normally. **Current auth traces print the token
  argument**, including launcher exchange codes. Logging is static across
  providers. Enable only in controlled development and redact before sharing.
- `Future<String?> getIdentityToken()` copies an EOS Connect ID-token JWT in
  every login mode. Send it securely to your backend; verify signature against
  Epic's JWKS (`https://api.epicgames.dev/auth/v1/oauth/jwks`) plus issuer,
  audience and expiry before trusting `sub` as PUID.
  Decoding the payload in a client is not verification. This path is implemented
  but the 0.2.0 changelog explicitly records no live EOS verification yet.

| Symptom | Check next |
| --- | --- |
| `UnsupportedError` at construction | Desktop target and `isSupported`; do not use the web stub as a runtime. |
| `Failed to load the EOS SDK library` | `libraryPath` is a file, architecture matches, loader dependencies/signing are valid. |
| `EOS_Platform_Create returned null` | Matching product/sandbox/deployment/client values and encryption-key format. |
| `EOS_InvalidRequest` 1012 during EAS | EAS Application, Brand settings, associated client, all three permissions and account access. |
| Unexpected anonymous identity | Both Dev Auth fields, forwarded launcher arguments, empty explicit override. |
| `CapabilityNotSupportedException` for friends/presence/PDS | Use EAS, not Device ID; confirm session identity. |
| Missing encryption-key error | Supply the 64-hex key before constructing the provider. |
| Timeout or missing callbacks | Responsive event loop, live network, reachable Dev Auth Tool, SDK/bindings compatibility. Do not blindly retry stat writes. |
| Empty stats/ranks/achievements | Correct deployment, policy, definitions, IDs and aggregation; allow backend propagation and the ranks EOS returns. |

## 7. Report validation honestly

- [ ] Review dependency versions, supported target, credentials/policy, selected
  auth mode and shutdown ownership without exposing secret values.
- [ ] Distinguish static/unit checks from live validation. The package's existing
  tests cover provider ID, capabilities, stored credentials, initial signed-out
  state and unsupported achievement operations; they do **not** load EOS.
  Host mocks/fakes can check wiring and error handling, not SDK ABI, credentials,
  Portal permissions, callbacks or backend persistence.
- [ ] With permission, use a real desktop host, actual EOS library and dedicated
  test deployment. Record OS/architecture, SDK version and mode for each result.
  Exercise Device ID, Dev Auth and Launcher separately when shipping those modes;
  verify identity and a fresh user's Connect creation, not just construction.
- [ ] In EAS, confirm profile/friends and presence from another authorized test
  account. Unlock a test achievement; ingest/read a stat and query its board.
  Round-trip cloud bytes, list the slot, `deleteSave`, then confirm absence.
  Validate identity tokens on the backend, not merely by displaying a JWT.
- [ ] Check negative paths: absent runtime, invalid environment/policy, anonymous
  EAS-only calls, missing PDS key, and clean shutdown without a lingering timer.
- [ ] State which checks actually ran and which remain unverified. Never label
  mocks as EOS integration success. For docs-only work, do not run tests/builds.