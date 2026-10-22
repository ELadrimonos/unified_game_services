---
name: unified-game-services-platform-interface-custom-providers
description: >-
  Use when creating or extending a custom UnifiedGameServicesPlatform provider,
  integrating a proprietary backend, or testing provider capabilities, ID
  mappings, authentication, events, and errors for unified_game_services 0.2.0.
---

# Implement a custom provider

## Establish the boundary

1. Ask which backend, target platforms, authentication mechanism, and operations
   the app needs. Identify the backend's real semantics before advertising support.
2. Keep the provider package pure Dart. Depend on
   `unified_game_services_platform_interface: ^0.2.0`; do not depend on the
   facade, another provider, Flutter, or platform channels. Native integrations
   can use FFI, conditional exports, and host-supplied runtime resources.
3. Extend `UnifiedGameServicesPlatform`, not `implements`. Let the constructor
   invoke `super()` so the platform-interface token and mapping storage exist.
4. Choose a stable, lowercase `snake_case` `providerId`, unique among the app's
   providers. Never derive it from `runtimeType` or change it between sessions.
5. Put non-portable backend features on the concrete provider, not on the shared
   interface. Do not modify the shared contract just to accommodate one backend.

## Implement the mandatory contract first

Override all of these, even when the capability set is empty:

- `signIn()` returns `Future<PlayerProfile?>`. Failure or cancellation must throw
  a normalized exception; `null` means success without a profile, not failure.
- `signOut()` returns `Future<void>`; document what sign-out means for the backend.
- `isSignedIn()` returns `false` for no session.
- `getCurrentPlayer()` returns `null` for no session.
- `events` is a broadcast `Stream<GameServiceEvent>`, even if it emits nothing.
- `dispose()` closes owned streams, clients, subscriptions, timers, and native
  resources. Cancel producers before closing their streams.

Authentication and `events` inherit `UnimplementedError`, not an implementation.
Make `events` available before sign-in; the facade merges provider streams when
its events stream is used. Subscribe before operations: streams do not replay
old events. Emit success events only after backend confirmation; the sealed
event hierarchy cannot be extended outside its library.

This working authentication-only adapter deliberately advertises **no game
capabilities**. Supply real backend callbacks that already translate failures
to `GameServiceException` subtypes. It owns its event stream, not the injected
backend client. Add backend session-expiry handling when integrating a real SDK.

```dart
import 'dart:async';

import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

class CustomProvider extends UnifiedGameServicesPlatform {
  CustomProvider({
    required this.authenticate,
    required this.endSession,
    required this.currentPlayer,
  });

  final Future<PlayerProfile> Function() authenticate;
  final Future<void> Function() endSession;
  final Future<PlayerProfile?> Function() currentPlayer;
  final _events = StreamController<GameServiceEvent>.broadcast();

  @override
  String get providerId => 'custom_backend';

  @override
  Set<GameCapability> get capabilities => const {};

  @override
  Stream<GameServiceEvent> get events => _events.stream;

  @override
  Future<PlayerProfile?> signIn() async {
    final player = await authenticate();
    _events.add(UserSignedInEvent(player: player, timestamp: DateTime.now()));
    return player;
  }

  @override
  Future<void> signOut() async {
    await endSession();
    _events.add(UserSignedOutEvent(timestamp: DateTime.now()));
  }

  @override
  Future<bool> isSignedIn() async => await currentPlayer() != null;

  @override
  Future<PlayerProfile?> getCurrentPlayer() => currentPlayer();

  @override
  Future<void> dispose() => _events.close();
}
```

## Add supported operations and ID mapping

- Advertise only implemented `GameCapability` values. Leave unsupported methods
  inherited: they throw `CapabilityNotSupportedException`. An advertised group
  does not imply every option works: unsupported incremental achievements or
  leaderboard scopes must also throw this exception, never silently succeed.
