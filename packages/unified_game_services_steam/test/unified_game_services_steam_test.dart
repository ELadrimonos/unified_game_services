import 'package:test/test.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';
import 'package:unified_game_services_steam/unified_game_services_steam.dart';

// NOTE: Operations are not exercised here — they require the Steam client,
// the Steamworks native library, and a logged-in user, none of which exist in
// CI. These tests cover only what is verifiable without the native runtime.
void main() {
  group('SteamProvider', () {
    test('declares the capabilities it implements', () {
      final provider = SteamProvider(appId: 480);
      expect(provider.capabilities, {
        GameCapability.achievements,
        GameCapability.leaderboards,
        GameCapability.stats,
        GameCapability.cloudSave,
        GameCapability.friends,
        GameCapability.presence,
      });
      expect(provider.supports(GameCapability.multiplayer), isFalse);
    });

    test('registerWith installs itself as the active platform', () {
      SteamProvider.registerWith(appId: 480);
      expect(UnifiedGameServicesPlatform.instance, isA<SteamProvider>());
    });

    test('is not signed in before init', () async {
      final provider = SteamProvider(appId: 480);
      expect(await provider.isSignedIn(), isFalse);
      expect(await provider.getCurrentPlayer(), isNull);
    });

    test('signOut is unsupported on Steam', () {
      final provider = SteamProvider(appId: 480);
      expect(provider.signOut, throwsA(isA<PlatformOperationException>()));
    });
  });
}
