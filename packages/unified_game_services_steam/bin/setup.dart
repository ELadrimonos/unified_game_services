#!/usr/bin/env dart
// One-shot setup for the Steam native library, for apps that depend on
// unified_game_services_steam.
//
//   dart run unified_game_services_steam:setup [--app-id 480] [--output .]
//
// pub.dev ships Dart source only — the Steamworks native library is NOT
// delivered with this package (Valve's license forbids redistributing the SDK).
// The transitive `steamworks` package bundles the official redistributables,
// though, so this tool copies the right one for your OS into your project and
// (optionally) writes a dev `steam_appid.txt`.
//
// For a shipped build you must distribute the native lib with your app and
// obtain it under your own Steamworks agreement; see the package README.

import 'dart:convert';
import 'dart:io';

const _libByOs = {
  'windows': 'steam_api64.dll',
  'linux': 'libsteam_api.so',
  'macos': 'libsteam_api.dylib',
};

void main(List<String> argv) {
  String? appId;
  var output = '.';
  for (var i = 0; i < argv.length; i++) {
    switch (argv[i]) {
      case '--app-id':
        appId = argv[++i];
      case '--output' || '-o':
        output = argv[++i];
      case '-h' || '--help':
        stdout.writeln('Usage: dart run unified_game_services_steam:setup '
            '[--app-id <id>] [--output <dir>]');
        return;
    }
  }

  final os = Platform.operatingSystem;
  final libName = _libByOs[os];
  if (libName == null) _fail('Unsupported OS: $os');

  final swRoot = _findSteamworks();
  final src = File('$swRoot/example/$libName');
  if (!src.existsSync()) {
    _fail('Native lib not found in the steamworks package: ${src.path}');
  }

  Directory(output).createSync(recursive: true);
  final dest = '$output/$libName';
  src.copySync(dest);
  stdout.writeln('Copied $libName -> $dest');

  if (appId != null) {
    File('$output/steam_appid.txt').writeAsStringSync('$appId\n');
    stdout.writeln('Wrote $output/steam_appid.txt ($appId)');
  } else {
    stdout.writeln('No --app-id given; create steam_appid.txt yourself for '
        'running outside Steam during development.');
  }

  _printRunHint(os, libName, output);
}

/// Resolves the steamworks package root from the consumer's package config.
String _findSteamworks() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) {
    _fail('.dart_tool/package_config.json not found. Run this from your '
        'project root after `dart pub get`.');
  }
  final json = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  final packages = (json['packages'] as List).cast<Map<String, dynamic>>();
  final sw = packages.where((p) => p['name'] == 'steamworks').toList();
  if (sw.isEmpty) {
    _fail('The `steamworks` package is not resolved. Add '
        'unified_game_services_steam to your pubspec and run `dart pub get`.');
  }
  // rootUri is resolved relative to the .dart_tool/ directory.
  final rootUri = config.parent.uri.resolveUri(Uri.parse(sw.first['rootUri'] as String));
  return rootUri.toFilePath().replaceAll(RegExp(r'[/\\]$'), '');
}

void _printRunHint(String os, String libName, String output) {
  stdout.writeln('\nThe dynamic loader must find $libName at runtime:');
  switch (os) {
    case 'windows':
      stdout.writeln('  Windows searches the executable directory and the '
          'working directory — keep $libName next to your app / run dir.');
    case 'linux':
      stdout.writeln('  Linux does not search the working directory. Run with:');
      stdout.writeln('    LD_LIBRARY_PATH="$output" dart run …');
      stdout.writeln('  or copy it to /usr/local/lib, or set an rpath.');
    case 'macos':
      stdout.writeln('  macOS does not search the working directory. Run with:');
      stdout.writeln('    DYLD_LIBRARY_PATH="$output" dart run …');
      stdout.writeln('  or copy it to /usr/local/lib.');
  }
  stdout.writeln('Also make sure the Steam client is running and logged in.');
}

Never _fail(String msg) {
  stderr.writeln('error: $msg');
  exit(1);
}
