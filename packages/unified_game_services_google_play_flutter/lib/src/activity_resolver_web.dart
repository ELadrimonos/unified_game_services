/// Web half of the Flutter adapter — the **default** import, replaced by
/// `activity_resolver_io.dart` where `dart.library.io` exists.
///
/// Web is never Android, so the adapter always takes the REST path and never
/// resolves an Activity. This stub exists only so the conditional import
/// resolves; it is unreachable at runtime (the facade's `usesNative` is `false`
/// on web).
Object Function() flutterActivityResolver() {
  throw UnsupportedError(
    'The native Play Games provider is Android-only; web uses the REST '
    'provider (pass an AuthStrategy via `auth`).',
  );
}
