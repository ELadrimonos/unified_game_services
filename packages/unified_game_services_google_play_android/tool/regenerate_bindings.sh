#!/usr/bin/env bash
# Regenerate the Play Games v2 JNI bindings (lib/src/playgames_bindings.dart).
#
# This repo is pure Dart (no Flutter/Gradle), and Play Games lives on Google's
# Maven (not Maven Central), so we resolve the aar + transitive deps from
# Google's Maven ourselves, extract each classes.jar, add the platform
# android.jar, and run jnigen against that classpath.
#
# Requirements:
#   * ANDROID_SDK_ROOT (or ANDROID_HOME) pointing at an Android SDK with at
#     least one installed platform (android.jar).
#   * A JDK (8–21). curl + unzip. Network access to dl.google.com.
#   * `dart pub global activate jnigen` (or run via `dart run jnigen`).
#
# Usage: tool/regenerate_bindings.sh [PLAY_GAMES_VERSION]
set -euo pipefail

GAMES_VERSION="${1:-21.0.0}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$SDK" ]]; then
  echo "ERROR: set ANDROID_SDK_ROOT or ANDROID_HOME." >&2
  exit 1
fi

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CP_DIR="$PKG_DIR/build/jnigen/classpath"
WORK="$PKG_DIR/build/jnigen/work"
rm -rf "$CP_DIR" "$WORK"
mkdir -p "$CP_DIR" "$WORK"

GOOGLE_MAVEN="https://dl.google.com/dl/android/maven2"

# Resolve a maven artifact (group:artifact:version[:ext]) from Google's Maven
# into $WORK, then unzip any aar's classes.jar into the classpath dir.
fetch() {
  local coord="$1"
  local group artifact version ext path file url
  group="${coord%%:*}"; coord="${coord#*:}"
  artifact="${coord%%:*}"; coord="${coord#*:}"
  version="${coord%%:*}"
  ext="aar"; [[ "$coord" == *:* ]] && ext="${coord##*:}"
  path="${group//.//}/$artifact/$version"
  file="$artifact-$version.$ext"
  url="$GOOGLE_MAVEN/$path/$file"
  echo "  fetch $url"
  curl -fsSL "$url" -o "$WORK/$file" || { echo "  (skip, not found: $file)"; return 0; }
  if [[ "$ext" == "aar" ]]; then
    (cd "$WORK" && unzip -o -q "$file" classes.jar && mv classes.jar "$CP_DIR/$artifact-$version.jar")
  else
    cp "$WORK/$file" "$CP_DIR/$file"
  fi
}

echo "Resolving Play Games v2 ($GAMES_VERSION) + key transitive deps from Google Maven…"
# The core artifact plus the GMS task/base libs the API signatures reference.
# (Transitive AndroidX deps that only appear in private signatures are not
# strictly needed for the public surface; add more here if jnigen reports
# missing referenced types.)
fetch "com.google.android.gms:play-services-games-v2:$GAMES_VERSION"
fetch "com.google.android.gms:play-services-tasks:18.2.0"
fetch "com.google.android.gms:play-services-base:18.5.0"
fetch "com.google.android.gms:play-services-basement:18.4.0"

# Platform android.jar (highest installed platform).
ANDROID_JAR="$(ls -d "$SDK"/platforms/android-*/android.jar | sort -V | tail -1)"
echo "Using platform: $ANDROID_JAR"
cp "$ANDROID_JAR" "$CP_DIR/android.jar"

echo "Running jnigen…"
cd "$PKG_DIR"
dart run jnigen --config jnigen.yaml \
  $(for j in "$CP_DIR"/*.jar; do printf -- '--class-path %q ' "$j"; done)

# ffigen/jnigen sometimes emit analyzer-rejected annotations; format to settle.
dart format lib/src/playgames_bindings.dart >/dev/null
echo "Done → lib/src/playgames_bindings.dart"
echo "Now add the package to the root pubspec 'workspace:' list and run melos analyze."
