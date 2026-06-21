#!/usr/bin/env dart
// Dev tool: obtain the Steamworks SDK, generate the `steamworks` Dart bindings
// for a target platform via `steamworks_gen`, and copy the matching native
// redistributable next to the example.
//
// The Steamworks SDK is login-gated at https://partner.steamgames.com — it
// cannot be downloaded anonymously. Provide it one of these ways (first match
// wins):
//   --sdk <dir>     | env STEAMWORKS_SDK      extracted SDK root
//   --zip <file>    | env STEAMWORKS_SDK_ZIP  SDK zip on disk
//   --url <url>     | env STEAMWORKS_SDK_URL  your own/CI mirror of the SDK zip
//
// Usage:
//   dart run tool/generate_steamworks.dart --sdk /path/to/sdk
//   dart run tool/generate_steamworks.dart --zip steamworks_sdk_162.zip -t linux
//   STEAMWORKS_SDK_URL=https://… dart run tool/generate_steamworks.dart
//
// NOTE: `steamworks_gen` mutates this package's pubspec.yaml (it runs
// `pub remove ffi` + `pub add ffi`). That is expected; re-pin ffi if needed.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:archive/archive.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

const _targets = {'win', 'linux', 'mac', 'arm'};

/// Relative path of the API description inside the SDK.
const _steamApiJsonRel = 'public/steam/steam_api.json';

/// Native redistributable per target, relative to the SDK root.
const _nativeLib = {
  'win': 'redistributable_bin/win64/steam_api64.dll',
  'linux': 'redistributable_bin/linux64/libsteam_api.so',
  'mac': 'redistributable_bin/osx/libsteam_api.dylib',
  'arm': 'redistributable_bin/osx/libsteam_api.dylib',
};

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('sdk', help: 'Path to an extracted Steamworks SDK root.')
    ..addOption('zip', help: 'Path to a Steamworks SDK zip to extract.')
    ..addOption('url', help: 'URL of a Steamworks SDK zip to download.')
    ..addOption('output',
        abbr: 'o',
        help: 'Output dir for generated bindings.',
        defaultsTo: '.steamworks')
    ..addOption('target',
        abbr: 't',
        help: 'Target platform.',
        allowed: _targets,
        defaultsTo: _hostTarget())
    ..addOption('app-id',
        help: 'App id written to example/steam_appid.txt.', defaultsTo: '480')
    ..addFlag('copy-natives',
        help: 'Copy the native lib into example/.', defaultsTo: true)
    ..addFlag('analyze',
        help: 'Run dart analyze on the generated bindings.', defaultsTo: true)
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    _fail('${e.message}\n\n${parser.usage}');
  }
  if (args['help'] as bool) {
    stdout.writeln('Generate Steamworks bindings for the Dart package.\n');
    stdout.writeln(parser.usage);
    return;
  }

  final packageDir = _packageDir();
  final target = args['target'] as String;
  final outputDir = p.isAbsolute(args['output'] as String)
      ? args['output'] as String
      : p.join(packageDir, args['output'] as String, target);

  final sdkDir = await _resolveSdk(args, packageDir);
  _log('Using SDK: $sdkDir');

  final steamApiJson = _findSteamApiJson(sdkDir);
  _log('steam_api.json: $steamApiJson');

  await _generate(
    packageDir: packageDir,
    steamApiJson: steamApiJson,
    output: outputDir,
    target: target,
  );

  if (args['copy-natives'] as bool) {
    _copyNativeLib(sdkDir, target, p.join(packageDir, 'example'));
  }
  _writeAppId(p.join(packageDir, 'example'), args['app-id'] as String);

  if (args['analyze'] as bool) {
    await _run('dart', ['analyze', outputDir], cwd: packageDir, allowFail: true);
  }

  _log('Done. Generated bindings: $outputDir');
  stdout.writeln('''

Next steps — point the package at these bindings on this platform via a
dependency_override in the workspace root pubspec.yaml:

  dependency_overrides:
    steamworks:
      path: ${p.relative(outputDir)}

Then `dart pub get`. The published `steamworks` ships Windows bindings; this
override is only needed for linux/mac/arm (see steamworks issue #17).''');
}

// ─── SDK acquisition ─────────────────────────────────────────────────────────

Future<String> _resolveSdk(ArgResults args, String packageDir) async {
  final sdkArg = (args['sdk'] as String?) ?? Platform.environment['STEAMWORKS_SDK'];
  if (sdkArg != null && sdkArg.isNotEmpty) {
    if (!Directory(sdkArg).existsSync()) _fail('SDK dir not found: $sdkArg');
    return _sdkRoot(sdkArg);
  }

  final zipArg = (args['zip'] as String?) ?? Platform.environment['STEAMWORKS_SDK_ZIP'];
  final urlArg = (args['url'] as String?) ?? Platform.environment['STEAMWORKS_SDK_URL'];

  final extractDir = p.join(packageDir, '.steamworks', 'sdk');
  if (zipArg != null && zipArg.isNotEmpty) {
    if (!File(zipArg).existsSync()) _fail('SDK zip not found: $zipArg');
    _extractZip(File(zipArg).readAsBytesSync(), extractDir);
    return _sdkRoot(extractDir);
  }
  if (urlArg != null && urlArg.isNotEmpty) {
    _log('Downloading SDK: $urlArg');
    final bytes = await _download(urlArg);
    _extractZip(bytes, extractDir);
    return _sdkRoot(extractDir);
  }

  _fail('No Steamworks SDK provided. Use --sdk/--zip/--url or the matching '
      'STEAMWORKS_SDK[_ZIP|_URL] env var.\nThe SDK is login-gated: download it '
      'from https://partner.steamgames.com/downloads/list and pass it here.');
}

