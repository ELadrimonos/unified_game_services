import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';
import 'package:unified_game_services_google_play_flutter/unified_game_services_google_play_flutter.dart';

import '../config/provider_config.dart';
import '../env.dart';
import 'native_providers.dart';

/// Why a provider is or isn't part of the active facade.
enum ProviderState {
  /// Built and added to the facade.
  active,

  /// Turned off in config.
  disabled,

  /// Enabled but not built (missing credentials, or unavailable in this
  /// environment). [detail] explains why.
  skipped,
}

class ProviderStatus {
  ProviderStatus(this.kind, this.state, {this.detail, this.instance});

  final ProviderKind kind;
  final ProviderState state;
  final String? detail;

  /// The built provider, when [state] is [ProviderState.active]. Lets the UI
  /// read its `capabilities`.
  final UnifiedGameServicesPlatform? instance;
}

/// The outcome of assembling providers for the current config + environment.
class ProviderBuild {
  ProviderBuild(this.facade, this.statuses);

  /// The facade over every active provider. Null when none were built.
  final UnifiedGameServices? facade;

  /// Per-provider status, in display order.
  final List<ProviderStatus> statuses;

  List<UnifiedGameServicesPlatform> get active => statuses
      .where((s) => s.state == ProviderState.active)
      .map((s) => s.instance!)
      .toList(growable: false);
}

/// Assembles the providers the config asks for, registering each only where it
/// can run. Pure-Dart providers (GameJolt, Google Play) are built here; the
/// dart:ffi providers (Steam, Epic) go through the conditional [native]
/// builder so they never enter a web bundle.
ProviderBuild buildProviders(AppConfig cfg, Environment env) {
  final statuses = <ProviderKind, ProviderStatus>{};
  final active = <UnifiedGameServicesPlatform>[];

  void add(ProviderKind kind, UnifiedGameServicesPlatform p) {
    active.add(p);
    statuses[kind] = ProviderStatus(kind, ProviderState.active, instance: p);
  }

  void skip(ProviderKind kind, String reason) {
    statuses[kind] = ProviderStatus(
      kind,
      ProviderState.skipped,
      detail: reason,
    );
  }

  void disabled(ProviderKind kind) {
    statuses[kind] = ProviderStatus(kind, ProviderState.disabled);
  }

  // ── GameJolt (REST — runs everywhere) ─────────────────────────────────────
  if (!cfg.gameJolt.enabled) {
    disabled(ProviderKind.gameJolt);
  } else if (!cfg.gameJolt.isComplete) {
    skip(
      ProviderKind.gameJolt,
      'Enabled but missing credentials (gameId / privateKey / username / '
      'userToken).',
    );
  } else {
    add(
      ProviderKind.gameJolt,
      GameJoltProvider(
        gameId: cfg.gameJolt.gameId,
        privateKey: cfg.gameJolt.privateKey,
        username: cfg.gameJolt.username,
        userToken: cfg.gameJolt.userToken,
      ),
    );
  }

  // ── Google Play (native on Android, REST elsewhere) ───────────────────────
  if (!cfg.googlePlay.enabled) {
    disabled(ProviderKind.googlePlay);
  } else {
    AuthStrategy? auth;
    var ok = true;
    if (!env.isAndroid) {
      // Off-Android the REST tier needs an OAuth token. The loopback flow
      // needs a Desktop OAuth client id (and only actually runs on desktop —
      // a browser can't bind the loopback socket).
      if (cfg.googlePlay.oauthClientId.isEmpty) {
        skip(
          ProviderKind.googlePlay,
          'Off Android, the REST tier needs a Desktop OAuth client id for the '
          'loopback sign-in flow.',
        );
        ok = false;
      } else {
        auth = LoopbackOAuthStrategy(
          clientId: cfg.googlePlay.oauthClientId,
          clientSecret: cfg.googlePlay.oauthClientSecret.isEmpty
              ? null
              : cfg.googlePlay.oauthClientSecret,
        );
      }
    }
    if (ok) {
      add(
        ProviderKind.googlePlay,
        GooglePlayGamesFlutter.create(
          auth: auth,
        ),
      );
    }
  }

  // ── Steam + Epic (dart:ffi — desktop only; web stub builds nothing) ───────
  if (!cfg.steam.enabled) disabled(ProviderKind.steam);
  if (!cfg.epic.enabled) disabled(ProviderKind.epic);
  buildNativeProviders(cfg: cfg, env: env, add: add, skip: skip);

  final ordered = [
    statuses[ProviderKind.gameJolt]!,
    statuses[ProviderKind.googlePlay]!,
    statuses[ProviderKind.steam]!,
    statuses[ProviderKind.epic]!,
  ];

  final Map<String, Map<String, String>> achievementsMap = {};
  final Map<String, Map<String, String>> leaderboardsMap = {};

  void addMappings(
    String providerId,
    Map<String, String>? achs,
    Map<String, String>? lbs,
  ) {
    for (final e in (achs ?? const <String, String>{}).entries) {
      (achievementsMap[e.key] ??= {})[providerId] = e.value;
    }
    for (final e in (lbs ?? const <String, String>{}).entries) {
      (leaderboardsMap[e.key] ??= {})[providerId] = e.value;
    }
  }

  addMappings('gamejolt', cfg.gameJolt.achievementIds, cfg.gameJolt.leaderboardIds);
  addMappings('google_play', cfg.googlePlay.achievementIds, cfg.googlePlay.leaderboardIds);
  addMappings('steam', cfg.steam.achievementIds, cfg.steam.leaderboardIds);
  addMappings('epic', cfg.epic.achievementIds, cfg.epic.leaderboardIds);

  return ProviderBuild(
    active.isEmpty
        ? null
        : UnifiedGameServices(
            providers: active,
            achievements: achievementsMap,
            leaderboards: leaderboardsMap,
          ),
    ordered,
  );
}
