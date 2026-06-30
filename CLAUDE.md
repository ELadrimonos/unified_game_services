# CLAUDE.md

Guidance for working in this repo.

## What this is

`unified_game_services` — a multi-platform abstraction over game-service providers
(achievements, leaderboards, stats, cloud save, profiles, rich presence) behind one
API. Federated-plugin architecture: an app-facing facade + a shared platform
interface + one package per provider.

## Hard constraint: pure Dart, no Flutter

**No package here depends on Flutter.** The SDK is the Dart SDK (`dart`, not
`flutter`), so the library works in pure Dart apps, CLIs, servers, and other Dart
frameworks — not only Flutter apps.

- Do **not** add `flutter:` to any `pubspec.yaml`, nor `package:flutter/*` imports.
- `plugin_platform_interface` is allowed: it is pure Dart (only depends on `meta`),
  it does **not** pull in Flutter.
- Providers needing platform code must reach the OS via pure-Dart means (FFI, REST,
  process, conditional imports) — never a Flutter plugin dependency.

**Sanctioned exception — `unified_game_services_google_play_flutter`.** This one
adapter package depends on `flutter` + `jni_flutter` (a Flutter plugin) to
auto-resolve the Android `Activity` for plug-and-play registration. It is a
workspace member, so **root resolution (`dart pub get` / `melos bootstrap`) now
requires the Flutter SDK on `PATH`**. The core/provider packages stay pure Dart
(no `package:flutter` / `dart:ui` imports); only this adapter crosses the line,
and Flutter apps opt into it explicitly. Engine/CLI hosts keep using the
pure-Dart packages and supply their own `activityResolver`.

## Layout (melos workspace)

```
packages/
  unified_game_services_platform_interface  # shared API: models, events,
                                             #   exceptions, capabilities, the
                                             #   UnifiedGameServicesPlatform base
  unified_game_services                      # app-facing facade (multi-provider)
  unified_game_services_google_play_rest       # Google Play Games via REST (impl)
  unified_game_services_google_play_android    # Google Play Games via Play Games v2
                                             #   Java SDK (jni); Android-only, writes
  unified_game_services_google_play           # auto: native on Android, REST else
  unified_game_services_google_play_flutter    # Flutter adapter: auto-resolves the
                                             #   Activity (jni_flutter). NOT pure Dart
  unified_game_services_game_center
  unified_game_services_steam
  unified_game_services_epic
  unified_game_services_xbox_pc              # Xbox on PC (GDK); console TBD
  unified_game_services_gamejolt
```

Dependency direction: facade → platform_interface ← each provider. Providers depend
**only** on the platform interface, never on each other or the facade.

## Platform interface (the contract)

`UnifiedGameServicesPlatform` (abstract) is the single contract every provider
extends. Conventions:

- Methods have default bodies that throw `UnimplementedError`. A provider overrides
  **only** the operations it supports — adding a method is non-breaking.
- Each provider declares `Set<GameCapability> get capabilities`. Gate calls with
  `supports(cap)`; unsupported ops should throw `CapabilityNotSupportedException`.
- `UnsupportedUnifiedGameServices` is the default instance (supports nothing).
- Errors are normalized into the `GameServiceException` hierarchy
  (`NotSignedIn`, `SignInFailed`, `CapabilityNotSupported`, `Network`,
  `PlatformOperation`).
- Events are a `sealed GameServiceEvent` hierarchy (switch exhaustively).

## Serialization: dart_mappable (code-gen)

Models use **`dart_mappable`** — not manual `toJson`/hand-rolled `==`/`copyWith`.

- Each model is its own library file with `part 'x.mapper.dart';` and
  `@MappableClass()` (`@MappableEnum()` for enums). The mixin supplies
  `toMap`/`toJson`/`copyWith`/`==`/`hashCode`/`toString`.
- `models.dart` re-exports the model files (it is **not** a `part`-of library).
- After editing any model, regenerate:
  `cd packages/unified_game_services_platform_interface && dart run build_runner build`
- `.mapper.dart` files are generated; they are committed so consumers don't need
  build_runner.
- `Uint8List` has no native JSON mapper — `CloudSave` stores `List<int>` + exposes a
  `Uint8List bytes` getter. Follow that pattern for binary payloads.

## Commands (melos)

```
dart pub get                 # bootstrap the workspace (run at root)
melos run analyze            # dart analyze --fatal-infos, all packages
melos run format             # dart format .
melos run format-check       # CI format gate
melos run test               # dart test in packages that have a test/ dir
```

