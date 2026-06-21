import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Demonstrates the unified models and capability gating.
///
/// Apps and federated providers depend on this package only for the shared
/// API; concrete providers (Google Play, Game Center, Steam, Epic, Xbox PC,
/// GameJolt) implement [UnifiedGameServicesPlatform].
void main() {
  final platform = UnifiedGameServicesPlatform.instance;

  if (platform.supports(GameCapability.achievements)) {
    platform.unlockAchievement('first_win');
  }

  // Models are dart_mappable-backed: free JSON, copyWith, equality, toString.
  const profile = PlayerProfile(id: 'p1', displayName: 'Ada');
  final json = profile.toJson();
  final restored = PlayerProfileMapper.fromJson(json);
  print('restored == profile: ${restored == profile}');
}
