import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'epic_credentials.dart';

const String _kWebError =
    'EpicProvider is desktop-only (EOS C SDK via dart:ffi) and is not '
    'available on web. Do not register it in a web build — the facade should '
    'only be given Epic on Windows/macOS/Linux. See the package README.';

/// The web stub of `EpicProvider`.
///
/// The real provider uses `dart:ffi` and cannot compile to JavaScript, so the
/// package entry point exports this stub when `dart.library.io` is unavailable.
/// It mirrors the public constructor so code that references `EpicProvider`
/// still type-checks on web, but construction always throws
/// [UnsupportedError] because EOS cannot run there. Register Epic only on
/// Windows, macOS and Linux.
class EpicProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'epic';

  /// Whether Epic Online Services is supported on the current platform.
  ///
  /// Always `false` on web.
  static bool get isSupported => false;

  /// Always throws [UnsupportedError].
  ///
  /// The parameters mirror the desktop `EpicProvider` constructor and are
  /// otherwise unused.
  EpicProvider({
    required this.credentials,
    this.exchangeCode,
    List<String>? launchArgs,
    this.devAuthHost,
    this.devAuthCredentialName,
    this.libraryPath,
    this.tickInterval = const Duration(milliseconds: 100),
    bool debugLogging = false,
  }) {
    throw UnsupportedError(_kWebError);
  }

  /// The Developer Portal settings; unused on web.
  final EpicCredentials credentials;

  /// The Epic Launcher exchange code; unused on web.
  final String? exchangeCode;

  /// The Developer Authentication Tool endpoint; unused on web.
  final String? devAuthHost;

  /// The Developer Authentication Tool credential name; unused on web.
  final String? devAuthCredentialName;

  /// The EOS runtime library path; unused on web.
  final String? libraryPath;

  /// The `EOS_Platform_Tick` interval; unused on web.
  final Duration tickInterval;

  /// Mirrors the desktop static toggle so references to
  /// `EpicProvider.debugLogging` still resolve on web; it has no effect.
  static bool debugLogging = false;

  /// Always throws [UnsupportedError].
  @override
  Future<void> dispose() => throw UnsupportedError(_kWebError);
}
