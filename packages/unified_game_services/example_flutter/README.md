# unified_game_services — multi-provider Flutter demo

A "real" Flutter app that drives the **unified facade** over several providers at
once — **GameJolt, Google Play Games, Steam and Epic Online Services** — and
shows the core promise of the API: *each provider is registered only on the
environments where it can actually run*, and a single facade call **fans out**
to every provider that supports the capability.

This is a standalone Flutter project (not a pub-workspace member). It depends on
the in-repo packages via path overrides.

## What it demonstrates

- **One API, many providers.** `UnifiedGameServices(providers: [...])` wraps
  whichever providers were built. `signIn()`, `unlockAchievement()`,
  `submitScore()`, `setStat()`, `setPresence()`, `saveData()` fan out to every
  capable provider; reads come from the primary (first) provider.
- **Environment respect.** Steam and Epic are `dart:ffi` (desktop only). They
  sit behind a `dart.library.io` conditional import (`services/native_providers*
  .dart`), so a **web build never pulls `dart:ffi`** — verified with
  `flutter build web`. On Android/iOS they're linked but never instantiated (no
  Steamworks / EOS runtime there) and the UI shows *why* they were skipped.
  GameJolt (REST) and Google Play (JNI on Android, REST elsewhere) run
  everywhere.
- **Capability matrix.** A live grid of capability × active-provider, read off
  each provider's `capabilities` getter — so you can see exactly which providers
  a given fan-out call will hit.
- **Merged event stream.** The facade's `events` stream from all providers,
  rendered in the activity log.

## Provider × environment

| Provider     | Transport                              | Web | Android | Desktop |
|--------------|----------------------------------------|:---:|:-------:|:-------:|
| GameJolt     | REST (pure Dart)                       | ✓   | ✓       | ✓       |
| Google Play  | JNI on Android, REST elsewhere         | ✓   | ✓       | ✓       |
| Steam        | Steamworks C API via `dart:ffi`        | —   | —       | ✓       |
| Epic         | EOS C SDK via `dart:ffi`               | —   | —       | ✓       |

> Only **desktop** runs all four at once. That is the showcase target.

## Run it

```bash
cd packages/unified_game_services/example_flutter
flutter pub get

flutter run -d macos     # desktop: all four providers can coexist
flutter run -d chrome    # web: GameJolt + Google Play (REST) only
flutter run -d <android> # Android: GameJolt + Google Play (native) only
```

Open **⚙ Configure providers**, enable the ones you want, paste credentials
(stored locally via `shared_preferences` — nothing is committed), Save, then use
the action buttons.

## Credentials / runtime each provider needs

- **GameJolt** — `gameId`, `privateKey`, `username`, `userToken` (Game API).
- **Google Play** — off Android, a **Desktop-app OAuth client id** for the
  loopback sign-in flow (desktop only; a browser can't bind the loopback
  socket, so the web REST path needs a pre-brokered token). On Android the
  native client brokers the token — no fields needed.
- **Steam** — a running Steam client + the Steamworks native library next to the
  executable; optional `appId` (or a `steam_appid.txt`).
- **Epic** — `EpicCredentials` (ProductId / SandboxId / DeploymentId / ClientId /
  ClientSecret, + `encryptionKey` for cloud save) from the Dev Portal, the EOS
  runtime library on the load path, and an EAS login (Dev Auth Tool `host:port`
  + credential name is the easiest in development).

Unified→native id maps (one `unified=native` per line) let a single facade call
hit every provider with its own achievement/leaderboard ids.

## Per-store builds (Steam-only, Epic-only, …)

This demo toggles every provider **at runtime** (the config screen) to show them
side by side. A shipping game does the opposite: one build per store, each
registering **only that store's provider**. You don't need this app's config
screen for that — and, importantly, you rarely need Flutter **flavors** either.

Because this is a federated plugin, "Steam-only" just means "register only
`SteamProvider`" — a provider you never construct never runs. So per-store builds
are really two mechanical problems:

1. **Register one provider** — a compile-time entry point per store.
2. **Bundle that store's native lib** — the only thing that genuinely differs.

### Why not just `--flavor`?

The FFI stores (Steam, Epic) are **desktop-only**, and Flutter's `--flavor`
support is solid on Android but weak/absent on desktop (macOS needs hand-authored
Xcode schemes; Windows/Linux have no flavor concept). Steam/Epic never run on
Android — so for them, **separate entry points + a packaging step** beat flavors.
Keep flavors for the Android/mobile axis (e.g. a Google Play vs. sideload
variant), not for the FFI desktop stores.

### 1. One entry point per store

```dart
// lib/main_steam.dart
import 'package:flutter/material.dart';
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

void main() {
  final services = UnifiedGameServices(providers: [
    SteamProvider(appId: 480, achievementIds: {'first_win': 'ACH_WIN_ONE_GAME'}),
  ]);
  runApp(MyGame(services));
}
```

```dart
// lib/main_epic.dart — same shape, only EpicProvider + EpicCredentials
```

Build each explicitly; Dart tree-shaking drops the other store's provider code:

```bash
flutter build macos   -t lib/main_steam.dart
flutter build windows -t lib/main_epic.dart
```

Google Play in the Steam build? Just don't import/register it — it's REST, no
native lib, zero cost to leave out.

### 2. Bundle the store's native lib

FFI providers `dlopen` a runtime lib the host must ship next to the executable
(license-gated, **not cross-redistributable** — never put Epic's runtime in a
Steam build):

| Store | Lib | Where it must sit |
|-------|-----|-------------------|
| Steam | `libsteam_api.dylib` / `steam_api64.dll` / `libsteam_api.so` (+ `steam_appid.txt`) | **Next to the executable** — `steamworks` opens it by name; `SteamProvider` has no path override |
| Epic  | `libEOSSDK-Mac-Shipping.dylib` / `EOSSDK-Win64-Shipping.dll` / `libEOSSDK-Linux-Shipping.so` | Next to the executable, or `EpicProvider(libraryPath: ...)` |

**macOS** — copy the lib into the app bundle at build time. Add a Run Script
phase to `macos/Runner.xcodeproj` (or a post-build step), e.g.:

```bash
cp "$SRCROOT/../third_party/steam/libsteam_api.dylib" \
   "$BUILT_PRODUCTS_DIR/$EXECUTABLE_FOLDER_PATH/"
```

**Windows** — copy the DLL next to `Runner.exe` (CMake `add_custom_command`
`POST_BUILD`, or your installer script). **Linux** — next to the bundle
executable and/or set `RPATH`.

Steam always loads its lib by name from the executable's directory (no override),
so the copy step above is mandatory. Epic can instead be pointed at an absolute
path:

```dart
EpicProvider(credentials: creds, libraryPath: '/opt/mygame/libEOSSDK-Mac-Shipping.dylib');
```

### Summary

- Per-store = one entry point that registers one provider + bundle its native
  lib. The facade imposes no build system.
- Use `--flavor` for the mobile axis; use entry points + a copy step for the FFI
  desktop stores.
- See [`../example/per_store_builds.dart`](../example/per_store_builds.dart) for
  the same idea as a pure-Dart CLI (`--define=STORE=…` + tree-shaking).
