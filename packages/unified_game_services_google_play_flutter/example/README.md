# gpg_flutter_example

Plug-and-play demo of `unified_game_services_google_play_flutter`.

`main()` calls `GooglePlayGamesFlutter.registerWith(...)` once — on Android it wires the
native Play Games provider and **auto-resolves the host Activity** from the
Flutter engine (no `jni_flutter` / `PlatformDispatcher` in app code). The UI
then drives the registered instance through the `UnifiedGameServices` facade
(sign in, unlock/increment achievement, submit score).

## Run on a real device / emulator with Play Services

Android only — the Play Games SDK loads only on Android.

1. Create a game in the **Play Console** with achievements + a leaderboard.
2. Set your numeric Play Games app id in
   `android/app/src/main/res/values/strings.xml` (`game_services_project_id`).
3. Replace the placeholder ids in `lib/main.dart` (`firstWin`, `highScores`)
   with ids from your game.
4. Sign with the SHA-1 registered in the Play Console credential (debug
   keystore is fine for testing) and add your account as a tester.
5. `flutter run`

The Play Games v2 aar is pulled in by `android/app/build.gradle.kts`
(`com.google.android.gms:play-services-games-v2`).

Reads (sign-in result, current player, listing) are not wired yet — see the
native provider docs (`Task<T>` binding pending). Writes fire the native
toasts/overlay.
