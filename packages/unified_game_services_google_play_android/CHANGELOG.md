# Changelog

## 0.1.0

Initial release (not yet published to pub.dev).

- Native Google Play Games provider via the Play Games v2 Java SDK over
  `package:jni` (pure Dart, no Flutter). Android only.
- Writes (`unlock`/`increment`/`reveal`/`submitScore`) go through the
  on-device client and fire the native toasts/overlay; runtime-verified on a
  Flutter Android host.
- Reads are pending a jnigen `Task<T>` fix and throw
  `CapabilityNotSupportedException` pointing at the REST provider.
