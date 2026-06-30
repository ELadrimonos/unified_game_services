/// Epic Online Services (EOS) provider for `unified_game_services`.
///
/// Backed by the EOS C SDK via pure-Dart `dart:ffi`. Desktop only. The host
/// supplies the EOS runtime shared library and [EpicCredentials]; see the
/// README and [EpicProvider] for the implemented surface and the read-path gap.
library;

export 'src/epic_credentials.dart';
export 'src/epic_provider.dart' show EpicProvider;
