import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_epic/unified_game_services_epic.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

import '../config/provider_config.dart';
import '../env.dart';

/// Native (dart:ffi) provider construction. Reached only on native hosts.
/// Steam + Epic are still gated to desktop at runtime — on Android/iOS the
/// ffi packages are linked but the providers are never instantiated (no
/// Steamworks / EOS runtime there), and a skip reason is reported instead.
void buildNativeProviders({
  required AppConfig cfg,
  required Environment env,
  required void Function(ProviderKind kind, UnifiedGameServicesPlatform p) add,
  required void Function(ProviderKind kind, String reason) skip,
}) {
  // ── Steam ──────────────────────────────────────────────────────────────
  if (cfg.steam.enabled) {
    if (!env.isDesktop) {
      skip(ProviderKind.steam, env.unavailableReason(ProviderKind.steam)!);
    } else {
      add(
        ProviderKind.steam,
        SteamProvider(
          appId: cfg.steam.appIdValue,
          achievementIds: cfg.steam.achievementIds,
          leaderboardIds: cfg.steam.leaderboardIds,
        ),
      );
    }
  }

  // ── Epic ───────────────────────────────────────────────────────────────
  if (cfg.epic.enabled) {
    if (!env.isDesktop) {
      skip(ProviderKind.epic, env.unavailableReason(ProviderKind.epic)!);
    } else if (!cfg.epic.isComplete) {
      skip(
        ProviderKind.epic,
        'Enabled but missing credentials (productId / sandboxId / '
        'deploymentId / clientId / clientSecret).',
      );
    } else {
      add(
        ProviderKind.epic,
        EpicProvider(
          credentials: EpicCredentials(
            productId: cfg.epic.productId,
            sandboxId: cfg.epic.sandboxId,
            deploymentId: cfg.epic.deploymentId,
            clientId: cfg.epic.clientId,
            clientSecret: cfg.epic.clientSecret,
            encryptionKey: cfg.epic.encryptionKey.isEmpty
                ? null
                : cfg.epic.encryptionKey,
          ),
          devAuthHost: cfg.epic.devAuthHost.isEmpty
              ? null
              : cfg.epic.devAuthHost,
          devAuthCredentialName: cfg.epic.devAuthCredentialName.isEmpty
              ? null
              : cfg.epic.devAuthCredentialName,
          achievementIds: cfg.epic.achievementIds,
          leaderboardIds: cfg.epic.leaderboardIds,
        ),
      );
    }
  }
}
