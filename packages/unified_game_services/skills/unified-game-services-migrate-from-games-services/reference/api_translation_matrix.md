# API Translation Matrix: `games_services` to `unified_game_services`

This reference maps every static class, method, and property from `games_services` directly to its equivalent in `unified_game_services`.

---

## 1. Authentication & Session (`GameAuth`)

| `games_services` | `unified_game_services` | Notes |
| :--- | :--- | :--- |
| `GameAuth.signIn()` | `GameServices.signIn()` | Returns `Future<MultiProviderOperationResult<PlayerProfile?>>` instead of `Future<String?>`. |
| `GameAuth.isSignedIn` | `GameServices.isSignedIn()` | Returns `Future<bool>`. |
| `GameAuth.getAuthCode(clientID)` | `GameServices.getIdentityToken()` | Returns `Future<String?>`. Server client ID is configured on provider setup if required. |
| *(None / Not supported)* | `GameServices.signOut()` | Standardized across all stores supporting explicit sign-out. |

---

## 2. Player Information (`Player`)

| `games_services` | `unified_game_services` | Notes |
| :--- | :--- | :--- |
| `Player.getPlayerID()` | `(await GameServices.getCurrentPlayer())?.id` | Part of `PlayerProfile`. |
| `Player.getPlayerName()` | `(await GameServices.getCurrentPlayer())?.displayName` | Part of `PlayerProfile`. |
| `Player.getPlayerProfileImage()` | `(await GameServices.getCurrentPlayer())?.avatarUrl` | Returns avatar URL or local cache path string instead of raw base64 string. |
| `Player.getPlayerScore(...)` | `GameServices.getPlayerScore(leaderboardId)` | Returns `Future<LeaderboardEntry?>` with rank, score, formatted score, and timestamp. |
| `Player.isUnderage` | *(Provider specific or not universally exposed)* | Query via provider specific cast if needed. |
| `Player.isMultiplayerGamingRestricted` | *(Provider specific)* | Handled via platform capabilities. |

---

## 3. Achievements (`Achievements`)

| `games_services` | `unified_game_services` | Notes |
| :--- | :--- | :--- |
| `Achievements.unlock(achievement: Achievement(...))` | `GameServices.unlockAchievement(achievementId)` | Uses unified id from mapping table. Returns `MultiProviderOperationResult<void>`. |
| `Achievements.increment(achievement: Achievement(...))` | `GameServices.incrementAchievement(achievementId, steps)` | Note: Steps vs percentage rules apply per store (see cross-store progression skill). |
| `Achievements.showAchievements()` | `GameServices.showAchievementsUI()` | Triggers native platform achievements overlay. |
| `Achievements.loadAchievements()` | `GameServices.getAchievements()` | Returns `Future<List<Achievement>>`. |
| *(None)* | `GameServices.revealAchievement(achievementId)` | Explicitly reveals hidden achievements. |
| *(None)* | `GameServices.getAchievementOverview()` | Aggregates achievement unlock status across all configured stores. |
| *(None)* | `GameServices.syncAchievements()` | Re-synchronizes unlocks across multiple active providers. |

---

## 4. Leaderboards (`Leaderboards`)

| `games_services` | `unified_game_services` | Notes |
| :--- | :--- | :--- |
| `Leaderboards.submitScore(score: Score(...))` | `GameServices.submitScore(leaderboardId: '...', score: int)` | Score value is integer (`int`). Returns `MultiProviderOperationResult<void>`. |
| `Leaderboards.showLeaderboards(...)` | `GameServices.showLeaderboardsUI(leaderboardId: '...')` | Optional `leaderboardId` to open a specific board directly. |
| `Leaderboards.loadLeaderboardScores(...)` | `GameServices.getLeaderboard(leaderboardId, timeScope: ..., collection: ..., maxResults: ...)` | Returns `Future<Leaderboard>` containing `List<LeaderboardEntry>`. |
| *(None)* | `GameServices.getLeaderboardFromAll(leaderboardId)` | Fetches leaderboards from all active providers simultaneously. |

---

## 5. Cloud Save (`SaveGame`)

| `games_services` | `unified_game_services` | Notes |
| :--- | :--- | :--- |
| `SaveGame.saveGame(name: '...', data: String)` | `GameServices.saveData(slot, Uint8List data)` | Binary bytes instead of string; use `utf8.encode()` for JSON. |
| `SaveGame.loadGame(name: '...')` | `GameServices.loadData(slot)` | Returns `Future<CloudSave?>` containing `.bytes` and `.metadata`. |
| `SaveGame.deleteGame(name: '...')` | `GameServices.deleteSave(slot)` | Returns `MultiProviderOperationResult<void>`. |
| `SaveGame.getSavedGames()` | `GameServices.listSaves()` | Returns `Future<List<CloudSaveMetadata>>`. |
