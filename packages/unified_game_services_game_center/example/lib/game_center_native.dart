import 'package:flutter/services.dart';

/// Thin wrapper over the host-side method channel that presents GameKit's
/// native *windows*. Apple only lets GameKit present from a view controller the
/// app owns, so the auth and dashboard windows must come from the runner
/// (macos/Runner, ios/Runner) — not the pure-Dart provider. Everything else
/// flows through [GameCenterProvider] over FFI.
class GameCenterNative {
  static const _channel = MethodChannel('game_center_example/native');

  /// Installs GameKit's `authenticateHandler` and presents the sign-in window
  /// if the OS asks for it. Completes with the resulting authentication state.
  static Future<bool> authenticate() async =>
      await _channel.invokeMethod<bool>('authenticate') ?? false;

  /// Presents the native Game Center dashboard window (achievements,
  /// leaderboards). Requires an authenticated player.
  static Future<void> showDashboard() =>
      _channel.invokeMethod<void>('showDashboard');
}
