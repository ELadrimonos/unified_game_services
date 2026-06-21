// Syncs the master version (root `VERSION` file) into every workspace package.
//
// - Sets each `packages/*/pubspec.yaml` top-level `version:` to the master.
// - Rewrites internal dependency constraints (any workspace package depending on
//   another) to `^<master>` so cross-package ranges stay in lockstep.
//
// Pure Dart, no deps. Run from the repo root:
//   dart run tool/sync_version.dart            # apply
//   dart run tool/sync_version.dart --check     # fail if anything would change
import 'dart:io';

void main(List<String> args) {
  final check = args.contains('--check');
  final root = Directory.current;

  final versionFile = File('${root.path}/VERSION');
  if (!versionFile.existsSync()) {
    stderr.writeln('error: VERSION file not found at ${versionFile.path}');
    exit(1);
  }
  final master = versionFile.readAsStringSync().trim();
  if (master.isEmpty) {
    stderr.writeln('error: VERSION file is empty');
    exit(1);
  }

  final pubspecs = Directory('${root.path}/packages')
      .listSync()
      .whereType<Directory>()
      .map((d) => File('${d.path}/pubspec.yaml'))
      .where((f) => f.existsSync())
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  // Collect every workspace package name so we can rewrite internal deps.
  final names = <String>{};
  for (final f in pubspecs) {
    final m = RegExp(r'^name:\s*(\S+)', multiLine: true)
        .firstMatch(f.readAsStringSync());
    if (m != null) names.add(m.group(1)!);
  }

  var changed = false;
  for (final f in pubspecs) {
    final original = f.readAsStringSync();
    var updated = original;

    // Top-level version: line.
    updated = updated.replaceFirst(
      RegExp(r'^version:.*$', multiLine: true),
      'version: $master',
    );

    // Internal dependency constraints: `  <pkg>: ^x.y.z` (skip path: deps).
    for (final name in names) {
      updated = updated.replaceAllMapped(
        RegExp('^(\\s+)' + RegExp.escape(name) + r':\s*\^?\d[^\n]*$',
            multiLine: true),
        (m) => '${m.group(1)}$name: ^$master',
      );
    }

    if (updated != original) {
      changed = true;
      final rel = f.path.replaceFirst('${root.path}/', '');
      if (check) {
        stdout.writeln('would update: $rel');
      } else {
        f.writeAsStringSync(updated);
        stdout.writeln('updated: $rel -> $master');
      }
    }
  }

  if (check && changed) {
    stderr.writeln('check failed: package versions out of sync with VERSION');
    exit(1);
  }
  stdout.writeln(changed
      ? (check ? 'out of sync' : 'all packages synced to $master')
      : 'already synced to $master');
}
