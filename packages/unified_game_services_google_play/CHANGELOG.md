# Changelog

## 0.1.0

Initial release (not yet published to pub.dev).

- Auto-selecting Google Play Games factory: native Play Games v2 SDK on
  Android, REST elsewhere — including web (`package:jni` stays behind a
  `dart.library.io` conditional import so the facade compiles to JS).
- `activityResolver` typed `Object Function()` so the public API carries no
  `jni` types; resolved fresh before each native call.
