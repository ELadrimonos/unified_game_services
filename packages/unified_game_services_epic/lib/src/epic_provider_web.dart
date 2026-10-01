import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'epic_credentials.dart';

const String _kWebError =
    'EpicProvider is desktop-only (EOS C SDK via dart:ffi) and is not '
    'available on web. Do not register it in a web build — the facade should '
    'only be given Epic on Windows/macOS/Linux. See the package README.';

/// Web stub of [EpicProvider].
///
/// The real provider is `dart:ffi` (EOS C SDK) and cannot compile to JS, so the
/// package entry point conditional-exports this stub on web
/// (`if (dart.library.io)` selects the real one). It mirrors the public
/// constructor so consumer code that references [EpicProvider]
/// still type-checks on web; construction throws [UnsupportedError] because EOS
/// cannot run there.
class EpicProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'epic';

  EpicProvider({
    required this.credentials,
    this.exchangeCode,
    List<String>? launchArgs,
    this.devAuthHost,
    this.devAuthCredentialName,
    this.libraryPath,
    this.tickInterval = const Duration(milliseconds: 100),
    bool debugLogging = false,
    super.leaderboardIds,
    super.achievementIds,
  }) {
    throw UnsupportedError(_kWebError);
  }

  final EpicCredentials credentials;
  final String? exchangeCode;
  final String? devAuthHost;
  final String? devAuthCredentialName;
  final String? libraryPath;
  final Duration tickInterval;

  /// Matches the real static toggle so referencing `EpicProvider.debugLogging`
  /// still resolves on web.
  static bool debugLogging = false;

  @override
  Future<void> dispose() => throw UnsupportedError(_kWebError);
}
