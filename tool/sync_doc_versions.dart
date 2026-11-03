// Keeps version references in Markdown docs in sync with the real package
// versions.
//
// Each package is versioned independently, so the source of truth is the
// `version:` of that package's own `pubspec.yaml` (not the root `VERSION`).
// For every `*.md` under `packages/` (READMEs, skills; CHANGELOGs are skipped)
// and the root README it rewrites:
//
// - dependency snippets: `unified_game_services_steam: ^0.2.0` -> `^<version>`
// - inline snippets:     `unified_game_services: ^0.2.0`       -> `^<version>`
// - prose mentions:      `unified_game_services_epic 0.2.0`    -> `<version>`
//
// Pure Dart, no deps. Run from the repo root after bumping versions:
//   dart run tool/sync_doc_versions.dart            # apply
//   dart run tool/sync_doc_versions.dart --check     # fail if anything would change
import 'dart:io';

void main(List<String> args) {
  final check = args.contains('--check');
  final root = Directory.current;
  final packagesDir = Directory('${root.path}/packages');
  if (!packagesDir.existsSync()) {
    stderr.writeln('error: run from the repo root (no packages/ dir)');
    exit(1);
  }

  // package name -> version, from each package's own pubspec.
  final versions = <String, String>{};
  for (final d in packagesDir.listSync().whereType<Directory>()) {
    final f = File('${d.path}/pubspec.yaml');
    if (!f.existsSync()) continue;
    final text = f.readAsStringSync();
    final name = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(text);
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(text);
    if (name != null && version != null) {
      versions[name.group(1)!] = version.group(1)!;
    }
  }

  final docs =
      <File>[
          File('${root.path}/README.md'),
          ...packagesDir.listSync(recursive: true).whereType<File>().where((f) {
            final p = f.path;
            return p.endsWith('.md') &&
                !p.endsWith('CHANGELOG.md') &&
                !p.contains('/.dart_tool/') &&
                !p.contains('/build/') &&
                !p.contains('/node_modules/');
          }),
        ].where((f) => f.existsSync()).toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  // Longest names first is unnecessary: the lookarounds below stop a name from
  // matching as a prefix of a longer one (`unified_game_services` vs
  // `unified_game_services_steam`).
  final names = versions.keys.map(RegExp.escape).join('|');
  final constraint = RegExp(
    '(?<![\\w])($names):(\\s*)\\^\\d+\\.\\d+\\.\\d+[^\\s`]*',
  );
  final prose = RegExp(
    '(?<![\\w])($names)(\\s+)v?\\d+\\.\\d+\\.\\d+(?![\\w.+-])',
  );

  var changed = false;
  for (final f in docs) {
    final original = f.readAsStringSync();
    var updated = original.replaceAllMapped(
      constraint,
      (m) => '${m[1]}:${m[2]}^${versions[m[1]]}',
    );
    updated = updated.replaceAllMapped(
      prose,
      (m) => '${m[1]}${m[2]}${versions[m[1]]}',
    );
    if (updated == original) continue;
    changed = true;
    final rel = f.path.replaceFirst('${root.path}/', '');
    if (check) {
      stdout.writeln('would update: $rel');
    } else {
      f.writeAsStringSync(updated);
      stdout.writeln('updated: $rel');
    }
  }

  if (check && changed) {
    stderr.writeln('check failed: doc versions out of sync with pubspecs');
    exit(1);
  }
  stdout.writeln(
    changed ? (check ? 'out of sync' : 'docs synced') : 'docs already in sync',
  );
}