/// The SDK zip extracts to an `sdk/` subdir; accept either layout.
String _sdkRoot(String dir) {
  final nested = p.join(dir, 'sdk');
  if (File(p.join(nested, _steamApiJsonRel)).existsSync()) return nested;
  return dir;
}

Future<List<int>> _download(String url) async {
  final client = HttpClient();
  try {
    var uri = Uri.parse(url);
    for (var redirects = 0; redirects < 5; redirects++) {
      final req = await client.getUrl(uri);
      req.followRedirects = false;
      final res = await req.close();
      if (res.isRedirect) {
        final loc = res.headers.value(HttpHeaders.locationHeader);
        if (loc == null) _fail('Redirect without Location from $uri');
        uri = uri.resolve(loc);
        await res.drain<void>();
        continue;
      }
      if (res.statusCode != HttpStatus.ok) {
        _fail('Download failed (${res.statusCode}) for $uri');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in res) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }
    _fail('Too many redirects for $url');
  } finally {
    client.close(force: true);
  }
}

void _extractZip(List<int> bytes, String destDir) {
  _log('Extracting SDK -> $destDir');
  final archive = ZipDecoder().decodeBytes(bytes);
  for (final entry in archive) {
    final outPath = p.join(destDir, entry.name);
    if (entry.isFile) {
      File(outPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(entry.content as List<int>);
    } else {
      Directory(outPath).createSync(recursive: true);
    }
  }
}

String _findSteamApiJson(String sdkDir) {
  final direct = p.join(sdkDir, _steamApiJsonRel);
  if (File(direct).existsSync()) return direct;
  // Fallback: search the tree.
  for (final entry in Directory(sdkDir).listSync(recursive: true)) {
    if (entry is File && p.basename(entry.path) == 'steam_api.json') {
      return entry.path;
    }
  }
  _fail('steam_api.json not found under $sdkDir');
}

// ─── Generation ──────────────────────────────────────────────────────────────

Future<void> _generate({
  required String packageDir,
  required String steamApiJson,
  required String output,
  required String target,
}) async {
  Directory(output).createSync(recursive: true);
  _log('Generating bindings (target=$target)…');
  // steamworks_gen rewrites the CWD pubspec's ffi dep — run it in the package.
  final code = await _run(
    'dart',
    ['run', 'steamworks_gen', '-o', output, '-t', target, steamApiJson],
    cwd: packageDir,
  );
  if (code != 0) _fail('steamworks_gen exited with $code');
}

// ─── Native lib + app id ─────────────────────────────────────────────────────

void _copyNativeLib(String sdkDir, String target, String destDir) {
  final rel = _nativeLib[target];
  if (rel == null) {
    _log('No native lib mapping for target "$target"; skipping copy.');
    return;
  }
  final src = File(p.join(sdkDir, rel));
  if (!src.existsSync()) {
    _log('Native lib not found in SDK: ${src.path}; skipping copy.');
    return;
  }
  Directory(destDir).createSync(recursive: true);
  final dest = p.join(destDir, p.basename(rel));
  src.copySync(dest);
  _log('Copied native lib -> $dest');
}

void _writeAppId(String dir, String appId) {
  final file = File(p.join(dir, 'steam_appid.txt'));
  if (file.existsSync()) return;
  Directory(dir).createSync(recursive: true);
  file.writeAsStringSync('$appId\n');
  _log('Wrote ${file.path} ($appId)');
}

// ─── Process / logging ───────────────────────────────────────────────────────

String _hostTarget() {
  if (Platform.isWindows) return 'win';
  if (Platform.isLinux) return 'linux';
  if (Platform.isMacOS) return 'mac';
  return 'win';
}

String _packageDir() {
  // tool/ lives directly under the package root.
  final scriptDir = p.dirname(Platform.script.toFilePath());
  return p.normalize(p.join(scriptDir, '..'));
}

Future<int> _run(
  String exe,
  List<String> args, {
  required String cwd,
  bool allowFail = false,
}) async {
  final proc = await Process.start(exe, args,
      workingDirectory: cwd, mode: ProcessStartMode.inheritStdio);
  final code = await proc.exitCode;
  if (code != 0 && !allowFail) return code;
  return code;
}

void _log(String msg) => stdout.writeln('[steamworks] $msg');

Never _fail(String msg) {
  stderr.writeln('error: $msg');
  exit(1);
}
