// jnigen config for the Play Games v2 Java SDK bindings.
//
// This repo is NOT a Flutter project, so the usual jnigen Android path
// (`AndroidSdk(addGradleDeps: true)` against an example app) does not apply.
// Instead `tool/regenerate_bindings.sh` resolves the Play Games v2 aar + its
// transitive deps from Google's Maven, extracts each `classes.jar` into
// `build/jnigen/classpath/`, and adds the platform `android.jar`. Run that
// script (not this file directly) to regenerate.
//
// Requires: ANDROID_SDK_ROOT, a JDK, and network access to Google's Maven.

import 'dart:io';

import 'package:jnigen/jnigen.dart';

final _obfuscated = RegExp(r'^zz[a-z]{1,2}$');

Future<void> main() async {
  var currentClass = '';
  final packageRoot = Platform.script.resolve('../');

  final generator = JniGenerator(
    input: Input(
      backend: SummarizerBackend.asm,
      // Populated by tool/regenerate_bindings.sh. Each jar must be listed
      // individually — a directory of jars is not a valid classpath entry.
      classPath: [
        packageRoot.resolve(
          'build/jnigen/classpath/play-services-games-v2.jar',
        ),
        packageRoot.resolve('build/jnigen/classpath/play-services-tasks.jar'),
        packageRoot.resolve('build/jnigen/classpath/play-services-base.jar'),
        packageRoot.resolve(
          'build/jnigen/classpath/play-services-basement.jar',
        ),
        packageRoot.resolve('build/jnigen/classpath/android.jar'),
      ],
      // Only the surface the provider touches; jnigen pulls referenced types
      // transitively, so keep this list tight.
      classes: [
        'com.google.android.gms.games.PlayGames',
        'com.google.android.gms.games.PlayGamesSdk',
        'com.google.android.gms.games.GamesSignInClient',
        'com.google.android.gms.games.AuthenticationResult',
        'com.google.android.gms.games.AchievementsClient',
        'com.google.android.gms.games.LeaderboardsClient',
        'com.google.android.gms.games.PlayersClient',
        'com.google.android.gms.games.Player',
        // Task + listener: lets the provider await `Task<T>` results without
        // blocking (addOnCompleteListener), e.g. for the native UI intents.
        'com.google.android.gms.tasks.Task',
        'com.google.android.gms.tasks.OnCompleteListener',
        // Only Activity.startActivityForResult is kept (see the visitor), to
        // launch the intents returned by the *Client.get*Intent() calls.
        'android.app.Activity',
      ],
    ),
    // The SDK ships obfuscated members (`zza`, `zzh`, ...). Some are named like
    // obfuscated types (`zza`), so the generated method shadows the type inside
    // its class and breaks compilation. They are not public API: drop them.
    visitors: [
      Visitor(
        classDecl: (c) {
          currentClass = c.binaryName;
          // Nested Activity types are not needed.
          if (c.binaryName.startsWith(r'android.app.Activity$')) {
            c.isIncluded = false;
          }
        },
        method: (m) {
          if (_obfuscated.hasMatch(m.name)) m.isIncluded = false;
          // android.app.Activity is huge; keep a single method.
          if (currentClass == 'android.app.Activity' &&
              (m.isConstructor || m.originalName != 'startActivityForResult')) {
            m.isIncluded = false;
          }
        },
        field: (f) {
          if (_obfuscated.hasMatch(f.name)) f.isIncluded = false;
        },
      ),
    ],
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/playgames_bindings.dart'),
        structure: OutputStructure.singleFile,
      ),
    ),
  );

  await generator.generate();
}
