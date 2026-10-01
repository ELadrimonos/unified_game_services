import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Demonstrates the unified models and capability gating.
///
/// Apps and federated providers depend on this package only for the shared
/// API; concrete providers (Google Play, Game Center, Steam, Epic, Xbox PC,
/// GameJolt) implement [UnifiedGameServicesPlatform].
void main() {
  final platform = _ExampleProvider();

  if (platform.supports(GameCapability.achievements)) {
    platform.unlockAchievement('first_win');
  }

  // Models are immutable value objects: copyWith, ==, hashCode, toString.
  const profile = PlayerProfile(id: 'p1', displayName: 'Ada');
  final tagged = profile.copyWith(providerId: 'steam');
  print('same player: ${tagged.id == profile.id}, equal: ${tagged == profile}');
}

class _ExampleProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'example';

  @override
  Set<GameCapability> get capabilities => const {GameCapability.achievements};

  @override
  Future<void> unlockAchievement(String achievementId) async {}
}
