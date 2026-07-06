/// Builds the dart:ffi providers (Steam, Epic) — but only where they can run.
///
/// The web variant is a stub that constructs nothing (and never imports the
/// ffi packages), so `flutter build web` never pulls `dart:ffi` into the
/// bundle. The io variant constructs Steam/Epic on desktop and reports a skip
/// reason on Android/iOS. This conditional export is the mechanism behind the
/// example's "respect the environment" promise.
library;

export 'native_providers_web.dart'
    if (dart.library.io) 'native_providers_io.dart';
