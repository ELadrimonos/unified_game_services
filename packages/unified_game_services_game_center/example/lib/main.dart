import 'package:flutter/material.dart';
import 'package:unified_game_services_game_center/unified_game_services_game_center.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'game_center_native.dart';

void main() {
  // Pure-Dart provider over GameKit FFI. Map unified keys to your Game Center
  // ids (configured in App Store Connect for the app's bundle id).
  GameCenterProvider.registerWith(
    leaderboardIds: {'global': 'com.example.game.highscores'},
    achievementIds: {'first_win': 'com.example.game.firstwin'},
  );
  runApp(const GameCenterExampleApp());
}

class GameCenterExampleApp extends StatelessWidget {
  const GameCenterExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Game Center Example',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _log = <String>[];
  PlayerProfile? _player;
  bool _busy = false;

  UnifiedGameServicesPlatform get _services =>
      UnifiedGameServicesPlatform.instance;

  void _say(String msg) => setState(() => _log.insert(0, msg));

  Future<void> _run(String label, Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } on GameServiceException catch (e) {
      _say('✗ $label: ${e.runtimeType} — ${e.message}');
    } catch (e) {
      _say('✗ $label: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  // 1. Present GameKit's native sign-in window (host-side), then resolve the
  //    Dart-side player through the provider.
  Future<void> _authenticate() => _run('authenticate', () async {
        final ok = await GameCenterNative.authenticate();
        _say(ok ? 'OS authenticated' : 'OS sign-in window shown — retry once done');
        if (!ok) return;
        _player = await _services.signIn();
        _say(_player == null
            ? 'signIn() returned null'
            : 'Signed in as ${_player!.displayName} (${_player!.id})');
      });

  // 2. Present the native Game Center dashboard window.
  Future<void> _showDashboard() =>
      _run('dashboard', () => GameCenterNative.showDashboard());

  Future<void> _unlock() => _run('unlock', () async {
        await _services.unlockAchievement('first_win');
        _say('Unlocked first_win');
      });

  Future<void> _submitScore() => _run('submitScore', () async {
        await _services.submitScore(leaderboardId: 'global', score: 4200);
        _say('Submitted 4200 to global');
      });

  Future<void> _loadLeaderboard() => _run('leaderboard', () async {
        final board = await _services.getLeaderboard('global', maxResults: 10);
        _say('Leaderboard global — ${board.entries.length} entries:');
        for (final e in board.entries) {
          _say('  #${e.rank} ${e.player.displayName} — ${e.formattedScore ?? e.score}');
        }
      });

  Future<void> _loadAchievements() => _run('achievements', () async {
        final list = await _services.getAchievements();
        _say('Achievements — ${list.length}:');
        for (final a in list) {
          final state = a.isUnlocked
              ? 'unlocked'
              : '${a.currentSteps}/${a.totalSteps}';
          _say('  ${a.id} — $state');
        }
      });

  @override
  Widget build(BuildContext context) {
    final signedIn = _player != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Center Example'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _authenticate,
                  icon: const Icon(Icons.login),
                  label: const Text('Authenticate (window)'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _showDashboard,
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Show dashboard (window)'),
                ),
                OutlinedButton(
                  onPressed: _busy || !signedIn ? null : _unlock,
                  child: const Text('Unlock achievement'),
                ),
                OutlinedButton(
                  onPressed: _busy || !signedIn ? null : _submitScore,
                  child: const Text('Submit score'),
                ),
                OutlinedButton(
                  onPressed: _busy || !signedIn ? null : _loadLeaderboard,
                  child: const Text('Load leaderboard'),
                ),
                OutlinedButton(
                  onPressed: _busy || !signedIn ? null : _loadAchievements,
                  child: const Text('Load achievements'),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: _log.isEmpty
                  ? const Center(child: Text('Authenticate to begin.'))
                  : ListView.builder(
                      itemCount: _log.length,
                      itemBuilder: (_, i) => Text(
                        _log[i],
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
