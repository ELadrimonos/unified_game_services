import 'package:flutter/foundation.dart';

/// Which provider this example knows how to build.
enum ProviderKind { gameJolt, googlePlay, steam, epic }

extension ProviderKindLabel on ProviderKind {
  String get label => switch (this) {
    ProviderKind.gameJolt => 'GameJolt',
    ProviderKind.googlePlay => 'Google Play Games',
    ProviderKind.steam => 'Steam',
    ProviderKind.epic => 'Epic Online Services',
  };

  /// How this provider reaches the platform — shown in the UI to explain the
  /// per-environment gating.
  String get transport => switch (this) {
    ProviderKind.gameJolt => 'REST (pure Dart) — runs everywhere',
    ProviderKind.googlePlay =>
      'JNI on Android, REST elsewhere (incl. web) — runs everywhere',
    ProviderKind.steam => 'Steamworks C API via dart:ffi — desktop only',
    ProviderKind.epic => 'EOS C SDK via dart:ffi — desktop only',
  };
}

/// Runtime environment classification used to decide which providers can be
/// instantiated. The point of the unified API: a provider that cannot run here
/// is simply never registered — no crash, no half-initialized state.
///
/// Web-safe: built on `kIsWeb` + `defaultTargetPlatform`, never `dart:io`.
class Environment {
  Environment._(this.isWeb, this.platform);

  factory Environment.detect() => Environment._(kIsWeb, defaultTargetPlatform);

  final bool isWeb;
  final TargetPlatform platform;

  bool get isAndroid => !isWeb && platform == TargetPlatform.android;
  bool get isIOS => !isWeb && platform == TargetPlatform.iOS;

  /// True on a native desktop host (macOS / Windows / Linux). dart:ffi
  /// providers (Steam, Epic) only build here.
  bool get isDesktop =>
      !isWeb &&
      (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux);

  String get description {
    if (isWeb) return 'Web (${platform.name})';
    return platform.name;
  }

  /// Whether [kind] is capable of running in this environment. Used to gate
  /// instantiation and to grey out unavailable providers in the UI.
  bool supports(ProviderKind kind) => switch (kind) {
    ProviderKind.gameJolt => true,
    ProviderKind.googlePlay => true,
    ProviderKind.steam => isDesktop,
    ProviderKind.epic => isDesktop,
  };

  /// Human reason a provider is unavailable here (null when it is available).
  String? unavailableReason(ProviderKind kind) {
    if (supports(kind)) return null;
    return 'Not available on $description: ${kind.transport}';
  }
}
