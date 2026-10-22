/// An Epic Online Services (EOS) provider for `unified_game_services`.
///
/// Backed by the EOS C SDK through `dart:ffi`. Supports achievements,
/// leaderboards, stats, friends, rich presence and cloud save on **desktop
/// only** (Windows, macOS, Linux). The host ships the EOS runtime library and
/// supplies [EpicCredentials]; see `EpicProvider` for the implemented surface
/// and its gaps.
///
/// On web this entry point exports an inert `EpicProvider` stub whose
/// constructor throws [UnsupportedError], so importing the package never breaks
/// a web build. On Android and iOS the code compiles but the constructor throws
/// [UnsupportedError] at runtime.
///
/// @docImport 'src/epic_credentials.dart';
library;

export 'src/epic_credentials.dart';
export 'src/epic_provider_web.dart'
    if (dart.library.io) 'src/epic_provider.dart'
    show EpicProvider;
