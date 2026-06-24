import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_google_play_flutter/unified_game_services_google_play_flutter.dart';

/// Plug-and-play demo of `unified_game_services_google_play_flutter`.
///
/// One call — `GooglePlayGamesFlutter.registerWith()` — wires the native Google Play Games
/// provider on Android, auto-resolving the host `Activity` from the running
/// Flutter engine. No `jni_flutter` / `PlatformDispatcher` in app code.
///
/// Before it works on-device: set the real Play Games app id in
/// `android/app/src/main/res/values/strings.xml` and replace the placeholder
/// ids below with ids from your Play Console game.
///
/// On Android the native provider is used and `auth` is ignored. Off Android —
/// including **web** — the REST provider is used and `auth` is **required**:
/// broker a Google OAuth access/refresh token (your own redirect flow or a
/// backend) and pass it via [StoredCredentialStrategy]. The placeholder below
/// lets the app boot; real Games API calls need a valid token.
void main() {
  // Replace with ids from your Play Console game.
  GooglePlayGamesFlutter.registerWith(
    auth: StoredCredentialStrategy(
      accessToken: 'REPLACE_WITH_A_BROKERED_GOOGLE_OAUTH_TOKEN',
    ),
    achievementIds: const {'firstWin': 'CgkI_REPLACE_ME_ach'},
    leaderboardIds: const {'highScores': 'CgkI_REPLACE_ME_lb'},
  );
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GPG Flutter adapter demo',
    theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Uses the instance registered in main() via GooglePlayGamesFlutter.registerWith().
  final UnifiedGameServices _games = UnifiedGameServices();
  final List<String> _log = [];

  void _append(String line) => setState(() => _log.insert(0, line));

  /// Runs [action], logging success or the mapped [GameServiceException].
  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      _append('$label ✓');
    } on GameServiceException catch (e) {
      _append('$label ✗ ${e.runtimeType}: ${e.message}');
    } catch (e) {
      _append('$label ✗ $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPG Flutter adapter demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _run('signIn', () async {
                    await _games.signIn();
                  }),
                  child: const Text('Sign in'),
                ),
                FilledButton(
                  onPressed: () => _run(
                    'unlock',
                    () => _games.unlockAchievement('firstWin'),
                  ),
                  child: const Text('Unlock achievement'),
                ),
                FilledButton(
                  onPressed: () => _run(
                    'increment',
                    () => _games.incrementAchievement('firstWin', 1),
                  ),
                  child: const Text('Increment +1'),
                ),
                FilledButton(
                  onPressed: () => _run(
                    'submitScore',
                    () => _games.submitScore(
                      leaderboardId: 'highScores',
                      score: 1234,
                    ),
                  ),
                  child: const Text('Submit score 1234'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _log.length,
              itemBuilder: (_, i) => Text(
                _log[i],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
