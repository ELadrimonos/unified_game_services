/// Steam provider for `unified_game_services`, backed by the pure-Dart
/// `steamworks` FFI bindings.
///
/// **Desktop only** (Windows/macOS/Linux). The real provider is `dart:ffi`, so
/// on web this entry point exports an inert stub whose members throw
/// [UnsupportedError] — importing the package never breaks a web build, but
/// Steam cannot run there. On mobile (Android/iOS) the code compiles but the
/// constructor throws [UnsupportedError] at runtime. See the README.
library;

export 'src/steam_provider_web.dart'
    if (dart.library.io) 'src/unified_game_services_steam_base.dart';
