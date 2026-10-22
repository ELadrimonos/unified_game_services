---
name: unified-game-services-per-store-builds
description: >-
  Use when a game built on unified_game_services 0.2.0 ships to several stores
  or platforms (Steam, Epic, Game Center, Google Play, web, mobile) and needs
  separate entry points, per-store native libraries, store-specific assets or
  credentials, web vs native separation, tree-shaking of FFI providers, Flutter
  flavors, or a release CI matrix.
---

# Build one game for several stores

Work in the consumer game, not in this skill's directory. The goal: each
artifact contains only its own store's provider code, native runtime, assets and
credentials. Respect the requested scope: for planning or documentation, do not
run builds or download SDKs.

## 1. Inventory the targets first

List every artifact as `{store} × {os}` before writing code, e.g.
`steam × windows`, `steam × linux`, `epic × windows`, `web`, `android`,
`ios`. For each, record the providers it registers:

| Provider package | Runs on | Needs a native runtime in the artifact |
| --- | --- | --- |
| `_steam` | Windows/macOS/Linux | `steam_api64.dll` / `libsteam_api.dylib` / `libsteam_api.so` |
| `_epic` | Windows/macOS/Linux | `EOSSDK-Win64-Shipping.dll` / `libEOSSDK-Mac-Shipping.dylib` / `libEOSSDK-Linux-Shipping.so` |
| `_game_center` | macOS/iOS | none (system GameKit; signed bundle) |
| `_google_play_flutter` | Android (REST elsewhere, incl. web) | `play-services-games-v2` via Gradle |
| `_gamejolt`, `_playfab`, `_google_play_rest` | everywhere, incl. web | none (REST) |

A store build registers only that store's provider plus any portable REST/backend
providers. Never ship one "universal" desktop build containing both the Steam
and EOS runtimes: they are license-gated and each may only ship under its own
agreement.

## 2. Pick the separation strategy

| Situation | Strategy |
| --- | --- |
| Pure Dart / CLI / custom engine host | One entry point per store (`bin/main_steam.dart`, `bin/main_epic.dart`). |
| Flutter desktop, Windows/Linux | One entry point per store, `flutter build windows --target=lib/main_steam.dart`; copy native libs post-build. |
| Flutter macOS / iOS / Android | Flavors (Xcode scheme + `.xcconfig`, Gradle product flavors) plus a per-flavor `--target`. |
| One shared entry point must also build for mobile/web | `const bool.fromEnvironment` guards so FFI providers are tree-shaken. |
| Local development only | Runtime `String.fromEnvironment('STORE')` switch is acceptable; nothing is shaken. |

A runtime check (`Platform.isWindows`, `SteamProvider.isSupported`, a throwing
constructor) prevents crashes but does **not** remove code: the FFI closure stays
in the bundle. Only an unreachable reference (separate entry point or a
const-`false` guard) removes it. `dart.library.io` distinguishes web from native,
never desktop from mobile.

## 3. Entry-point layout

Keep store choice at the edge. Every entry point builds its provider list and
calls one shared bootstrap; gameplay code never imports a provider package.

```
lib/
  main_steam.dart     # imports only the Steam provider
  main_epic.dart      # imports only the Epic provider
  main_web.dart       # REST providers only
  main_mobile.dart    # Game Center / Google Play
  src/bootstrap.dart  # shared: tables, initialize, runGame()
  src/progression_ids.dart
```

```dart
// lib/main_steam.dart
import 'package:unified_game_services_steam/unified_game_services_steam.dart';
import 'src/bootstrap.dart';

Future<void> main() => bootstrap(providers: [SteamProvider(appId: kSteamAppId)]);
```

```dart
// lib/src/bootstrap.dart — must not import any provider package.
import 'package:unified_game_services/unified_game_services.dart';
import 'progression_ids.dart';

Future<void> bootstrap({
  required List<UnifiedGameServicesPlatform> providers,
}) async {
  GameServices.initialize(
    providers: providers,
    achievements: kAchievements,
    leaderboards: kLeaderboards,
    stats: kStats,
  );
  await runGame(); // sign-in happens in the background; see the lifecycle skill
}
```