Single package: `cd packages/<name> && dart test`.

## Two layers: unified + provider-specific

The package deliberately exposes two tiers, and providers must respect the line:

1. **Unified API** — `UnifiedGameServicesPlatform`. Portable across every
   provider. Only model concepts that map cleanly to *most* providers, and
   capability-gate them. If a feature can't be expressed without losing meaning
   on a given provider, it does **not** belong here.
2. **Provider-specific extras** — extra public members on a concrete provider
   (e.g. `GameJoltProvider.openSession`/`startSessionHeartbeat`) for apps that
   target one provider and want its full feature set. Mark them clearly as
   not part of the unified interface, and keep them off
   `UnifiedGameServicesPlatform`.

Rule of thumb: prefer unifying, but never shoehorn. Example: GameJolt
*sessions* are online presence (playing + active/idle), not the free-text
[RichPresence] the unified API models — so they live on `GameJoltProvider`, not
behind `GameCapability.presence`. A dev using the facade gets portability; a dev
holding a `GameJoltProvider` gets everything GameJolt offers.

Reach provider-specific members without keeping the registered reference via the
typed accessor:
`UnifiedGameServicesPlatform.getInstance<GameJoltProvider>().openSession()`
(throwing) or `tryGetInstance<T>()` (nullable).

## Provider scope (MVP)

Pure-Dart-reachable providers ship first:

- **Steam** — Steamworks C API via `dart:ffi`.
- **GameJolt** — REST API.
- **Epic** — EOS C SDK via `dart:ffi` (**SDK-first, not REST**). Unlike Google
  Play (REST is the primary tier), the EOS **Web API does not expose
  achievements/leaderboards/stats/cloud-save/presence over REST** — those are
  SDK-only; REST surfaces just friends(read) + display-name lookups. So the real
  Epic provider is the FFI/C-SDK tier — same "host supplies the runtime" shape as
  Steam/GameCenter: the host ships the EOS runtime lib (`EOSSDK-Win64-Shipping.dll`
  / `libEOSSDK-Mac-Shipping.dylib` / `libEOSSDK-Linux-Shipping.so`) and supplies
  `EpicCredentials` (ProductId/SandboxId/DeploymentId/ClientId/ClientSecret +
  optional EncryptionKey, all from the Dev Portal; secret never committed). EOS
  calls are async, completing inside `EOS_Platform_Tick` (pumped on a `Timer`);
  completions correlate to Futures by the `ClientData` token via a static
  `Pointer.fromFunction` callback. **Implemented:** three sign-in methods —
  anonymous Device ID, `EOS_LCT_Developer` (Dev Auth Tool: pass `devAuthHost`
  `host:port` + `devAuthCredentialName`), and `EOS_LCT_ExchangeCode` (Epic
  Launcher, via `launchArgs`/`exchangeCode`). EAS runs the full **Auth → Connect**
  flow (`EOS_Auth_Login` → `EOS_Auth_CopyUserAuthToken` → `EOS_Connect_Login`
  `EOS_ECT_EPIC`, incl. `EOS_Connect_CreateUser` on first login). After an EAS
  login: **real profile** (`getCurrentPlayer` display name via
  `EOS_UserInfo_QueryUserInfo`/`CopyUserInfo`) and **friends** (`getFriends` via
  `EOS_Friends_QueryFriends`/`GetFriendsCount`/`GetFriendAtIndex`). Plus
  `unlockAchievement`, the achievements **read path** (`getAchievements`:
  QueryDefinitions + QueryPlayerAchievements + CopyPlayerAchievementByIndex),
  stat ingest (`setStat`/`incrementStat`/`submitScore` — EOS leaderboards
  aggregate a backing stat), the **stats read path** (`getStats`/`getStat`:
  QueryStats + CopyStatByIndex) and the **leaderboards read path**
  (`getLeaderboard`/`getPlayerScore`: QueryLeaderboardRanks +
  CopyLeaderboardRecordByIndex; `getPlayerScore` scans the top-100 ranks page —
  a dedicated QueryLeaderboardUserScores path is a TODO). `debugLogging: true`
  (constructor) toggles verbose FFI traces, off by default. **Runtime-verified on
  macOS** via the Dev Auth Tool (real display name + friends list). **Gaps:**
  cloud save (`EOS_HPlayerDataStorage`) and presence (`EOS_HPresence`) — the
  hand-authored stub ships neither interface's function wrappers, so both await a
  bindings regen; **no avatar** (the C SDK exposes none —
  `PlayerProfile.avatarUrl` stays null). EAS also requires
  **Dev Portal config**: an Epic Account Services Application with the client
  associated + scopes (else `EOS_InvalidRequest` 1012). Capabilities advertised:
  achievements, leaderboards, stats, **friends**.
  `lib/src/eos_bindings.dart` is **hand-authored** (so the package compiles
  without the license-gated headers); the Auth/UserInfo/Friends interfaces are
  wired here (the three `EOS_Friends_*` function wrappers were **added by hand** —
  the stub shipped only their option/callback structs). Struct offsets +
  `*_API_LATEST` constants are **unverified** (work at runtime for exercised
  paths) — regen with `tool/regenerate_bindings.sh` (needs `EOS_SDK_DIR`;
  `melos run epic:gen`) for verified ffigen output. SDK headers/libs are NOT
  redistributable — never committed (`.eos-sdk/` gitignored), same posture as
  Steamworks/GameKit.
