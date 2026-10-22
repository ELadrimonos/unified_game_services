---
name: unified-game-services-steam-setup
description: >-
  Use when configuring unified_game_services_steam 0.2.0 in a Dart desktop app,
  wiring SteamProvider into the GameServices facade, preparing Steamworks native
  libraries and an app ID, or diagnosing Steam initialization and callback failures.
---

# Configure Steam game services

Set up the consumer application, not the directory containing this installed
skill. These instructions are self-contained; no repository checkout is needed
for the normal setup. Do not add Flutter plugins or platform-channel glue.
Respect the requested scope: for documentation-only work, do not run setup,
dependency resolution, tests, builds, or live operations.

## 1. Establish prerequisites

- Confirm the target OS, CPU architecture, Dart version, launch method, working
  directory, app ID, and whether this is development or a release build.
- Require Dart `^3.12.0` and Windows, macOS, or Linux. The package uses pure-Dart
  FFI and depends on `steamworks ^0.4.10`; it does not require Flutter.
- Check `SteamProvider.isSupported` before construction. It is false on web and
  mobile. The public import is web-safe, but the web constructor throws
  `UnsupportedError`; the native constructor rejects Android/iOS too. Prefer
  store-specific entry points when Steam must be excluded entirely.
- Require the Steam client running and logged in. The player is that client's
  user; do not request Steam usernames/passwords or implement an OAuth flow.
- Obtain an authorized Steamworks runtime for the target OS and architecture.
  This provider does not bundle it. A full Steamworks SDK is needed for binding
  regeneration, not the normal runtime-copy setup. Obtain the SDK through your
  Steamworks account; never assume anonymous download access or invent an SDK
  version requirement that this package does not declare.
- Use app ID `480` (Spacewar) only for a smoke test. For your game, use its real
  Steamworks app ID, an entitled test account, and published/configured API
  names for achievements, integer stats, and leaderboards. Spacewar IDs are not
  your game's configuration.

## 2. Install and prepare the native loader

In the consumer's `pubspec.yaml`, align the facade and provider:

```yaml
dependencies:
  unified_game_services: ^0.2.0
  unified_game_services_steam: ^0.2.0
```

From the consumer directory containing `.dart_tool/package_config.json`, run:

```sh
dart pub get
dart run unified_game_services_steam:setup --app-id 480 --output .
```

The setup command copies the host OS library from the resolved `steamworks`
package's `example` directory and writes `steam_appid.txt`. It is not a
cross-compiler, SDK downloader, or Steamworks dashboard configurator. It can
overwrite destination files: confirm the output directory and app ID first.
In a workspace, run it where the resolved package configuration actually lives.

| Target | Runtime | Development loader configuration |
| --- | --- | --- |
| Windows | `steam_api64.dll` | Keep it beside the executable / in the run directory. |
| macOS | `libsteam_api.dylib` | Set `DYLD_LIBRARY_PATH` to the library directory. |
| Linux | `libsteam_api.so` | Set `LD_LIBRARY_PATH` to the library directory. |

For example, with the library in the consumer's current directory:

```sh
# macOS
DYLD_LIBRARY_PATH="$PWD" dart run bin/main.dart
# Linux
LD_LIBRARY_PATH="$PWD" dart run bin/main.dart
```

Replace `bin/main.dart` with the actual entry point. On macOS/Linux, merely
placing the library in the working directory does not make the loader find it.
In a JetBrains run configuration, set both the working directory and the loader
environment variable. Keep the dev `steam_appid.txt` in that working directory,
and keep its value consistent with `SteamProvider(appId: ...)`.

For releases, supply the real app ID in code, omit `steam_appid.txt`, and ship
the authorized redistributable with the app under your Steamworks agreement.
Configure the packaged loader/rpath as needed; do not rely on a developer's
environment or assume an adjacent library alone works on every OS. Test the
actual Steam-launched artifact on every supported OS/architecture.

## 3. Wire facade 0.2.0