If a shared file must reference a desktop provider, guard it:

```dart
const kEnableSteam = bool.fromEnvironment('ENABLE_STEAM');
if (kEnableSteam) providers.add(SteamProvider(appId: kSteamAppId));
```

Reference each FFI provider **only** inside its guard. One reference outside
(a type check, `GameServices.provider<SteamProvider>()` in shared code, an
import used elsewhere) re-anchors the symbol and defeats the shake. Provider
extras belong in the store entry point or a store-only file.

## 4. Assets, native libs and credentials

- **Native runtimes are never bundled by pub or Flutter.** Copy them in a
  post-build step of the matching artifact only: next to `Runner.exe` /
  the Linux bundle's `lib/`, or into `Contents/Frameworks` (macOS, with a
  matching rpath) via an Xcode Copy Files phase gated per configuration.
- `steam_appid.txt` is development-only. Release Steam builds omit it; no other
  store's build contains it.
- **Flutter assets** in `pubspec.yaml` are global. Where `--flavor` works
  (Android, iOS, macOS), scope store-only assets with
  `- path: assets/steam/` + `flavors: [steam]`. On Windows/Linux, keep
  store-only assets (store logos, legal text, EULA) out of `pubspec.yaml` and
  copy them in the post-build step, or keep them tiny and select at runtime.
- **Credentials per store** come from `--dart-define-from-file=config/steam.json`
  (or CI secrets), read with `const String.fromEnvironment`. Keep those files
  out of git. Anything compiled in is extractable: ship only client-grade
  identifiers (app IDs, EOS client credentials meant for game clients); never
  publisher Web API keys or server secrets.
- Web artifacts register only REST providers. Importing Steam/Epic on web
  compiles (inert stub) but constructing them throws `UnsupportedError`.

## 5. Release pipeline

Use a CI matrix over `{store} × {os}`; each job builds its target, copies its
own runtime, and uploads one artifact:

```yaml
strategy:
  matrix:
    include:
      - { store: steam, os: windows-latest, target: lib/main_steam.dart }
      - { store: epic,  os: windows-latest, target: lib/main_epic.dart }
      - { store: steam, os: ubuntu-latest,  target: lib/main_steam.dart }
steps:
  - run: flutter build ${{ runner.os == 'Windows' && 'windows' || 'linux' }} --release --target=${{ matrix.target }} --dart-define-from-file=config/${{ matrix.store }}.json
  - run: dart run tool/copy_runtime.dart --store ${{ matrix.store }}   # fetches the runtime from a private artifact store
```

Store SDK runtimes in a private artifact store or encrypted CI cache, never in
the repository or a public release.

## 6. Verify each artifact

- [ ] Inspect the built output: only the expected runtime is present; no
  `steam_appid.txt` in release; the other store's runtime is absent.
- [ ] For guarded or per-entry builds, confirm the shake: compare sizes with the
  flag on/off, or search the compiled output for the other provider's class
  names.
- [ ] `flutter build web` / `dart compile js` succeeds for the web entry point.
- [ ] Launch each artifact the way the store launches it (Steam client, Epic
  Launcher with exchange code, TestFlight, Play internal track) and confirm
  sign-in. A development run is not release proof; report untested artifacts
  as unverified.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| `if (Platform.isWindows) SteamProvider(...)` to "exclude" Steam from mobile | Runtime gates do not shake code; use an entry point or const guard. |
| Shared bootstrap imports every provider | Move provider imports into the store entry points. |
| Both Steam and EOS DLLs in one desktop zip | One runtime per store artifact. |
| Relying on `--flavor` for Windows/Linux assets | Use `--target` + post-build copy. |
| Secrets in `--dart-define` treated as safe | Compiled constants are readable; keep server secrets on a backend. |
