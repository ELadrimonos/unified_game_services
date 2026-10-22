---
name: unified-game-services-game-center-setup
description: >-
  Use when configuring unified_game_services_game_center 0.2.0 on macOS or iOS,
  setting up signing and App Store Connect, wiring GameKit authentication in a
  host app, or diagnosing entitlement, sign-in UI, and main-run-loop failures.
---

# Configure Apple Game Center

## Check the host first

1. Ask whether the host is Flutter or a custom engine, whether it targets macOS
   or iOS, and whether it has a registered bundle ID and Apple development team.
2. Require macOS/iOS. Check `GameCenterProvider.isSupported` before construction;
   other platforms throw `UnsupportedError`. A web-safe import is not web support.
3. Keep this provider pure Dart: it uses GameKit through Objective-C FFI, not a
   Flutter plugin. Native window presentation belongs to the host application.
4. Use Dart 3.12+ and a native-assets-capable build. Install the Apple build
   toolchain (Xcode for iOS; `clang` via Xcode/Command Line Tools for macOS).
   The build hook compiles generated Objective-C block trampolines. Consumers do
   not regenerate bindings or download a separate GameKit runtime: GameKit comes
   from the OS. Do not copy system frameworks into the package.
5. Run inside a correctly signed `.app`/`.ipa` with a pumped main run loop.
   Bare `dart run` is not a valid authentication smoke test. Flutter/AppKit hosts
   provide a run loop; custom hosts must keep the main thread's run loop alive
   without blocking Dart work or native completion handlers.

## Configure Apple services

1. Use an Apple Developer Program team with access to App Store Connect. A free
   personal signing team alone is insufficient for the registered service setup.
2. Register the app's explicit bundle ID and create the matching App Store Connect
   app record. Enable Game Center for the app.
3. In Xcode's Signing & Capabilities, select the correct team, use the same bundle
   ID, and add Game Center. Verify the signed target carries
   `com.apple.developer.game-center` and matching provisioning for each build
   configuration. Do not merely edit an unused entitlement file.
4. Create the achievements and leaderboards in App Store Connect. Complete their
   required configuration and use their exact identifiers in the Dart ID tables.
   Example IDs below are placeholders, not preconfigured Apple resources.
5. Arrange a Game Center test account and test environment appropriate to the
   signed build. Never commit signing keys, provisioning secrets, or account
   credentials to the repository.

## Arrange authentication UI outside the provider

The player must already be authenticated, or the host must present the view
controller supplied by `GKLocalPlayer.authenticateHandler` from its own native
window/view controller. Wait for host authentication to finish before invoking
the Dart provider; do not race two handlers for the same local player.

`GameCenterProvider.signIn()` does **not** present that UI. It throws
`SignInFailedException` when GameKit requests a view controller. The provider has
no `authenticate` window helper or `showDashboard` API. A Flutter host may own a
method channel for those windows, but do not add Flutter/platform-channel
dependencies to the provider itself.

The repository's Game Center example demonstrates host-owned authentication and
dashboard presentation. It documents that full end-to-end authentication and
game operations have **not** yet been runtime-verified with a registered paid
account. Do not present its entitlement/FFI handshake checks as proof of success.

## Wire the 0.2.0 API

Add `unified_game_services: ^0.2.0` and
`unified_game_services_game_center: ^0.2.0` to the app's dependencies. Create
`GameCenterProvider()` with **no mapping arguments**. ID tables belong on the
facade; do not use old `achievementIds`, `leaderboardIds`, or `registerWith` APIs.

Call this from a signed, running host **after** native authentication. It performs
real test-account writes; use an achievement and leaderboard intended for testing.

```dart
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_game_center/unified_game_services_game_center.dart';

Future<void> verifyGameCenter() async {
  if (!GameCenterProvider.isSupported) {
    throw UnsupportedError('Game Center requires macOS or iOS.');
  }
  final services = UnifiedGameServices(
    providers: [GameCenterProvider()],
    achievements: UnifiedAchievementTable({
      'first_win': ProviderIdMap(gameCenter: 'com.example.game.firstwin'),
    }),
    leaderboards: UnifiedLeaderboardTable({
      'global': ProviderIdMap(gameCenter: 'com.example.game.highscores'),
    }),
  );
  try {
    (await services.signIn()).throwIfAnyFailed();
    (await services.unlockAchievement('first_win')).throwIfAnyFailed();
    (await services.submitScore(
      leaderboardId: 'global',
      score: 4200,
    )).throwIfAnyFailed();
    final board = await services.getLeaderboard('global', maxResults: 10);
    print(board);
  } finally {
    (await services.dispose()).throwIfAnyFailed();
  }
}
```

For a long-lived app, retain the facade until host shutdown instead of disposing
after every operation. The global alternative is
`GameServices.initialize(providers: [...], achievements: ..., leaderboards: ...)`.
Await disposal before `GameServices.reset()`; reset alone does not free resources.
Facade sign-in and writes capture provider failures in result objects: checking
only whether `await` threw will miss failures. Inspect `failed` or use
`throwIfAnyFailed()` as above.

## Respect the supported feature set

- The provider advertises achievements and leaderboards only. Achievement
  progress is represented as steps out of 100, corresponding to GameKit percent.
- Do not promise stats, friends, cloud saves, rich presence, lobbies, or a native
  overlay through this provider. GameKit having an API does not mean this package
  implements it.
- The current provider does not override `signOut`; do not use it as an OS logout
  mechanism (the inherited method throws `UnimplementedError`). Dispose resources
  on shutdown; account management belongs to the OS/host.

## Troubleshoot by layer

| Symptom | Check next |
| --- | --- |
| Unsupported platform | Target macOS/iOS and guard construction. |
| Native-assets/clang build failure | Apple toolchain and supported Dart/Flutter build, not binding regeneration. |
| Missing entitlement / not authenticated | Actual signed bundle, provisioning, Game Center capability, and account state. |
| `GKErrorDomain Code=15`, server `5019`, "no game matching descriptor" | Bundle ID, team, App Store Connect record, and Game Center configuration. Do not bypass signing. |
| Sign-in requires UI | Present authentication in the host, wait for success, then call provider sign-in. |
| Timeout (60s sign-in, 30s reads) | Main run loop, callbacks, connectivity, and app registration; do not just raise timeouts. |
| Unknown leaderboard / empty data | Exact App Store Connect IDs, ID table mappings, configured resources, and test account. |

## Acceptance checklist

- Analyze the host and verify its signed entitlements for the intended target.
- On a configured macOS/iOS host, authenticate, retrieve a real profile, unlock
  a test achievement, submit a test score, and read results back.
- Exercise cancelled/required authentication UI and bad-resource errors. Confirm
  facade result failures are surfaced rather than silently ignored.
- Dispose at shutdown; distinguish successful build/FFI loading from successful
  Game Center operations. If Apple account access is unavailable, report live
  verification as blocked rather than claiming end-to-end success.