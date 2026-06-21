part of 'platform_interface.dart';

/// The default [UnifiedGameServicesPlatform] used when no provider has been
/// registered.
///
/// It supports no [capabilities] and inherits the base class's
/// [UnimplementedError]-throwing defaults for every operation.
class UnsupportedUnifiedGameServices extends UnifiedGameServicesPlatform {}
