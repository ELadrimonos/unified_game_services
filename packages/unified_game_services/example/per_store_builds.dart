// Per-store builds: ship a Steam-only build and an Epic-only build (and skip
// Google Play entirely for the Steam one, etc.) — WITHOUT any Flutter flavors.
//
// Why no flavors are needed
// -------------------------
// This is a federated plugin: every provider is a separate package, and the
// facade only fans out to the providers you *register at runtime*. A provider
// that is never constructed never runs — so "Steam-only" simply means "register
// only SteamProvider". The abstraction layer imposes no build system on you;
// flavors are just one optional tool for the *native* side (see below).
//
// The one thing that DOES differ per store: native runtime libs
// -------------------------------------------------------------
// Steam/Epic/GameCenter reach the OS via FFI, so the host ships a native lib:
//   Steam → steam_api64.dll / libsteam_api.dylib  (+ steam_appid.txt)
//   Epic  → EOSSDK-Win64-Shipping.dll / libEOSSDK-Mac-Shipping.dylib
// These are large, license-gated, and not cross-redistributable — you do NOT
// want the Epic runtime inside a Steam build. That, not the Dart code, is the
// real reason to separate builds. Google Play is REST (no native lib), so it is
// free to leave out of a Steam build — just don't register it.
//
// Three strategies, cheapest first
// --------------------------------
//   1. Runtime switch (this file): one binary, pick the store via --define.
//        dart run --define=STORE=epic example/per_store_builds.dart
//      Simplest; unused Dart deps still ship. Good for dev/testing.
//   2. Entry points: bin/main_steam.dart + bin/main_epic.dart, each importing
//      only its provider. Dart tree-shaking drops the other's code. Recommended
//      for pure-Dart / CLI targets. Package the matching native lib per build.
//   3. Flutter flavors / separate app packages: real dependency + asset
//      separation. Use when a Flutter app must bundle only one store's native
//      lib and credentials per variant. Flavors handle per-variant assets well.
//
// This file demonstrates strategy 1 (and reads like the body of a strategy-2
// entry point — copy the relevant branch into bin/main_<store>.dart).

import 'dart:io';

import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_epic/unified_game_services_epic.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

// Unified keys the app uses; each provider maps them to its own native id.
const kFirstWin = 'first_win';
const kHighScore = 'high_score';

/// Which store this build targets. Baked in at compile time via --define so a
/// tree-shaking build (strategy 2/3) can drop the branch it doesn't take.
const kStore = String.fromEnvironment('STORE', defaultValue: 'steam');

Future<void> main() async {
  final env = Platform.environment;

  // Build ONLY the provider for this store. The unregistered providers never
  // run — no Google Play, no Epic in a Steam build, etc.
  final UnifiedGameServicesPlatform provider = switch (kStore) {
    'steam' => SteamProvider(
      appId: int.parse(env['STEAM_APP_ID'] ?? '480'),
      achievementIds: {kFirstWin: 'ACH_WIN_ONE_GAME'},
      leaderboardIds: {kHighScore: 'Quickest Win'},
      // Host must ship libsteam_api + a running Steam client.
    ),
    'epic' => EpicProvider(
      credentials: EpicCredentials(
        productId: env['EOS_PRODUCT_ID']!,
        sandboxId: env['EOS_SANDBOX_ID']!,
        deploymentId: env['EOS_DEPLOYMENT_ID']!,
        clientId: env['EOS_CLIENT_ID']!,
        clientSecret: env['EOS_CLIENT_SECRET']!,
      ),
      achievementIds: {kFirstWin: 'ACH_WIN_ONE_GAME'},
      leaderboardIds: {kHighScore: 'high_score'},
      // Host must ship the EOSSDK runtime lib for the platform.
    ),
    final other => throw ArgumentError(
      'Unknown STORE "$other". Build with --define=STORE=steam|epic.',
    ),
  };

  final services = UnifiedGameServices(providers: [provider]);
  stdout.writeln('Build target: $kStore → ${provider.runtimeType}\n');

  await services.signIn();

  if (services.supports(GameCapability.achievements)) {
    await services.unlockAchievement(kFirstWin);
    stdout.writeln('Unlocked "$kFirstWin".');
  }
  if (services.supports(GameCapability.leaderboards)) {
    await services.submitScore(leaderboardId: kHighScore, score: 1500);
    stdout.writeln('Submitted 1500 to "$kHighScore".');
  }
}