Construct the provider and pass it to `GameServices.initialize`. Do not use
`registerWith`: it was removed in 0.2.0. This minimal, read-only smoke program
uses one provider; its `finally` block owns that provider's shutdown:

```dart
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

Future<void> main() async {
  if (!SteamProvider.isSupported) return;

  final steam = SteamProvider(appId: 480);
  final services = GameServices.initialize(providers: [steam]);
  try {
    (await services.signIn()).throwIfAnyFailed();
    final player = await steam.getCurrentPlayer();
    if (player == null) {
      throw StateError('Steam did not initialize; inspect sign-in diagnostics.');
    }
    print(player.displayName);
  } finally {
    final disposal = await services.dispose();
    GameServices.reset();
    disposal.throwIfAnyFailed();
  }
}
```

Keep the provider reference, or obtain it with
`GameServices.provider<SteamProvider>()` (nullable). Use the facade for portable
operations, for example `services.unlockAchievement('ACH_WIN_ONE_GAME')` or
`services.submitScore(leaderboardId: 'Feet Traveled', score: 1500)` on Spacewar.
Only perform these writes with permission: they change real player data.

For method-level native diagnostics, call `await steam.signIn()` directly and
inspect its exception. Facade sign-in and writes return
`MultiProviderOperationResult`: inspect `failed`/`succeeded` or call
`throwIfAnyFailed()`. Simply awaiting them does not throw captured provider errors.

For portable IDs, pass `achievements: UnifiedAchievementTable({'first_win':
ProviderIdMap(steam: 'ACH_WIN_ONE_GAME')})` and equivalent
`UnifiedLeaderboardTable`/`UnifiedStatTable` values to the facade, not to the
provider constructor. The mapping key is `steam`; unmapped IDs pass through.
The facade handles reverse mapping on reads. `GameServices.reset()` only clears
the global reference; it does not dispose native resources.

## 4. Own the lifecycle

- `SteamProvider({int? appId})` initializes lazily. Await sign-in before stats
  or achievements: `Future<PlayerProfile?> signIn()` warms the player's stats.
  Omitting `appId` uses the development app ID file.
- The provider runs callbacks every 50 ms until disposal. Keep the Dart event
  loop responsive; do not add a second pump or block it with synchronous input
  or long-running work while awaiting Steam callbacks.
- Subscribe to `steam.events` before operations whose events matter. Retain and
  cancel subscriptions during shutdown; stop new work and finish pending
  operations before disposal. Use one Steam runtime owner, not competing
  providers across isolates.
- In a long-running game, keep the provider alive for the session, rather than
  disposing after login as the short smoke program does. Ensure exactly one
  shutdown owner awaits `Future<void> dispose()`; do not also dispose it through
  another owner. Disposal stops the pump, leaves watched lobbies, shuts down
  Steam, and closes events. Do not reuse the disposed instance.
- `signOut()` throws `PlatformOperationException`; users switch accounts in
  the Steam client. `isSignedIn()` reports local SDK initialization, not live
  authentication or connectivity. `getCurrentPlayer()` is null before init.
- Gate features with `steam.supports(GameCapability.achievements)` and the
  equivalent capability. Advertised capabilities are achievements, leaderboards,
  stats, cloudSave, friends, presence, identityTokens, lobbies, invitations;
  not matchmaking. Capability support does not imply every operation exists:
  `incrementAchievement(String, int)` throws; `revealAchievement(String)` is a
  no-op. Use configured backing integer stats for incremental achievements.

## 5. Diagnose in this order

