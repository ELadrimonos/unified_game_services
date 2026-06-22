// Build hook: compiles the ffigen-generated Objective-C block trampolines
// (`lib/src/gamekit_bindings.dart.m`) into a dynamic library and registers it
// as a code asset, so the `@ffi.Native` externals in `gamekit_bindings.dart`
// resolve at runtime.
//
// This compiles *our* generated glue only — it does not ship or link Apple's
// GameKit SDK. GameKit itself is dlopen'd from the OS at runtime by
// `GameCenterProvider`, and the trampolines reference the Objective-C runtime
// via `-undefined dynamic_lookup` (resolved in-process against the already
// loaded `objective_c.dylib`).
//
// Only runs for macOS/iOS code-asset builds; a no-op everywhere else.
//
// Adapted from package:objective_c's own build hook.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const _objCFlags = ['-x', 'objective-c', '-fobjc-arc'];

/// Asset name must equal the generated library's package-relative path so it
/// matches the default asset id used by its `@ffi.Native` declarations
/// (`package:unified_game_services_game_center/src/gamekit_bindings.dart`).
const _assetName = 'src/gamekit_bindings.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final code = input.config.code;
    final os = code.targetOS;
    if (os != OS.macOS && os != OS.iOS) return;
    if (code.linkModePreference == LinkModePreference.static) {
      throw UnsupportedError('Static linking is not supported.');
    }

    // Generated Objective-C sources live under lib/src/.
    final srcDir = Directory.fromUri(input.packageRoot.resolve('lib/src/'));
    final mFiles = [
      for (final f in srcDir.listSync(recursive: true))
        if (f is File && f.path.endsWith('.m')) f.path,
    ];
    if (mFiles.isEmpty) return;

    final compiler = code.cCompiler?.compiler.toFilePath() ?? 'clang';
    final sysroot = _sdkPath(os, code);
    final target = _targetTriple(os, code);
    final minVersion = _minOSVersion(os, code);
    final commonFlags = ['-isysroot', sysroot, '-target', target, minVersion];

    final objDir = input.outputDirectory.resolve('obj/');
    Directory.fromUri(objDir).createSync(recursive: true);

    final objects = <String>[];
    for (final src in mFiles) {
      final obj = objDir.resolve('${src.split('/').last}.o').toFilePath();
      await _run(compiler, [
        ...commonFlags,
        ..._objCFlags,
        '-c',
        src,
        '-fpic',
        '-gline-tables-only',
        // The .m #imports the wrapper header in src/ (which pulls GameKit).
        '-I',
        input.packageRoot.resolve('src/').toFilePath(),
        '-I',
        input.packageRoot.resolve('lib/src/').toFilePath(),
        '-o',
        obj,
      ]);
      objects.add(obj);
    }

    final assetPath = input.outputDirectory.resolve('gamekit_bindings.dylib');
    await _run(compiler, [
      '-shared',
      '-Wl,-encryptable',
      // Objective-C runtime symbols (objc_retainBlock, DOBJC_*) resolve at
      // runtime against the in-process objective_c.dylib.
      '-undefined',
      'dynamic_lookup',
      ...commonFlags,
      ...objects,
      '-o',
      assetPath.toFilePath(),
    ]);

    output.dependencies.addAll(mFiles.map(Uri.file));
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        file: assetPath,
        linkMode: DynamicLoadingBundled(),
      ),
    );
  });
}

Future<void> _run(String exe, List<String> args) async {
  final proc = await Process.run(exe, args);
  if (proc.exitCode != 0) {
    throw Exception(
      'Command failed: $exe ${args.join(' ')}\n${proc.stdout}\n${proc.stderr}',
    );
  }
}

String _sdkPath(OS os, CodeConfig code) {
  final sdk = switch (os) {
    OS.iOS =>
      code.iOS.targetSdk == IOSSdk.iPhoneOS ? 'iphoneos' : 'iphonesimulator',
    _ => 'macosx',
  };
  return _firstLine('xcrun', ['--show-sdk-path', '--sdk', sdk]);
}

String _minOSVersion(OS os, CodeConfig code) => os == OS.iOS
    ? '-mios-version-min=${code.iOS.targetVersion}'
    : '-mmacos-version-min=${code.macOS.targetVersion}';

String _targetTriple(OS os, CodeConfig code) {
  final arch = code.targetArchitecture;
  if (os == OS.iOS) {
    final sim = code.iOS.targetSdk != IOSSdk.iPhoneOS;
    return switch (arch) {
      Architecture.arm64 =>
        sim ? 'arm64-apple-ios-simulator' : 'arm64-apple-ios',
      Architecture.x64 => 'x86_64-apple-ios-simulator',
      _ => throw UnsupportedError('Unsupported iOS arch: $arch'),
    };
  }
  return switch (arch) {
    Architecture.arm64 => 'arm64-apple-darwin',
    Architecture.x64 => 'x86_64-apple-darwin',
    _ => throw UnsupportedError('Unsupported macOS arch: $arch'),
  };
}

String _firstLine(String cmd, List<String> args) {
  final r = Process.runSync(cmd, args);
  if (r.exitCode != 0) throw Exception('$cmd failed: ${r.stderr}');
  return (r.stdout as String).split('\n').firstWhere((l) => l.isNotEmpty);
}
