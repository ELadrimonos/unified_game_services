# gpg_android_example

Flutter host app for `unified_game_services_google_play_android` (the native
Google Play Games provider, Play Games v2 Java SDK over `package:jni`).

> The provider package is **pure Dart** — it has no Flutter dependency. This
> example is a separate Flutter app that *consumes* it, so Flutter lives only in
> this directory's `pubspec.yaml`, never in the package. The app exists because
> the native provider needs an on-device Android host: a live ART VM with
> `package:jni` bound to it (Flutter provides this) and the current `Activity`
> jobject (obtained via `Jni.getCurrentActivity()`).

## What it shows

The write path — the calls that fire the **native Play Games toasts/overlay**:

- `signIn()` (triggers the native sign-in UI)
- `unlockAchievement` / `incrementAchievement` / `revealAchievement`
- `submitScore`

Reads (sign-in state, current player, listing achievements/scores) are **not
wired yet** — see the provider docs: jnigen 0.16.0 mis-generates `Task<T>`, so
the read path awaits a generics fix. For reads today use the REST provider
(`unified_game_services_google_play_rest`).

## Run on a real device / emulator with Play Services

Android only — the Play Games SDK loads only on Android.

1. Create a game in the **Play Console** and add achievements + a leaderboard.
2. Set your numeric Play Games app id in
   `android/app/src/main/res/values/strings.xml`
   (`game_services_project_id`). It is wired into the manifest as
   `com.google.android.gms.games.APP_ID`.
3. Replace the placeholder ids in `lib/main.dart` (`_achievementId`,
   `_leaderboardId`) with ids from your game.
4. Sign the build with the SHA-1 you registered in the Play Console credential
   (debug keystore is fine for testing), and add your test account as a tester.
5. `flutter run`

The Play Games v2 aar is pulled in by `android/app/build.gradle.kts`
(`com.google.android.gms:play-services-games-v2`).

Without a configured Play Console game the UI still launches and the provider
initializes; the write calls just fail at the SDK layer (logged in-app).
