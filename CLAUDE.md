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
  unified_game_services_google_play          # provider impls (still stubs)
  unified_game_services_game_center
  unified_game_services_steam
  unified_game_services_epic
  unified_game_services_xbox
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

## Provider scope (MVP)

Pure-Dart-reachable providers ship first:

- **Steam** — Steamworks C API via `dart:ffi`.
- **GameJolt** — REST API.
- **Epic** — EOS REST / C SDK.

**Deferred: Google Play Games & Game Center.** These are mobile-native SDKs
(Android `.aar`, Obj-C GameKit) with no clean pure-Dart path: Android Play Games
is callable only from a running app runtime, and the popular wrapper
[`games_services`](https://pub.dev/packages/games_services) depends on Flutter +
platform channels — which violates the no-Flutter constraint. Do **not** add them
back by depending on `games_services`. Revisit later via FFI (GameKit through
`package:objective_c`) or a deliberately-scoped optional-Flutter adapter.

## When adding a provider

1. Implement the subset of `UnifiedGameServicesPlatform` the provider supports.
2. Declare accurate `capabilities`.
3. Map native/SDK errors to `GameServiceException` subtypes.
4. Register via `UnifiedGameServicesPlatform.instance = ...`.
5. Keep it pure Dart (see constraint above).
