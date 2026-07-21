# Changelog

## 0.1.0

Initial release.

- Flutter adapter for the Google Play Games family: one call
  (`GooglePlayGamesFlutter.registerWith` / `.create`) auto-resolves the
  Android `Activity` from the running Flutter engine via `jni_flutter`.
- Off Android — including Flutter web — it delegates to the REST tier;
  builds for web verified with `flutter build web`.
