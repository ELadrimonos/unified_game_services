---
name: unified-game-services-migrate-from-games-services
description: >-
  Use when migrating a Flutter game from games_services to unified_game_services 0.2.2:
  translating callsites for GameAuth, Player, Achievements, Leaderboards, and SaveGame,
  replacing inline platform IDs with unified identifier tables, adapting error handling
  to MultiProviderOperationResult, or converting Cloud Save strings to binary data.
---

# Migrate from `games_services` to `unified_game_services`

This guide explains how to migrate Flutter projects from the legacy `games_services`
package to `unified_game_services` 0.2.0.

For detailed callsite-by-callsite translation tables and data model differences, see:
- [API Translation Matrix](reference/api_translation_matrix.md)
- [Architecture & Data Models](reference/architecture_and_models.md)

---

## 1. Core Architectural Differences

| Concept | `games_services` | `unified_game_services` |
| :--- | :--- | :--- |
| **Provider scope** | Hardcoded to Apple Game Center & Google Play Games | Decoupled; supports Steam, GameJolt, Epic, Google Play, Apple Game Center, etc. |
| **Identifier mapping** | IDs passed inline in every call (`androidID: '...', iOSID: '...'`) | Centralized mapping table configured once at initialization |
| **Write operations** | Fire-and-forget, returns nullable `String?` error or throws | Returns `MultiProviderOperationResult` with per-provider status |
| **Sign-in lifecycle** | Global blocking sign-in (`GameAuth.signIn()`) | Background asynchronous sign-in (`GameServices.signIn()`) |
| **Cloud Save** | Strings only (`SaveGame.saveGame(data: '...')`) | Raw bytes / `Uint8List` (`GameServices.saveData(slot, bytes)`) |

---

## 2. Step 1: Update Dependencies & Initial Setup

1. In `pubspec.yaml`, remove `games_services` and add `unified_game_services` along with required provider packages (e.g., `unified_game_services_google_play_android`, `unified_game_services_game_center`, etc.):

```yaml
dependencies:
  unified_game_services: ^0.2.2
  unified_game_services_google_play_android: ^0.2.0
  unified_game_services_game_center: ^0.2.0
```

2. Replace per-call platform IDs with a single centralized mapping table initialized at app startup (e.g. in `main.dart` or composition root):

```dart
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_google_play_android/unified_game_services_google_play_android.dart';
import 'package:unified_game_services_game_center/unified_game_services_game_center.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  GameServices.initialize(
    providers: [
      if (Platform.isIOS || Platform.isMacOS) AppleGameCenterProvider(),
      if (Platform.isAndroid) GooglePlayGamesAndroidProvider(),
    ],
    achievements: UnifiedAchievementTable({
      'first_win': ProviderIdMap(
        gameCenter: 'grp.first_win_ios',
        googlePlay: 'CgkI4v...first_win',
      ),
      'score_100': ProviderIdMap(
        gameCenter: 'grp.score_100_ios',
        googlePlay: 'CgkI4v...score_100',
      ),
    }),
    leaderboards: UnifiedLeaderboardTable({
      'high_scores': ProviderIdMap(
        gameCenter: 'grp.high_scores_ios',
        googlePlay: 'CgkI4v...high_scores',
      ),
    }),
  );

  runApp(const MyGameApp());
}
```

---

## 3. Step 2: Authentication & Player Profile

### Sign In
```dart
// Before (games_services):
final result = await GameAuth.signIn();

// After (unified_game_services):
final result = await GameServices.signIn();
if (result.allSucceeded) {
  // Signed in on all configured providers
} else {
  for (final failed in result.failed) {
    print('Provider ${failed.providerId} failed: ${failed.error}');
  }
}
```

### Check Auth State & Get Current Player
```dart
// Before (games_services):
final isSignedIn = await GameAuth.isSignedIn;
final playerId = await Player.getPlayerID();
final playerName = await Player.getPlayerName();

// After (unified_game_services):
final isSignedIn = await GameServices.isSignedIn();
final player = await GameServices.getCurrentPlayer();
final playerId = player?.id;
final playerName = player?.displayName;
```

---

## 4. Step 3: Achievements

