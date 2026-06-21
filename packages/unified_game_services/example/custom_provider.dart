#!/usr/bin/env dart
// How to write a CUSTOM provider (e.g. backed by your own Supabase database)
// and unify it with the built-in providers (Steam, GameJolt, …).
//
// A provider is just a class that extends UnifiedGameServicesPlatform, calls
// super(), declares the capabilities it supports, and overrides the matching
// methods. Pass it to UnifiedGameServices alongside any other provider and the
// facade fans out writes to every capable provider at once.
//
// Run:  dart run example/custom_provider.dart

import 'package:unified_game_services/unified_game_services.dart';

// ─── 1. Your backend ─────────────────────────────────────────────────────────
// Abstracted so this example runs without a network. In a real app this is
// where your Supabase queries live.

abstract class GameBackend {
  Future<Map<String, Object?>?> player(String id);
  Future<List<Map<String, Object?>>> achievements(String playerId);
  Future<void> unlock(String playerId, String achievementId);
  Future<void> addScore(String leaderboardId, String playerId, int score);
  Future<List<Map<String, Object?>>> topScores(String leaderboardId, int limit);
}

/// Sketch of the Supabase-backed implementation (pseudo, needs `supabase`):
///
/// ```dart
/// class SupabaseBackend implements GameBackend {
///   SupabaseBackend(this.db); // SupabaseClient
///   final SupabaseClient db;
///
///   @override
///   Future<List<Map<String, Object?>>> achievements(String playerId) async {
///     return await db
///         .from('player_achievements')
///         .select('achievement_id, title, unlocked_at, achievements(title)')
///         .eq('player_id', playerId);
///   }
///
///   @override
///   Future<void> unlock(String playerId, String achievementId) =>
///       db.from('player_achievements').upsert({
///         'player_id': playerId,
///         'achievement_id': achievementId,
///         'unlocked_at': DateTime.now().toIso8601String(),
///       });
///
///   @override
///   Future<void> addScore(String table, String playerId, int score) =>
///       db.from('scores').insert(
///           {'leaderboard': table, 'player_id': playerId, 'score': score});
///
///   @override
///   Future<List<Map<String, Object?>>> topScores(String table, int n) => db
///       .from('scores')
///       .select('score, players(id, display_name)')
///       .eq('leaderboard', table)
///       .order('score', ascending: false)
///       .limit(n);
///   // …player()…
/// }
/// ```

// ─── 2. The custom provider ──────────────────────────────────────────────────

class SupabaseGameProvider extends UnifiedGameServicesPlatform {
  SupabaseGameProvider({required this.backend, required this.playerId});

  final GameBackend backend;
  final String playerId;

  // Declare only what your backend actually does.
  @override
  Set<GameCapability> get capabilities => const {
        GameCapability.achievements,
        GameCapability.leaderboards,
      };

  @override
  Future<PlayerProfile?> getCurrentPlayer() async {
    final row = await backend.player(playerId);
    if (row == null) return null;
    return PlayerProfile(
      id: '${row['id']}',
      displayName: '${row['display_name']}',
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  @override
  Future<PlayerProfile?> signIn() => getCurrentPlayer();

  @override
  Future<List<Achievement>> getAchievements() async {
    final rows = await backend.achievements(playerId);
    return rows
        .map((r) => Achievement(
              id: '${r['achievement_id']}',
              title: '${r['title']}',
              isUnlocked: r['unlocked_at'] != null,
            ))
        .toList();
  }

  @override
  Future<void> unlockAchievement(String achievementId) =>
      backend.unlock(playerId, achievementId);

  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) =>
      backend.addScore(leaderboardId, playerId, score);

  @override
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) async {
    final rows = await backend.topScores(leaderboardId, maxResults);
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      entries.add(LeaderboardEntry(
        rank: i + 1,
        score: r['score'] as int,
        player: PlayerProfile(
          id: '${r['player_id']}',
          displayName: '${r['display_name']}',
        ),
      ));
    }
    return Leaderboard(id: leaderboardId, entries: entries);
  }
}

// ─── 3. A tiny in-memory backend so the demo runs ────────────────────────────

class InMemoryBackend implements GameBackend {
  final _players = {
    'p1': {'id': 'p1', 'display_name': 'Ada', 'avatar_url': null},
  };
  final _unlocked = <String>{};
  final _scores = <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>?> player(String id) async => _players[id];

  @override
  Future<List<Map<String, Object?>>> achievements(String playerId) async => [
        {
          'achievement_id': 'first_win',
          'title': 'First Win',
          'unlocked_at':
              _unlocked.contains('first_win') ? '2026-01-01T00:00:00Z' : null,
        },
      ];

  @override
  Future<void> unlock(String playerId, String achievementId) async =>
      _unlocked.add(achievementId);

  @override
  Future<void> addScore(String leaderboardId, String playerId, int score) async =>
      _scores.add({
        'leaderboard': leaderboardId,
        'player_id': playerId,
        'display_name': _players[playerId]?['display_name'],
        'score': score,
      });

  @override
  Future<List<Map<String, Object?>>> topScores(
      String leaderboardId, int limit) async {
    final rows = _scores.where((s) => s['leaderboard'] == leaderboardId).toList()
      ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return rows.take(limit).toList();
  }
}

// ─── 4. Use it — alone or unified with Steam/GameJolt ────────────────────────

Future<void> main() async {
  final supabase =
      SupabaseGameProvider(backend: InMemoryBackend(), playerId: 'p1');

  // Unify with other providers. In a real app, e.g.:
  //   providers: [supabase, SteamProvider(appId: 480)]
  // A score then writes to BOTH your DB and Steam in one call.
  final services = UnifiedGameServices(providers: [supabase]);

  final player = await services.signIn();
  print('Player: ${player?.displayName}');

  await services.unlockAchievement('first_win'); // fan-out to capable providers
  await services.submitScore(leaderboardId: 'global', score: 1500);
  await services.submitScore(leaderboardId: 'global', score: 900);

  for (final a in await services.getAchievements()) {
    print('  [${a.isUnlocked ? 'x' : ' '}] ${a.id}');
  }
  final board = await services.getLeaderboard('global');
  for (final e in board.entries) {
    print('  #${e.rank} ${e.player.displayName}: ${e.score}');
  }
}
