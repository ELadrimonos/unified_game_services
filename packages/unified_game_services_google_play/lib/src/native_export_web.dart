/// Empty web stand-in for `native_export_io.dart`. The native Android provider
/// (`GooglePlayAndroidProvider`) depends on `package:jni` (FFI, no web), so it
/// is not re-exported on web — web consumers use the REST provider.
library;
