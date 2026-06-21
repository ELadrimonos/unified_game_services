/// Unified, multi-platform game services API for Dart.
///
/// Import this single package to get the [UnifiedGameServices] facade plus the
/// shared models, capabilities, events and exceptions (re-exported from
/// `unified_game_services_platform_interface`). Add a provider package
/// (Steam, GameJolt, …) and pass its provider to the facade.
library;

export 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

export 'src/aggregate_exception.dart';
export 'src/unified_game_services_base.dart';
