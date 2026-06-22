# unified_game_services_google_play_android

Native Google Play Games provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services),
backed by the **Play Games v2 Java SDK** reached over `package:jni` — pure Dart,
no Flutter. **Android only.**

Most apps should use [`unified_game_services_google_play`](../unified_game_services_google_play)
(auto-selects this on Android, REST elsewhere) rather than depending on this
package directly.

## Why this exists

The REST provider ([`unified_game_services_google_play_rest`](../unified_game_services_google_play_rest))
talks to Google's cloud and so cannot fire the **native Play Services
achievement/leaderboard toasts** on Android. This provider routes writes through
the on-device Play Games client, so unlocks and score submissions show the
native overlay. Authentication is handled by Play Services — there is no OAuth
token to manage.

`package:jni`/`jnigen` reach the Java SDK via JNI (the same approach
`objective_c` uses for GameKit), so this stays within the repo's no-Flutter
constraint. `games_services` is banned because it uses Flutter platform
channels — JNI does not.

## Host requirements

This package is pure Dart, but the SDK needs the host (the engine/app embedding
Dart on Android) to supply the Android runtime — the same "host supplies the
runtime" shape as Steam (needs the Steam client) and Game Center (needs a signed
bundle + run loop):

1. A running ART VM with `package:jni` initialized against it (host hands the
   `JavaVM*`/`JNIEnv` to JNI on startup).
2. The current `Activity` jobject, passed to `registerWith` / the constructor
   (e.g. from `ANativeActivity.clazz`).
3. The APK bundles `com.google.android.gms:play-services-games-v2` and declares
   the Play Games app id `<meta-data>` in its manifest.

## Status

- **Implemented:** the native-UX writes — `unlockAchievement`,
  `incrementAchievement`, `revealAchievement`, `submitScore`, and the
  provider-specific `setAchievementStepsAtLeast`. `signIn()` triggers the native
  sign-in flow.
- **Pending:** operations that read a `Task<T>` result (confirming sign-in
  state, current player, listing achievements / leaderboard scores). jnigen
  0.16.0 mis-generates `com.google.android.gms.tasks.Task`/`Tasks`, so those are
  excluded from the bindings and `Task`-returning methods come back as opaque
  `JObject`. Wiring reads needs a jnigen that fixes generics (or a small
  hand-written JNI `Tasks.await` helper). Meanwhile the unified facade can serve
  reads from the REST provider.
- **Not runtime-verified on device** yet — the Play Games SDK loads only on
  Android with a Play Console game + tester account.

## Bindings

`lib/src/playgames_bindings.dart` is generated and committed. Regenerate with:

```sh
ANDROID_SDK_ROOT=/path/to/sdk tool/regenerate_bindings.sh [PLAY_GAMES_VERSION]
```

Needs the Android SDK (for `android.jar`), a JDK ≤ 21 (the ASM summarizer), and
network access to Google's Maven. The script resolves the Play Games aar +
transitive deps, extracts each `classes.jar`, and runs jnigen against that
classpath. Keep the runtime `jni` dependency aligned with the jnigen version
(jnigen 0.16.0 → jni 1.0.0).

## License

MIT — see [LICENSE](LICENSE). Independent, unofficial; not affiliated with any
platform vendor. See the repository `NOTICE.md`.
