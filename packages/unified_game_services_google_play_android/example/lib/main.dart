import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:jni_flutter/jni_flutter.dart';
import 'package:unified_game_services_google_play_android/unified_game_services_google_play_android.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Minimal Flutter host for [GooglePlayAndroidProvider].
///
/// The provider package itself is pure Dart (no Flutter dependency). This app
/// only exists to satisfy the provider's two host requirements on a real
/// device:
///   1. a running ART VM with `package:jni` bound to it (Flutter on Android
///      gives us this for free), and
///   2. the current `Activity` jobject — obtained here with
///      `Jni.getCurrentActivity()` and passed into the provider.
///
/// Reads are not wired yet (see the provider docs: `Task<T>` binding pending),
/// so this demo exercises the write path — the calls that fire the native
/// Play Games toasts/overlay: unlock / increment / reveal / submitScore.
///
/// Before it works on-device you must, in `android/`:
///   - set the real Play Games app id string resource (see AndroidManifest +
///     `app/build.gradle.kts`), and
///   - replace the placeholder achievement / leaderboard ids below with ids
///     from your Play Console game.
void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GPG Android (native) demo',
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
  // Replace with ids from your Play Console game.
  static const _achievementId = 'CgkI_REPLACE_ME_ach';
  static const _leaderboardId = 'CgkI_REPLACE_ME_lb';

  GooglePlayAndroidProvider? _provider;
  StreamSubscription<GameServiceEvent>? _eventsSub;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    try {
      // The host Activity jobject — the one piece the provider can't get on
      // its own. jni_flutter resolves it from the running Flutter engine.
      final activity = androidActivity(PlatformDispatcher.instance.engineId!);
      if (activity == null) {
        _append('init failed: no Android Activity (run on Android)');
        return;
      }
      final provider = GooglePlayAndroidProvider(activity: activity);
      _eventsSub = provider.events.listen(
        (e) => _append('event: ${e.runtimeType}'),
      );
      _provider = provider;
      _append('provider ready (caps: ${provider.capabilities})');
    } catch (e) {
      _append('init failed: $e');
    }
  }

  void _append(String line) {
    if (!mounted) return;
    setState(() => _log.insert(0, line));
  }

  /// Runs [action], logging success or the mapped [GameServiceException].
  Future<void> _run(String label, Future<void> Function() action) async {
    final p = _provider;
    if (p == null) {
      _append('$label skipped — provider not initialized');
      return;
    }
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
  void dispose() {
    _eventsSub?.cancel();
    _provider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _provider;
    return Scaffold(
      appBar: AppBar(title: const Text('GPG native write demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: p == null ? null : () => _run('signIn', p.signIn),
                  child: const Text('Sign in'),
                ),
                FilledButton(
                  onPressed: p == null
                      ? null
                      : () => _run(
                          'unlock',
                          () => p.unlockAchievement(_achievementId),
                        ),
                  child: const Text('Unlock achievement'),
                ),
                FilledButton(
                  onPressed: p == null
                      ? null
                      : () => _run(
                          'increment',
                          () => p.incrementAchievement(_achievementId, 1),
                        ),
                  child: const Text('Increment +1'),
                ),
                FilledButton(
                  onPressed: p == null
                      ? null
                      : () => _run(
                          'reveal',
                          () => p.revealAchievement(_achievementId),
                        ),
                  child: const Text('Reveal achievement'),
                ),
                FilledButton(
                  onPressed: p == null
                      ? null
                      : () => _run(
                          'submitScore',
                          () => p.submitScore(
                            leaderboardId: _leaderboardId,
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