### Unlocking Achievements
```dart
// Before (games_services):
await Achievements.unlock(
  achievement: Achievement(
    androidID: 'CgkI4v...first_win',
    iOSID: 'grp.first_win_ios',
    percentComplete: 100,
  ),
);

// After (unified_game_services):
final result = await GameServices.unlockAchievement('first_win');
if (!result.allSucceeded) {
  // Handle failed stores or queue for offline retry
}
```

### Incrementing & Showing UI
```dart
// Before (games_services):
await Achievements.increment(
  achievement: Achievement(androidID: '...', steps: 5),
);
await Achievements.showAchievements();

// After (unified_game_services):
await GameServices.incrementAchievement('coins_collected', 5);
await GameServices.showAchievementsUI();
```

---

## 5. Step 4: Leaderboards & Scores

### Submitting Scores
```dart
// Before (games_services):
await Leaderboards.submitScore(
  score: Score(
    androidLeaderboardID: 'CgkI4v...high_scores',
    iOSLeaderboardID: 'grp.high_scores_ios',
    value: 1500,
  ),
);

// After (unified_game_services):
final result = await GameServices.submitScore(
  leaderboardId: 'high_scores',
  score: 1500,
);
```

### Showing Leaderboard UI & Fetching Scores
```dart
// Before (games_services):
await Leaderboards.showLeaderboards(
  androidLeaderboardID: '...',
  iOSLeaderboardID: '...',
);
final scores = await Leaderboards.loadLeaderboardScores(...);

// After (unified_game_services):
await GameServices.showLeaderboardsUI(leaderboardId: 'high_scores');
final leaderboard = await GameServices.getLeaderboard(
  'high_scores',
  timeScope: LeaderboardTimeScope.allTime,
  collection: LeaderboardCollection.global,
  maxResults: 25,
);
```

---

## 6. Step 5: Saved Games (Cloud Save)

`games_services` dealt exclusively in strings, whereas `unified_game_services` uses binary `Uint8List` for maximum performance and cross-format flexibility.

```dart
// Before (games_services):
await SaveGame.saveGame(name: 'slot1', data: jsonEncode(gameData));
final saveString = await SaveGame.loadGame(name: 'slot1');

// After (unified_game_services):
import 'dart:convert';
import 'dart:typed_data';

// Saving:
final bytes = Uint8List.fromList(utf8.encode(jsonEncode(gameData)));
await GameServices.saveData('slot1', bytes);

// Loading:
final save = await GameServices.loadData('slot1');
if (save != null) {
  final jsonMap = jsonDecode(utf8.decode(save.bytes));
}

// Deleting / Listing:
await GameServices.deleteSave('slot1');
final savesList = await GameServices.listSaves();
```

---

## 7. Step 6: Handling Results and Errors

In `games_services`, errors were inconsistent (strings returned or uncaught platform exceptions).
In `unified_game_services`:
- Fan-out writes (`unlockAchievement`, `submitScore`, `saveData`, etc.) return a `MultiProviderOperationResult`.
- Inspect `result.allSucceeded`, `result.succeeded`, and `result.failed`.
- Never use `result.throwIfAnyFailed()` in production gameplay code; instead, handle partial failures gracefully (e.g. queue offline writes).
- Reads (`getAchievements`, `getLeaderboard`, etc.) target the primary provider and will throw `GameServiceException` if a network or platform error occurs.

---

## 8. Migration Checklist

- [ ] Removed `games_services` from `pubspec.yaml` and added `unified_game_services` with target providers.
- [ ] Created mapping tables (`UnifiedAchievementTable`, `UnifiedLeaderboardTable`) with unified keys.
- [ ] Initialized `GameServices.initialize(...)` once at startup before calling any services.
- [ ] Replaced `GameAuth.signIn()` and `Player.*` calls with `GameServices.signIn()` and `GameServices.getCurrentPlayer()`.
- [ ] Replaced `Achievements.*` and `Leaderboards.*` with unified ID calls.
- [ ] Converted `SaveGame` strings to UTF-8 / binary `Uint8List` for `GameServices.saveData` and `loadData`.
- [ ] Replaced string error checks with `MultiProviderOperationResult.failed` handling.