| Symptom | Action |
| --- | --- |
| `UnsupportedError` constructing Steam | Exclude Steam on web/mobile; check `isSupported` before construction. |
| Missing native library / init failure | Verify trusted library, process architecture, loader path, and working directory first. Inspect the direct `SignInFailedException.message` and `cause`. |
| `SteamRestartRequiredException` | Steam requested a relaunch. Flush application state and terminate the old process cleanly; the provider never calls `exit()`. Do not retry in a loop. |
| Other `SignInFailedException` | Check Steam is logged in, app ID/file consistency, launch context, and account access to the app. |
| `NetworkException` after about 10 seconds | Async call-results timed out: check client connectivity and a responsive event loop. Do not replace the timeout with an infinite wait. |
| Auth-ticket `PlatformOperationException` | Ticket requests use their own failure/10-second timeout path; inspect the message rather than treating every timeout as `NetworkException`. |
| Achievement rejected / missing data | Await sign-in; check the exact Steamworks API name, app ID, published configuration, ownership and archived/DLC restrictions. |
| Float stats or step achievements fail | This implementation uses 32-bit integer stats; `setStat(String, num)` truncates. There is no direct step-achievement API. |
| ABI errors on non-Windows targets | Verify runtime and generated bindings match the target; do not infer ABI correctness from a successful import or unit test. |

Published bindings are Windows-oriented. Existing package documentation differs
on whether regeneration is always required on macOS/Linux; do not promise
universal compatibility. If regeneration is needed, obtain the authorized SDK,
generate target-specific bindings with `steamworks_gen`, and point the consumer's
`dependency_overrides.steamworks.path` to that generated package. Review generator
dependency changes and validate with the real runtime. Do not blindly override
dependencies or download untrusted binaries to suppress an ABI failure.

## 6. Protect credentials and player data

- Never commit SDK archives/headers, native libraries, or `steam_appid.txt`.
  Keep development artifacts out of release packages except the authorized
  runtime. An app ID is configuration, not a secret or proof of identity.
- Never embed publisher Web API keys in the client or logs. Treat auth-ticket
  bytes/hex as credentials; send them only to your backend over TLS, without
  logging or caching them. Do not trust client-reported Steam IDs on a server.
- `int getSteamId64()` is for local identity display. For server trust, use
  `Future<SteamAuthTicket> getWebApiAuthTicket({String? identity})`; send
  `ticket.hex` to your backend. The backend verifies it with
  `ISteamUserAuth/AuthenticateUserTicket`, its publisher key, the expected app
  ID and, if supplied, the agreed identity. Link only the verified Steam ID to
  an authenticated backend account; reject failed verification.
- Release the explicit ticket with `void cancelAuthTicket(int handle)` after
  backend consumption, including failure cleanup, before provider disposal.
  Alternatively, `Future<String?> getIdentityToken()` returns ticket hex with
  automatic cancellation after two minutes: verify immediately, never cache it.
- Do not reset achievements/stats or delete cloud saves without explicit
  approval. `resetAllStats(includeAchievements: true)` affects real data.

## 7. Report verification honestly

- [ ] Confirm versions, platform guard, app ID, working directory, loader path,
  and release exclusion of the dev app ID file.
- [ ] **Static / unit / mocks:** review wiring and lifecycle; where authorized,
  run the consumer's targeted tests. Existing provider tests cover capabilities,
  pre-init state, unsupported sign-out, error mapping, and deferred unregistering.
  They do not call live Steam operations. Mocks validate application behavior,
  not native loading, ABI compatibility, authentication, or Steam persistence.
- [ ] **Real runtime:** on each target OS/architecture, launch with the actual
  Steam client and runtime; await sign-in and read the expected player profile.
  Confirm clean shutdown and no duplicate process after a requested relaunch.
- [ ] **Real features, with permission:** write/read back a test achievement or
  score; exercise cloud save, lobbies/invitations with another account, and
  backend ticket verification only if used. Use disposable test data and record
  which app/account/environment was exercised without exposing credentials.
- [ ] **Release:** test the packaged Steam launch without `steam_appid.txt` or
  development loader variables. A Spacewar development run is not release proof.
- [ ] Summarize changed files and checks actually executed. Separate mocked,
  static, live, and unverified results; name missing runtime/SDK/account access
  as blockers rather than reporting success. Never claim all-platform support
  from one machine's smoke test.