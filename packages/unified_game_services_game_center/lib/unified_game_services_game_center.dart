/// An Apple Game Center provider for `unified_game_services`.
///
/// Backed by the GameKit framework through pure-Dart Objective-C FFI
/// (`package:objective_c`), with no Flutter dependency. Supports
/// authentication, achievements and leaderboards on **macOS and iOS only**.
/// Stats, rich presence, cloud save and friends are not supported. The host
/// must supply a signed app bundle and a pumped main run loop; see
/// `GameCenterProvider`.
///
/// On web this entry point exports an inert `GameCenterProvider` stub whose
/// constructor throws [UnsupportedError], so importing the package never
/// breaks a web build.
library;

export 'src/game_center_provider_web.dart'
    if (dart.library.io) 'src/game_center_provider.dart';
