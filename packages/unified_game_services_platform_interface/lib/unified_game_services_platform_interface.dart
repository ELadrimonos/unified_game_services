/// The shared contract every `unified_game_services` provider implements:
/// the [UnifiedGameServicesPlatform] base class, plus the models, capability
/// set, event hierarchy, and normalized exceptions all providers share.
///
/// App developers usually depend on `unified_game_services` (the facade) and
/// one or more provider packages instead of this package directly; provider
/// authors extend [UnifiedGameServicesPlatform] and override the operations
/// their service supports.
///
/// @docImport 'src/platform_interface/platform_interface.dart';
library;

export 'src/models/models.dart';
export 'src/platform_interface/platform_interface.dart';
export 'src/platform_interface/unified_id_table.dart';
export 'src/capabilities.dart';
export 'src/events.dart';
export 'src/exceptions.dart';
