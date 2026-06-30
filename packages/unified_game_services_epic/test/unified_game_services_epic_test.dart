import 'package:test/test.dart';
import 'package:unified_game_services_epic/unified_game_services_epic.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

// EOS operations are not exercised here: they need the EOS runtime shared
// library, a configured product/deployment, and a live backend — none exist in
// CI. These cover only what is verifiable without the native runtime.
const _credentials = EpicCredentials(
  productId: 'prod',
  sandboxId: 'sandbox',
  deploymentId: 'deploy',
  clientId: 'client',
  clientSecret: 'secret',
);

void main() {
  group('EpicProvider', () {
    test('declares the capabilities it implements', () {
      final provider = EpicProvider(credentials: _credentials);
      expect(provider.capabilities, {
        GameCapability.achievements,
        GameCapability.leaderboards,
        GameCapability.stats,
      });
      expect(provider.supports(GameCapability.cloudSave), isFalse);
      expect(provider.supports(GameCapability.friends), isFalse);
    });

    test('registerWith installs itself as the active platform', () {
      EpicProvider.registerWith(credentials: _credentials);
      expect(UnifiedGameServicesPlatform.instance, isA<EpicProvider>());
      expect(
        UnifiedGameServicesPlatform.getInstance<EpicProvider>().credentials,
        same(_credentials),
      );
    });

    test('is not signed in before signIn', () async {
      final provider = EpicProvider(credentials: _credentials);
      expect(await provider.isSignedIn(), isFalse);
      expect(await provider.getCurrentPlayer(), isNull);
    });

    test('reveal/increment achievement throw without the native runtime', () {
      final provider = EpicProvider(credentials: _credentials);
      expect(
        () => provider.revealAchievement('a'),
        throwsA(isA<PlatformOperationException>()),
      );
      expect(
        () => provider.incrementAchievement('a', 1),
        throwsA(isA<PlatformOperationException>()),
      );
    });
  });
}
