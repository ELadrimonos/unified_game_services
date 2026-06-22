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
- **Epic** — EOS REST / C SDK.
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

  **Phase 2 — `unified_game_services_google_play_android` (scaffolded, on-device
  verify pending):** committed `jnigen` bindings to the Play Games v2 **Java**
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
  `jni` aligned with jnigen (jnigen 0.16.0 → jni 1.0.0). Not yet runtime-tested
  (needs a Dart-on-Android host + a Play Console game).

  **`unified_game_services_google_play` (built):** thin factory picking native on
  Android, REST elsewhere (runtime `Platform.isAndroid` switch; Dart has no
  compile-time OS guard, so the `jni` dep rides along into all builds but only
  runs on Android). Re-exports both concrete provider types + the REST auth
  strategies.

  **Constraint clarification:** the native package is allowed under no-Flutter.
  `games_services` is banned because it uses Flutter **platform channels**;
  `package:jni`/`jnigen` (pure Dart) reach the Java SDK via JNI — the same
  approach `objective_c` uses for GameKit. "Native Android SDK banned" meant the
  *Flutter* path, not JNI.

**Deferred: Game Center.** Obj-C GameKit, no clean pure-Dart path (no public
REST equivalent). Do **not** pull it in via `games_services` (Flutter +
platform channels — violates the no-Flutter constraint). Revisit later via FFI
(GameKit through `package:objective_c`) or a deliberately-scoped optional-Flutter
adapter.

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