- **Google Play Games** — three-package `android_*` family. Implemented today:
  `unified_game_services_google_play_rest`, the cross-platform REST tier (Games API
  v1, `games.googleapis.com/games/v1`, over `package:http`). Advertises
  **achievements + leaderboards** only. Stats (GPG `stats` is fixed read-only
  analytics, not writable counters), cloud save (snapshots live in Drive
  appdata — separate API + `drive.appdata` scope) and friends/presence are
  intentionally not advertised. Mirrors the GameJolt template (provider + thin
  `GamesRestClient` + `MockClient` tests + a `.withClient()` seam).

  Auth is a pluggable `AuthStrategy` (the provider performs no OAuth itself):
  `LoopbackOAuthStrategy` (authorization-code + PKCE + `127.0.0.1` loopback,
  desktop/CLI; needs a **Desktop app** OAuth client), `StoredCredentialStrategy`
  (refresh token / brokered access token, server/headless), and
  `NativeSilentTokenStrategy` consuming a host-implemented `NativeTokenProvider`
  — the interface by which an Android host brokers a silent token. Scope
  `https://www.googleapis.com/auth/games`; refresh tokens need
  `access_type=offline` + `prompt=consent`. The REST client refreshes once and
  retries on a single `401`.

  **Phase 2 — `unified_game_services_google_play_android` (JNI bridge verified
  on-device):** committed `jnigen` bindings to the Play Games v2 **Java**
  SDK (`lib/src/playgames_bindings.dart`; regen via `tool/regenerate_bindings.sh`
  — Android SDK + JDK ≤21 + Google Maven). Writes (`unlock`/`increment`/
  `reveal`/`submitScore`) go through the on-device Play Games client and fire
  **native toasts/overlay** (REST can't — it writes to the cloud, bypassing the
  on-device client). Heavy host requirements (engine supplies the
  `JavaVM*`/`JNIEnv` and the `Activity` jobject; APK bundles the
  `play-services-games-v2` aar) — same "host supplies the runtime" shape as
  Steam/GameCenter. **Read-path gap:** jnigen 0.16.0 mis-generates the generic
  `tasks.Task`/`Tasks`, so they're excluded and `Task`-returning methods are
  opaque `JObject` — confirming sign-in / current-player / list reads await a
  jnigen generics fix or a hand-written JNI `Tasks.await`. Keep the runtime
  `jni` aligned with jnigen (jnigen 0.16.0 → jni 1.0.0). **Runtime-verified on a
  Flutter Android host** (`example/`): `signIn()` fires the native Play Games
  sign-in overlay, proving the JNI path reaches the live SDK (VM/Activity wiring
  + bindings work). The example is a Flutter app that *consumes* the pure-Dart
  package (Flutter only in the example pubspec); it gets the runtime + Activity
  jobject from `jni_flutter` (`androidActivity(engineId)`) — the Flutter plugin
  half of `package:jni`, which belongs in the host, never in the package. Write
  toasts and the `Task`-backed read path still need a configured Play Console
  game to fully exercise.

  **`unified_game_services_google_play` (built):** thin factory picking native on
  Android, REST elsewhere — **including web**. The native half (`dart:io` +
  `package:jni`, which is FFI with no web support) sits behind a
  `dart.library.io` conditional import (`native_provider_{io,web}.dart` +
  `native_export_{io,web}.dart`), so `package:jni` never enters a web build and
  the facade compiles to JS (verified via `dart compile js`); on native a
  runtime `Platform.isAndroid` switch picks native on Android, REST otherwise.
  Re-exports the REST API surface unconditionally and the native
  `GooglePlayAndroidProvider` only on `dart.library.io`. The native path takes
  an `activityResolver` **typed `Object Function()`** (not `JObject Function()`)
  so the facade's public API carries no `jni` types and stays web-compilable;
  the io seam casts to `JObject`. The resolver is invoked fresh before each
  native call so a volatile Flutter activity (stale after rotation/
  backgrounding) is never cached. Engine hosts with a stable activity pass
  `() => activity`.

  **`unified_game_services_google_play_flutter` (built):** the sanctioned Flutter
  adapter (depends on `flutter` + `jni_flutter`; see the hard-constraint
  exception above). One call — `GooglePlayGamesFlutter.registerWith(...)` /
  `.create(...)` (same `<Type>.registerWith` idiom as every other provider) —
  auto-resolves the Android `Activity` from the
  running Flutter engine (`androidActivity(PlatformDispatcher.instance.engineId!)`,
  wrapped into the `activityResolver` the factory needs) so app devs never touch
  `jni_flutter` / `PlatformDispatcher`. Re-exports the whole family API. Off
  Android — **including Flutter web** — it delegates to the REST path (`auth`
  required); `jni_flutter` + `dart:ui` activity resolution sit behind a
  `dart.library.io` conditional import (`src/activity_resolver_{io,web}.dart`)
  and the OS pick uses `GooglePlayGames.usesNative` (not `dart:io` `Platform`),
  so the adapter builds for web — verified with `flutter build web` on
  `example/`. Example under `example/` (standalone, not a workspace member).

  **Constraint clarification:** the native package is allowed under no-Flutter.
  `games_services` is banned because it uses Flutter **platform channels**;
  `package:jni`/`jnigen` (pure Dart) reach the Java SDK via JNI — the same
  approach `objective_c` uses for GameKit. "Native Android SDK banned" meant the
  *Flutter* path, not JNI.

