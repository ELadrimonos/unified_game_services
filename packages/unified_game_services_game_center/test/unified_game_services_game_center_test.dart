import 'package:test/test.dart';
import 'package:unified_game_services_game_center/unified_game_services_game_center.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

void main() {
  // These tests don't touch GameKit (no FFI / dlopen), so they run on any
  // platform. Live auth/achievement/leaderboard calls require a signed
  // macOS/iOS app bundle and are not exercised here.
  group('GameCenterProvider capabilities', () {
    final provider = GameCenterProvider();

    test('advertises achievements and leaderboards', () {
      expect(provider.supports(GameCapability.achievements), isTrue);
      expect(provider.supports(GameCapability.leaderboards), isTrue);
    });

    test('does not advertise stats, cloud save or presence', () {
      expect(provider.supports(GameCapability.stats), isFalse);
      expect(provider.supports(GameCapability.cloudSave), isFalse);
      expect(provider.supports(GameCapability.presence), isFalse);
    });
  });

  group('GameCenterProvider id resolution', () {
    test('maps unified ids to native ids, passing unknown keys through', () {
      final provider = GameCenterProvider(
        leaderboardIds: {'global': 'native.board'},
        achievementIds: {'first_win': 'native.win'},
      );
      expect(provider.resolveLeaderboardId('global'), 'native.board');
      expect(provider.resolveLeaderboardId('other'), 'other');
      expect(provider.resolveAchievementId('first_win'), 'native.win');
    });
  });
}
