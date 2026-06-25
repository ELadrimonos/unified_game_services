# game_center_example

Flutter host app for the `unified_game_services_game_center` provider. macOS + iOS.

> **⚠️ Not yet runtime-verified.** Game Center auth was only reachable up to the
> server handshake with a **free** Apple account: GameKit then rejects sign-in
> with `GKErrorDomain Code=15` / server `5019` — *"no game matching descriptor"* —
> because the bundle id is not registered as a Game Center–enabled app in App
> Store Connect. That registration requires a **paid Apple Developer Program
> membership ($99/yr)**, which was not available here. The entitlement wiring and
> the pure-Dart FFI path are confirmed working (the error advanced from
> *missing entitlement* → *app not recognized*); full auth + achievements +
> leaderboards still need a paid account + an App Store Connect record to verify.

## Why a Flutter app

The provider itself is pure-Dart GameKit FFI (no Flutter). But GameKit only
presents its **windows** — the sign-in sheet and the Game Center dashboard —
from a view controller the *host app owns*, and it needs a real signed app
bundle with a pumped run loop. A bare `dart run` can't supply that, so this
Flutter app is the harness that lets you actually see the windows.

Split of responsibilities:

- **Pure-Dart provider** (`UnifiedGameServicesPlatform.instance`) — sign-in
  state, achievements, leaderboards, score submission, player profile. Over FFI.
- **Host method channel** `game_center_example/native` (`lib/game_center_native.dart`
  ↔ `macos/Runner/MainFlutterWindow.swift`, `ios/Runner/AppDelegate.swift`) —
  presents the two native windows only: `authenticate` (sign-in sheet) and
  `showDashboard` (`GKGameCenterViewController`).

## One-time setup (signing + Game Center)

GameKit refuses to run without a real, signed bundle whose id is registered as a
Game Center–enabled app in App Store Connect.

1. Open the runner in Xcode:
   - macOS: `open macos/Runner.xcworkspace`
   - iOS: `open ios/Runner.xcworkspace`
2. **Signing & Capabilities** → pick your Team, set a unique **Bundle Identifier**.
3. Add the **Game Center** capability (the `com.apple.developer.game-center`
   entitlement is already in `macos/Runner/*.entitlements`; on iOS the capability
   wires `ios/Runner/Runner.entitlements` for you).
4. In App Store Connect create an app with that bundle id, then define the
   achievement and leaderboard ids used in `lib/main.dart`:
   - achievement `com.example.game.firstwin` (unified key `first_win`)
   - leaderboard `com.example.game.highscores` (unified key `global`)
   Swap these for your own ids in the `GameCenterProvider.registerWith(...)` call.

Deployment targets are bumped to macOS 11.0 / iOS 14.0 — `GKGameCenterViewController(state:)`
requires them.

## Run

```sh
flutter run -d macos
flutter run -d ios
```

Tap **Authenticate (window)** first — the native sign-in sheet appears, then the
Dart provider resolves the player. The remaining buttons exercise the provider;
**Show dashboard (window)** presents the native Game Center UI.