- **Game Center** — Obj-C GameKit via `dart:ffi` + `package:objective_c` (pure
  Dart, no Flutter). Implemented: auth + achievements + leaderboards. macOS/iOS
  only. Bindings are ffigen-generated from the SDK GameKit headers and committed
  (`gamekit_bindings.dart`); regenerate with
  `packages/unified_game_services_game_center/tool/regenerate_bindings.sh`
  (macOS + Xcode). GameKit needs the *host* to supply a signed app bundle and a
  pumped main run loop — same shape as Steam needing the Steam client running;
  the package itself stays pure Dart. Do **not** pull in `games_services`
  (Flutter + platform channels — violates the no-Flutter constraint). Stats and
  rich presence have no GameKit equivalent (not advertised); cloud save
  (`GKSavedGame`) and friends are planned.

  ffigen gotchas for GameKit (encoded in `ffigen_gamekit.yaml`): set
  `exclude-all-by-default: true` or the transitive closure explodes to ~1000
  interfaces; do **not** use `member-filter` (it runs after scope creation,
  drops class properties like `GKLocalPlayer.localPlayer`, and doesn't shrink
  the file under exclude-all-by-default); requires ffigen `^21.0.0-dev.0` (20.x
  crashes with a null-scope bug on transitively-referenced stubs). The regen
  script strips ffigen-21's propagated `@Deprecated` annotations, which the
  analyzer rejects on extension-type declarations.

## When adding a provider

1. Implement the subset of `UnifiedGameServicesPlatform` the provider supports.
2. Declare accurate `capabilities`.
3. Map native/SDK errors to `GameServiceException` subtypes.
4. Register via `UnifiedGameServicesPlatform.instance = ...`, or just pass an
   instance to `UnifiedGameServices(providers: [...])`.
5. Keep it pure Dart (see constraint above).

This is also the extension point for **custom providers** outside this repo —
e.g. backing achievements/scores/players with your own Supabase (or any) DB.
Subclass `UnifiedGameServicesPlatform`, call `super()`, override what you
support, and pass it to the facade next to Steam/GameJolt; the facade fans out
writes to every capable provider. Runnable template:
`packages/unified_game_services/example/custom_provider.dart`.
