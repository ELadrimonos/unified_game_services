import 'package:steamworks/steamworks.dart' as sw;
import 'package:test/test.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';
import 'package:unified_game_services_steam/src/unified_game_services_steam_base.dart'
    show mapSteamInitError;
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

  group('mapSteamInitError', () {
    test('restart-needed becomes SteamRestartRequiredException', () {
      final error = sw.SteamRestartAppIfNecessaryError();
      final mapped = mapSteamInitError(error);
      expect(mapped, isA<SteamRestartRequiredException>());
      expect(mapped, isA<SignInFailedException>());
      expect(mapped.cause, same(error));
    });

    test('init error keeps the native message', () {
      final mapped = mapSteamInitError(
        sw.SteamInitializationError(message: 'Steam is not running'),
      );
      expect(mapped, isA<SignInFailedException>());
      expect(mapped, isNot(isA<SteamRestartRequiredException>()));
      expect(mapped.message, contains('Steam is not running'));
    });

    test('unknown errors fall back to a generic sign-in failure', () {
      final mapped = mapSteamInitError(StateError('boom'));
      expect(mapped, isA<SignInFailedException>());
      expect(mapped.message, 'Failed to initialize Steam.');
    });
  });
}
