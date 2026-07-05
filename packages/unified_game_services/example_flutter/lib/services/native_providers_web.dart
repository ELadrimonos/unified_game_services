import 'package:unified_game_services/unified_game_services.dart';

import '../config/provider_config.dart';
import '../env.dart';

/// Web stub: Steam + Epic are dart:ffi and are never compiled into a web
/// build, so there is nothing to construct here. If the user enabled them, we
/// surface a clear skip reason instead of failing the build.
void buildNativeProviders({
  required AppConfig cfg,
  required Environment env,
  required void Function(ProviderKind kind, UnifiedGameServicesPlatform p) add,
  required void Function(ProviderKind kind, String reason) skip,
}) {
  if (cfg.steam.enabled) {
    skip(
      ProviderKind.steam,
      'Steam uses dart:ffi (Steamworks) — excluded from web builds entirely.',
    );
  }
  if (cfg.epic.enabled) {
    skip(
      ProviderKind.epic,
      'Epic uses dart:ffi (EOS SDK) — excluded from web builds entirely.',
    );
  }
}
