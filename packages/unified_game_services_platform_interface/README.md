# unified_game_services_platform_interface

The common platform interface for
[`unified_game_services`](https://pub.dev/packages/unified_game_services).

This package defines the contract that every game-service provider implements,
plus the shared models, capabilities, events and exceptions. **Most apps don't
depend on it directly** — they use `unified_game_services` (which re-exports
everything here) and a provider package. Depend on it directly only when
**writing a provider**.

Pure Dart, no Flutter dependency.

## What's inside

- **`UnifiedGameServicesPlatform`** — the abstract base every provider extends.
  Methods default to throwing `UnimplementedError`, so a provider overrides only
  what it supports.
- **Models** — `Achievement`, `Leaderboard`/`LeaderboardEntry`, `PlayerProfile`,
  `Stat`, `CloudSave`, `RichPresence`. Hand-written immutable value classes
  with `copyWith`, `==`, `hashCode` and `toString`; no serialization contract.
- **`GameCapability`** — the capability enum used for feature gating.
- **Events** — a sealed `GameServiceEvent` hierarchy.
- **Exceptions** — `GameServiceException` and subtypes (`NotSignedIn`,
  `SignInFailed`, `CapabilityNotSupported`, `Network`, `PlatformOperation`).

## Install

```yaml
dependencies:
  unified_game_services_platform_interface: ^0.2.0
```

## Writing a provider

```dart
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

class MyProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'my_provider'; // stable, snake_case, never changes

  @override
  Set<GameCapability> get capabilities => const {GameCapability.achievements};

  @override
  Future<void> unlockAchievement(String id) async {
    // talk to your platform / backend
  }
}

// Hand it to the facade (global instance or a standalone one):
GameServices.initialize(providers: [MyProvider()]);
```

Guidelines:

1. Override only the methods your platform supports.
2. Declare accurate `capabilities`; throw `CapabilityNotSupportedException` for
   unsupported operations.
3. Map platform/SDK errors onto the `GameServiceException` hierarchy.
4. Put non-portable, provider-specific features as extra public members (not on
   the interface). Apps reach them with
   `GameServices.provider<MyProvider>()`.

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
any platform vendor. Third-party credits, trademark notices, and the Steamworks
SDK redistribution terms are in the repository's `NOTICE.md`.

