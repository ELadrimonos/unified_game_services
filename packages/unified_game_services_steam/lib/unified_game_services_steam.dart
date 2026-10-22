/// A Steam provider for `unified_game_services`, backed by the Steamworks SDK
/// through the pure-Dart `steamworks` FFI bindings.
///
/// Supports achievements, leaderboards, stats, cloud save, friends and rich
/// presence on **desktop only** (Windows, macOS, Linux). The host ships the
/// Steamworks runtime library and runs the Steam client; see `SteamProvider`
/// for the requirements and behaviour.
///
/// On web this entry point exports an inert `SteamProvider` stub whose
/// constructor throws [UnsupportedError], so importing the package never breaks
/// a web build. On Android and iOS the code compiles but the constructor throws
/// [UnsupportedError] at runtime.
library;

export 'src/steam_provider_web.dart'
    if (dart.library.io) 'src/unified_game_services_steam_base.dart';
export 'src/steam_exceptions.dart';
