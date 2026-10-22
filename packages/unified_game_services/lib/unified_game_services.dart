/// Unified, multi-platform game services API for Dart.
///
/// Import this single package to get the [UnifiedGameServices] facade, the
/// global [GameServices] entry point, and the shared models, capabilities,
/// events and exceptions (re-exported from
/// `unified_game_services_platform_interface`). Add a provider package
/// (Steam, GameJolt, …) and pass its provider to the facade.
///
/// @docImport 'src/game_services.dart';
/// @docImport 'src/unified_game_services_base.dart';
library;

export 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

export 'src/game_services.dart';
export 'src/multi_provider_result.dart';
export 'src/achievement_overview.dart';
export 'src/unified_game_services_base.dart';
