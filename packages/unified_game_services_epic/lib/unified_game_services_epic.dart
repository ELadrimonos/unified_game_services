/// Epic Online Services (EOS) provider for `unified_game_services`.
///
/// Backed by the EOS C SDK via pure-Dart `dart:ffi`. **Desktop only**
/// (Windows/macOS/Linux). The host supplies the EOS runtime shared library and
/// [EpicCredentials]; see the README and [EpicProvider] for the implemented
/// surface and the read-path gap.
///
/// On web this entry point exports an inert [EpicProvider] stub whose
/// constructor throws [UnsupportedError] — importing the package never breaks a
/// web build, but EOS cannot run there. On mobile (Android/iOS) the code
/// compiles but the constructor throws [UnsupportedError] at runtime.
library;

export 'src/epic_credentials.dart';
export 'src/epic_provider_web.dart'
    if (dart.library.io) 'src/epic_provider.dart'
    show EpicProvider;
