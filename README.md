# Unified Game Services

A multi-platform abstraction layer for game services that unifies achievements,
leaderboards, stats, cloud save, user profiles, and rich presence behind a
single Dart API.

> **Pure Dart, no Flutter.** Every package targets the Dart SDK, so the library
> runs in plain Dart apps, CLIs, servers, and any Dart framework — Flutter
> included, but not required.

## Goals

- A single API across multiple platforms.
- Modular, federated-plugin architecture.
- Works on mobile, desktop, and [console?](https://fluorite.game/).
- Easy integration for Dart developers.
- Extensible to new providers without touching the core.

---

## Project status

| Module | Status |
|---------|---------|
| Core API | ✅ Implemented (interface + multi-provider facade) |
| Achievements | ✅ Implemented (Steam, GameJolt, PlayFab) |
| Leaderboards | ✅ Implemented (Steam, GameJolt, PlayFab) |
| Stats | ✅ Implemented (Steam, PlayFab) |
| Cloud Save | ✅ Implemented (Steam, GameJolt, PlayFab) |
| User Profiles | ✅ Implemented (Steam, GameJolt, PlayFab) |
| Rich Presence | ✅ Implemented (Steam) |
| Steam | ✅ Implemented (pure Dart, FFI `steamworks`) — runtime-verified on macOS |
| GameJolt | ✅ Implemented (pure Dart, REST Game API v1.2) — verified with tests + live |
| Epic Online Services | 🚧 MVP (pure Dart, EOS REST/C) |
| PlayFab | ✅ Implemented (pure Dart, REST Client API) — verified with tests |
| Google Play Games (rest) | ✅ Implemented (pure Dart, REST Games API v1 + OAuth) — achievements + leaderboards, verified with tests |
| Google Play Games (android) | ✅ Implemented (Play Games Services native SDK via package:jni) |
| Google Play Games | ✅ Implemented (auto-selects native on Android, REST elsewhere) |
| Google Play Games (flutter) | ✅ Implemented (Flutter adapter — auto-resolves the Activity via jni_flutter for plug-and-play) |
| Apple Game Center | ✅ Implemented (pure Dart, FFI GameKit via `objective_c`) — auth + achievements + leaderboards, macOS/iOS |
| Xbox on PC (GDK) | 📋 Research |
| Huawei Game Service | 📋 Research |

> **Core constraint:** no package depends on Flutter. That is why
> [`games_services`](https://pub.dev/packages/games_services) is not used (it
> requires Flutter + platform channels). The MVP covers the providers reachable
> from pure Dart. Google Play Games currently ships as three packages: `unified_game_services_google_play_rest` (REST Games API v1 + OAuth 2.0, achievements + leaderboards), `unified_game_services_google_play_android` (native Play Games Services integration via `package:jni`), and `unified_game_services_google_play`, a convenience provider that automatically selects the native implementation on Android and the REST implementation elsewhere. Game Center is implemented in pure Dart via `dart:ffi` + `package:objective_c` against GameKit (macOS/iOS) — auth + achievements + leaderboards.


---

## Vision

Today Dart/Flutter has standalone solutions for some platforms, but there is no
unified interface that lets you write a single implementation and ship it across
multiple ecosystems.

This project sets out to solve that.

```dart
final gameServices = UnifiedGameServices();

await gameServices.unlockAchievement(
  'first_win',
);

await gameServices.submitScore(
  leaderboardId: 'global_score',
  score: 1500,
);
```

The same call will work over:

- Google Play Games
- Apple Game Center
- Steam
- Epic Games Store
- GameJolt
- PlayFab (Microsoft's cross-platform backend; distinct from native Xbox Live)
- Xbox on PC (Microsoft GDK; console variant TBD)
- Other future or custom providers

---

## Architecture

```text
unified_game_services
│
├── core
│   ├── achievements
│   ├── leaderboards
│   ├── stats
│   ├── profiles
│   ├── cloud_save
│   └── presence
│
├── providers
│   ├── android_rest        # Google Play Games (REST, all platforms)
│   ├── android_native      # Google Play Games (Play Games v2 Java SDK, Android)
│   ├── android             # auto: native on Android, REST elsewhere
│   ├── game_center
│   ├── steam
│   ├── epic
│   ├── playfab
│   ├── xbox_pc
│   ├── gamejolt
│   └── huawei
│
└── platform_interfaces
```

---

## Recommended monorepo

```text
packages/
│
├── unified_game_services
├── unified_game_services_platform_interface
├── unified_game_services_google_play_rest
├── unified_game_services_google_play_android
├── unified_game_services_google_play
├── unified_game_services_google_play_flutter
├── unified_game_services_game_center
├── unified_game_services_steam
├── unified_game_services_epic
├── unified_game_services_gamejolt
├── unified_game_services_playfab
├── unified_game_services_xbox_pc
└── examples/
```

---

## Roadmap

### Phase 1 — Core

**Goal**

Build the base API without depending on any platform.

**Tasks**

- Define `GameProvider`.
- Define `Achievement`.
- Define `Leaderboard`.
- Define `PlayerProfile`.
- Define `Stat`.
- Define `CloudSave`.
- Define `RichPresence`.
- Define common exceptions.
- Define the capabilities system.

### Phase 2 — Achievements

**Initial API**

```dart
await services.unlockAchievement(
  'achievement_id',
);
```

**Features**

- Unlock achievement.
- Incremental achievements.
- Get progress.
- Get full listing.
- Change events.

### Phase 3 — Leaderboards

**Initial API**

```dart
await services.submitScore(
  leaderboardId: 'global',
  score: 1000,
);
```

**Features**

- Submit score.
- Get global top.
- Get personal score.
- Get ranking.
- Get friends' scores.

### Phase 4 — Stats

**Initial API**

```dart
await services.setStat(
  key: 'kills',
  value: 150,
);
```

**Features**

- Read stats.
- Update stats.
- Increment stats.
- Automatic sync.

### Phase 5 — Profiles

**Initial API**

```dart
final player = await services.getCurrentPlayer();
```

**Features**

- User ID.
- Display name.
- Avatar.
- Online status.
- Friends.

### Phase 6 — Rich Presence

**Initial API**

```dart
await services.setPresence(
  state: 'Playing Ranked',
);
```

**Features**

- Custom state.
- Session time.
- Current activity.
- Invitations.

### Phase 7 — Cloud Save

**Initial API**

```dart
await services.saveData(
  slot: 'profile',
  data: bytes,
);
```

**Features**

- Remote save.
- Versioning.
- Conflict resolution.
- Offline sync.

---

## Capabilities system

Each platform supports different features.

```dart
if (services.supports(
  GameCapability.cloudSave,
)) {
  ...
}
```

Planned capabilities:

```dart
enum GameCapability {
  achievements,
  leaderboards,
  stats,
  cloudSave,
  friends,
  presence,
  multiplayer,
}
```

---

## Multi-provider

Lets you publish to several platforms at once.

```dart
final services = UnifiedGameServices(
  providers: [
    SteamProvider(),
    EpicProvider(),
    GameJoltProvider(),
  ],
);
```

Operations fan out to every capable provider.

---

## Events

```dart
services.events.listen(
  (event) {
    print(event);
  },
);
```

Planned events:

- AchievementUnlocked
- ScoreSubmitted
- StatUpdated
- PresenceChanged
- UserSignedIn

---

## Testing

### Core

- Unit tests
- Mock providers

### Providers

- Integration tests
- Fake SDKs
- Cross-platform CI

---

## Future expansions

### Multiplayer

```dart
await services.inviteFriend();
```

### Matchmaking

```dart
await services.findMatch();
```

### Anti-cheat

Optional system for compatible providers.

### Analytics

```dart
await services.trackEvent(
  'boss_defeated',
);
```

---

## Recommended MVP

### Core

- Base architecture.
- Achievements.
- Leaderboards.

### Providers

- Google Play Games.
- Apple Game Center.
- Steam.

### Publishing

- Documentation.
- Full example.
- Tests.
- CI.

---

## End goal

Become the standard Dart/Flutter solution for game services — write a single
integration and deploy it over any game-distribution ecosystem.

---

## License & credits

**MIT** — see the [`LICENSE`](LICENSE) file.

This is an **independent, unofficial** library. It is not affiliated with or
endorsed by any platform vendor (Valve, Game Jolt, Epic Games, Microsoft,
Google, Apple). All trademarks belong to their respective owners and are used
only to identify the service each provider integrates with.

The repository bundles **no vendor SDK or native binary** that it lacks
permission to redistribute. In particular, the Steamworks SDK is **not**
redistributed: the Steam provider is a wrapper over the
[`steamworks`](https://github.com/aeb-dev/steamworks) FFI bindings
(BSD-3-Clause), and Valve's native library is copied out of your own `pub`
cache when you set up the project.

Third-party credits, trademark notices, and the Steamworks SDK redistribution
terms: see [`NOTICE.md`](NOTICE.md).
