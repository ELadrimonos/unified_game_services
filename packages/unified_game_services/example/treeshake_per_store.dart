// Compile-time tree-shaking of FFI providers out of a mobile/web build, from a
// SINGLE entry point — no per-platform main files, no Flutter flavors.
//
// The problem
// -----------
// Steam and Epic are `dart:ffi` (desktop-only). Dart has NO OS-conditional
// import (`dart.library.*` distinguishes web vs io, never android/ios/desktop),
// and `dart:ffi` exists on mobile too — so nothing keeps their Dart out of an
// Android/iOS bundle automatically. A runtime gate (`Platform.isAndroid`, a
// throwing constructor) does NOT tree-shake: the symbol stays reachable, so the
// compiler keeps the whole steamworks/EOS Dart closure as dead weight.
//   (The NATIVE libs are never bundled on mobile regardless — steamworks/EOS are
//    pure-Dart packages, not Flutter plugins, so there's no .so/.aar to pack.
//    This file is only about dropping the dead Dart.)
//
// The fix: `const bool.fromEnvironment` guards
// -------------------------------------------
// A `const` flag makes the branch a compile-time constant. When the flag is
// unset the branch is const-`false`, so the tree-shaker proves the provider is
// unreachable and removes it — and its entire transitive `dart:ffi` closure —
// from that build. The provider is only ever referenced inside its own guard,
// which is what makes the elimination sound.
//
//   # desktop build — flags on → Steam/Epic compiled in
//   dart compile exe example/treeshake_per_store.dart \
//     --define=ENABLE_STEAM=true --define=ENABLE_EPIC=true
//
//   # mobile/web build — flags unset → const false → both tree-shaken out
//   flutter build appbundle           # (from a Flutter host importing this logic)
//   dart compile js example/treeshake_per_store.dart -o out.js
//
// Rule: reference each FFI provider ONLY inside its `if (kEnableX)` block. A
// single reference outside a const-false guard re-anchors the symbol and defeats
// the tree-shake.

import 'package:unified_game_services/unified_game_services.dart';
import 'package:unified_game_services_epic/unified_game_services_epic.dart';
import 'package:unified_game_services_gamejolt/unified_game_services_gamejolt.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

// Compile-time flags. Unset → `false` → the guarded provider is tree-shaken.
const bool kEnableSteam = bool.fromEnvironment('ENABLE_STEAM');
const bool kEnableEpic = bool.fromEnvironment('ENABLE_EPIC');
// GameJolt is REST (pure Dart, all platforms) — no flag, always available.

Future<void> main() async {
  final providers = <UnifiedGameServicesPlatform>[];

  // GameJolt: portable, no guard needed.
  providers.add(
    GameJoltProvider(
      gameId: const String.fromEnvironment('GAMEJOLT_GAME_ID'),
      privateKey: const String.fromEnvironment('GAMEJOLT_PRIVATE_KEY'),
      username: const String.fromEnvironment('GAMEJOLT_USERNAME'),
      userToken: const String.fromEnvironment('GAMEJOLT_GAME_TOKEN'),
    ),
  );

  // Steam: the ONLY reference to SteamProvider is inside this const guard, so a
  // build without --define=ENABLE_STEAM=true drops it entirely (desktop-only).
  if (kEnableSteam) {
    providers.add(SteamProvider(appId: 480));
  }

  // Epic: same pattern. Desktop-only; tree-shaken unless ENABLE_EPIC is set.
  if (kEnableEpic) {
    providers.add(
      EpicProvider(
        credentials: const EpicCredentials(
          productId: String.fromEnvironment('EOS_PRODUCT_ID'),
          sandboxId: String.fromEnvironment('EOS_SANDBOX_ID'),
          deploymentId: String.fromEnvironment('EOS_DEPLOYMENT_ID'),
          clientId: String.fromEnvironment('EOS_CLIENT_ID'),
          clientSecret: String.fromEnvironment('EOS_CLIENT_SECRET'),
        ),
      ),
    );
  }

  final services = UnifiedGameServices(providers: providers);
  await services.signIn();
  if (services.supports(GameCapability.achievements)) {
    await services.unlockAchievement('first_win');
  }
}
