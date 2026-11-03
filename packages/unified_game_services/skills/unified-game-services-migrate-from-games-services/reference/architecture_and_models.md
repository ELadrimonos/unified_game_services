# Architecture and Data Models: `games_services` vs `unified_game_services`

This guide details the architectural paradigm shifts and model transitions when migrating to `unified_game_services`.

---

## 1. Data Model Comparison

### Achievements

* **`games_services`**:
  ```dart
  class Achievement {
    String? androidID;
    String? iOSID;
    double? percentComplete;
    int? steps;
    // ...
  }
  ```
* **`unified_game_services`**:
  ```dart
  class Achievement {
    final String id; // Unified ID
    final String title;
    final String? description;
    final bool isUnlocked;
    final int currentSteps;
    final int totalSteps;
    final double progressPercentage;
    final DateTime? unlockedAt;
    final Map<String, String> nativeIds; // Per-provider native ID map
  }
  ```

---

### Player Profile

* **`games_services`**: Dispersed static calls (`Player.getPlayerID()`, `Player.getPlayerName()`, `Player.getPlayerProfileImage()`).
* **`unified_game_services`**: Single cohesive model:
  ```dart
  class PlayerProfile {
    final String id;
    final String displayName;
    final String? avatarUrl;
    final String? providerId;
  }
  ```

---

### Leaderboards and Scores

* **`games_services`**:
  ```dart
  class Score {
    String? androidLeaderboardID;
    String? iOSLeaderboardID;
    int? value;
    // ...
  }
  ```
* **`unified_game_services`**:
  - `Leaderboard`: Contains `id`, `name`, `entries` (`List<LeaderboardEntry>`), and `timeScope`.
  - `LeaderboardEntry`: Contains `formattedScore`, `rawScore` (`int`), `rank` (`int`), `player` (`PlayerProfile`), `timestamp` (`DateTime`).

---

### Cloud Save

* **`games_services`**: String payload only.
* **`unified_game_services`**:
  - `CloudSave`: Contains `bytes` (`Uint8List`), `data` (`List<int>`), and `metadata` (`CloudSaveMetadata`).
  - `CloudSaveMetadata`: Contains `slot`, `sizeBytes`, `modifiedAt`, `deviceName`, `providerId`.

---

## 2. Error Handling & Result Model

### The Problem in `games_services`
In `games_services`, write operations return a nullable `String?` (containing an error message on failure) or throw untyped `PlatformException`s. If you target multiple stores or run into network issues, handling failures requires verbose try/catch blocks and ad-hoc string inspections.

### The Solution in `unified_game_services`
All write operations (`signIn`, `unlockAchievement`, `submitScore`, `saveData`, etc.) return a `MultiProviderOperationResult<T>`:

```dart
final result = await GameServices.unlockAchievement('boss_defeated');

// 1. Check if all providers succeeded:
if (result.allSucceeded) {
  print('Unlocked everywhere!');
}

// 2. Access per-provider successes:
for (final success in result.succeeded) {
  print('Succeeded on: ${success.providerId}');
}

// 3. Inspect per-provider failures:
for (final failure in result.failed) {
  print('Failed on ${failure.providerId}: ${failure.error.message}');
  // Queue for offline retry or log error
}
```

---

## 3. Dependency Injection & Testability

* **`games_services`**: Bound strictly to static classes and platform channels; impossible to test in Flutter unit tests without mocking binary messengers.
* **`unified_game_services`**: Provides both a global static entry point (`GameServices`) and an injectable instance (`UnifiedGameServices`):

```dart
// In production:
final services = GameServices.instance;

// In tests:
final testServices = UnifiedGameServices(
  providers: [FakeGameServicesProvider()],
);
```
