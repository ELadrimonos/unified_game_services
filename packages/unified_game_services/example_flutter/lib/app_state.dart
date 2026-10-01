import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:unified_game_services/unified_game_services.dart';

import 'config/provider_config.dart';
import 'env.dart';
import 'services/registry.dart';

/// One log line in the activity feed, with a success/failure flavor for the UI.
class LogEntry {
  LogEntry(this.message, {this.ok = true, this.kind = 'op'});
  final String message;
  final bool ok;
  final String kind; // 'op' | 'event'
}

/// Holds the whole demo's runtime state: the persisted config, the assembled
/// facade, the signed-in player, and an activity log. The single source of
/// truth the widgets listen to.
class AppState extends ChangeNotifier {
  final Environment env = Environment.detect();

  AppConfig config = AppConfig();
  ProviderBuild? build;
  PlayerProfile? currentPlayer;
  bool busy = false;

  final List<LogEntry> log = [];
  StreamSubscription<GameServiceEvent>? _eventsSub;

  UnifiedGameServices? get facade => build?.facade;
  bool get hasActiveProviders => (build?.active.isNotEmpty) ?? false;

  Future<void> init() async {
    config = await AppConfig.load();
    _rebuild();
  }

  /// Persists the current config and reassembles the providers.
  Future<void> saveAndRebuild() async {
    await config.save();
    _rebuild();
  }

  void _rebuild() {
    _eventsSub?.cancel();
    build = buildProviders(config, env);
    currentPlayer = null;
    final f = facade;
    if (f != null) {
      _eventsSub = f.events.listen(
        (e) => _push(_describeEvent(e), kind: 'event'),
        onError: (Object e) => _push('event error: $e', ok: false),
      );
    }
    _push(
      'Assembled facade: ${build!.active.length} active provider(s) on '
      '${env.description}.',
    );
    notifyListeners();
  }

  // ─── Unified actions ──────────────────────────────────────────────────────

  Future<void> signIn() => _run('signIn (fan-out to all)', (f) async {
    final result = await f.signIn();
    for (final r in result.succeeded) {
      if (r.value != null) {
        currentPlayer = r.value;
        break;
      }
    }
    return result;
  });

  Future<void> signOut() => _run('signOut (fan-out to all)', (f) async {
    final result = await f.signOut();
    currentPlayer = null;
    return result;
  });

  Future<void> refreshPlayer() => _run('getCurrentPlayer (primary)', (f) async {
    currentPlayer = await f.getCurrentPlayer();
  });

  Future<void> unlockAchievement(String id) => _run(
    'unlockAchievement("$id") → achievements-capable providers',
    (f) => f.unlockAchievement(id),
  );

  Future<void> submitScore(String leaderboardId, int score) => _run(
    'submitScore("$leaderboardId", $score) → leaderboards-capable',
    (f) => f.submitScore(leaderboardId: leaderboardId, score: score),
  );

  Future<void> setStat(String key, num value) => _run(
    'setStat("$key", $value) → stats-capable',
    (f) => f.setStat(key, value),
  );

  Future<void> setPresence(String stateText, String details) => _run(
    'setPresence("$stateText") → presence-capable',
    (f) => f.setPresence(
      RichPresence(state: stateText, details: details.isEmpty ? null : details),
    ),
  );

  Future<void> saveData(String slot, String text) => _run(
    'saveData("$slot") → cloudSave-capable',
    (f) => f.saveData(slot, Uint8List.fromList(utf8.encode(text))),
  );

  Future<void> loadData(String slot) =>
      _run('loadData("$slot") from primary', (f) async {
        final save = await f.loadData(slot);
        if (save == null) {
          _push('  → no save found in slot "$slot"');
        } else {
          _push('  → ${save.bytes.length} bytes: "${utf8.decode(save.bytes)}"');
        }
      });

  Future<void> fetchAchievements() =>
      _run('getAchievements from primary', (f) async {
        final list = await f.getAchievements();
        _push('  → ${list.length} achievement(s) from ${_primaryName()}');
        for (final a in list.take(10)) {
          _push('     ${a.isUnlocked ? "🔓" : "🔒"} ${a.title}');
        }
      });

  Future<void> fetchFriends() => _run('getFriends from primary', (f) async {
    final list = await f.getFriends();
    _push('  → ${list.length} friend(s) from ${_primaryName()}');
    for (final p in list.take(10)) {
      _push('     ${p.displayName}');
    }
  });

  // ─── Plumbing ─────────────────────────────────────────────────────────────

  String _primaryName() => facade?.primary.runtimeType.toString() ?? '—';

  Future<void> _run(
    String label,
    Future<dynamic> Function(UnifiedGameServices) op,
  ) async {
    final f = facade;
    if (f == null) {
      _push('No active providers — configure at least one.', ok: false);
      return;
    }
    busy = true;
    notifyListeners();
    _push('▶ $label');
    try {
      final result = await op(f);
      if (result is MultiProviderOperationResult) {
        _logResult(result);
      } else {
        _push('✓ done', ok: true);
      }
    } catch (e) {
      _push('✗ ${_describeError(e)}', ok: false);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _push(String message, {bool ok = true, String kind = 'op'}) {
    log.insert(0, LogEntry(message, ok: ok, kind: kind));
    if (log.length > 200) log.removeRange(200, log.length);
    notifyListeners();
  }

  /// Logs one line per provider: partial failures are results, not throws.
  void _logResult(MultiProviderOperationResult<Object?> result) {
    for (final r in result.succeeded) {
      _push('  ✓ ${r.providerId}');
    }
    for (final r in result.failed) {
      _push('  ✗ ${r.providerId}: ${r.error}', ok: false);
    }
    _push(
      result.allSucceeded
          ? '✓ done'
          : '⚠ ${result.failedProviders.length} failed',
      ok: result.allSucceeded,
    );
  }

  String _describeError(Object e) => e.toString();

  String _describeEvent(GameServiceEvent e) => switch (e) {
    UserSignedInEvent(:final player) => '🔔 signed in: ${player.displayName}',
    UserSignedOutEvent() => '🔔 signed out',
    ScoreSubmittedEvent(:final leaderboardId, :final score) =>
      '🔔 score $score → $leaderboardId',
    AchievementUnlockedEvent(:final achievement) =>
      '🔔 achievement unlocked: ${achievement.title}',
    _ => '🔔 ${e.runtimeType}',
  };

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }
}
