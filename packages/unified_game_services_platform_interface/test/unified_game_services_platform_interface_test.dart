import 'package:test/test.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

void main() {
  group('Achievement', () {
    test('progressPercentage reports 1.0 when unlocked', () {
      const a = Achievement(id: 'a', title: 'A', isUnlocked: true);
      expect(a.progressPercentage, 1.0);
    });

    test('progressPercentage tracks incremental steps', () {
      const a = Achievement(
        id: 'a',
        title: 'A',
        currentSteps: 3,
        totalSteps: 4,
      );
      expect(a.isIncremental, isTrue);
      expect(a.progressPercentage, 0.75);
    });
  });

  group('dart_mappable serialization', () {
    test('PlayerProfile round-trips through a map', () {
      const profile = PlayerProfile(
        id: 'p1',
        displayName: 'Ada',
        isOnline: true,
      );
      final copy = PlayerProfileMapper.fromMap(profile.toMap());
      expect(copy, profile);
    });

    test('Leaderboard round-trips with nested entries', () {
      final board = Leaderboard(
        id: 'global',
        entries: const [
          LeaderboardEntry(
            rank: 1,
            player: PlayerProfile(id: 'p1', displayName: 'Ada'),
            score: 1500,
          ),
        ],
      );
      final copy = LeaderboardMapper.fromJson(board.toJson());
      expect(copy.entries.single.player.displayName, 'Ada');
      expect(copy.entries.single.score, 1500);
    });

    test('GameServiceEvent decodes via its discriminator', () {
      final event = AchievementUnlockedEvent(
        achievement: const Achievement(id: 'a', title: 'A', isUnlocked: true),
        timestamp: DateTime.utc(2026),
      );
      final decoded = GameServiceEventMapper.fromJson(event.toJson());
      expect(decoded, isA<AchievementUnlockedEvent>());
    });
  });

  group('UnifiedGameServicesPlatform', () {
    test('default provider supports nothing and throws on use', () {
      final platform = UnifiedGameServicesPlatform.instance;
      expect(platform.supports(GameCapability.achievements), isFalse);
      expect(platform.signIn, throwsUnimplementedError);
    });
  });
}