- Guard authenticated operations with `NotSignedInException`. Do not use that
  exception for the normal signed-out result of the two session queries above.
- Resolve every incoming achievement, leaderboard, and stat key with
  `resolveAchievementId`, `resolveLeaderboardId`, or `resolveStatId`, respectively,
  before passing it to the backend. Cover reads as well as writes.
- Return native IDs in provider models; the facade performs reverse mapping and
  stamps `providerId`/native-ID metadata. Do not invent a second mapping layer.
  Unmapped incoming keys intentionally pass through unchanged.
- Respect method semantics: incremental achievement steps and `incrementStat`
  are deltas, whereas `setStat` is an absolute value. Do not conflate these just
  because the backend exposes only an increment operation.
- Shared models are immutable Dart values, not wire DTOs: keep backend JSON and
  serialization in the provider. Do not assume `toJson`/`fromJson` exist.
- If implementing lobbies, preserve `LobbyKind` using the reserved
  `lobbyKindDataKey` (`ugs_kind`) and strip that metadata from user-visible data.

In the **consumer app**, depend on `unified_game_services: ^0.2.0` and the custom
provider package. After implementing achievements, wire its IDs as follows
(`provider.providerId` must be `custom_backend`):

```dart
import 'package:unified_game_services/unified_game_services.dart';

UnifiedGameServices configureServices(UnifiedGameServicesPlatform provider) {
  return UnifiedGameServices(
    providers: [provider],
    achievements: UnifiedAchievementTable({
      'first_win': ProviderIdMap(custom: {'custom_backend': 'backend_first_win'}),
    }),
  );
}
```

Use `UnifiedLeaderboardTable` and `UnifiedStatTable` similarly. The facade calls
`registerMappings` with the provider's slice; there are no constructor mapping
arguments or `registerWith`/global platform singleton to implement. A global app
can instead use `GameServices.initialize(providers: [...])`.

Provider methods return their declared values and throw failures. Do **not**
return facade-specific result wrappers from a provider. At the facade layer,
sign-in and fan-out writes return `MultiProviderOperationResult`: inspect
`failed`/`succeeded` or call `throwIfAnyFailed()`. One provider's failure does not
roll back successful writes to another provider. Await `services.dispose()`
when done; `GameServices.reset()` only clears the global reference.

## Normalize backend failures

Preserve existing `GameServiceException`s. Translate connectivity failures into
`NetworkException`, rejected/cancelled sign-in into `SignInFailedException`,
and other backend failures into `PlatformOperationException(message, code: ...,
cause: ...)`. Unsupported operations/options use
`CapabilityNotSupportedException(capability)`. Never swallow an error and return
fake success. Never include credentials or tokens in error messages or logs;
wrapped causes may also contain sensitive response bodies.

## Verify before handing off

Inject a backend client or callbacks so unit tests need no real credentials.
Run `dart analyze --fatal-infos` and targeted `dart test` in the provider project.
Cover:

- Successful sign-in/out, rejected/cancelled auth, signed-out queries, and session
  expiry; every mandatory override must avoid inherited `UnimplementedError`.
- Declared capabilities and actual implemented methods/options. An auth-only
  provider must reject `unlockAchievement` with `CapabilityNotSupportedException`.
- Mapped and unmapped IDs reaching the backend, plus facade reverse mapping for
  reads; use `ProviderIdMap(custom: ...)` with the exact `providerId`.
- Numeric semantics, empty reads, invalid input, and backend/network errors.
- Multiple event listeners, events only on confirmed success, and disposal with
  no dangling subscriptions/timers or events added after stream closure.
- Consumer-level facade integration, including a second provider failing while
  this provider succeeds. Keep the facade dependency in the consumer/test harness,
  not the provider's runtime dependencies.

Report mock-based verification separately from a live backend smoke test. Do not
claim an integration works against a service until its authentication, one write,
and a corresponding read have actually been exercised with a test account.