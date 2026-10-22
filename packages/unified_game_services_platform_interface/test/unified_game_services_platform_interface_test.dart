import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:test/test.dart';
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

class _FakeProviderA extends UnifiedGameServicesPlatform
    with MockPlatformInterfaceMixin {
  @override
  String get providerId => 'fake_a';
}

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

  group('value semantics', () {
    test('PlayerProfile == / hashCode compare fields, incl. extra deeply', () {
      const a = PlayerProfile(id: 'p1', displayName: 'Ada', extra: {'k': 1});
      const b = PlayerProfile(id: 'p1', displayName: 'Ada', extra: {'k': 1});
      const c = PlayerProfile(id: 'p1', displayName: 'Ada', extra: {'k': 2});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('PlayerProfile.copyWith replaces only the given fields', () {
      const p = PlayerProfile(id: 'p1', displayName: 'Ada', isOnline: true);
      final q = p.copyWith(providerId: 'steam', displayName: 'Grace');
      expect(q.id, 'p1');
      expect(q.displayName, 'Grace');
      expect(q.isOnline, isTrue);
      expect(q.providerId, 'steam');
      expect(p.providerId, isNull);
    });

    test('copyWith cannot reset a field to null (documented)', () {
      const p = PlayerProfile(id: 'p1', displayName: 'Ada', avatarUrl: 'u');
      expect(p.copyWith(avatarUrl: null).avatarUrl, 'u');
    });

    test('Leaderboard compares entries deeply', () {
      Leaderboard board(int score) => Leaderboard(
        id: 'global',
        entries: [
          LeaderboardEntry(
            rank: 1,
            player: const PlayerProfile(id: 'p1', displayName: 'Ada'),
            score: score,
          ),
        ],
      );
      expect(board(10), board(10));
      expect(board(10).hashCode, board(10).hashCode);
      expect(board(10), isNot(board(11)));
      expect(board(10).entries.single.displayScore, '10');
    });

    test('CloudSave compares payload bytes and exposes bytes/slot', () {
      const meta = CloudSaveMetadata(slot: 's1');
      final a = CloudSave.fromBytes(
        metadata: meta,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      const b = CloudSave(metadata: meta, data: [1, 2, 3]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(b.copyWith(data: [1, 2, 4])));
      expect(a.slot, 's1');
      expect(a.bytes, isA<Uint8List>());
      expect(a.bytes, [1, 2, 3]);
      expect(a.toString(), contains('3 bytes'));
    });

    test('Stat, RichPresence and Achievement support == and copyWith', () {
      expect(const Stat(key: 'k', value: 1), const Stat(key: 'k', value: 1));
      expect(const Stat(key: 'k', value: 1).copyWith(value: 2).value, 2);
      expect(
        const RichPresence(state: 'x', partySize: 2),
        const RichPresence(state: 'x', partySize: 2),
      );
      expect(
        const Achievement(id: 'a', title: 'A').copyWith(isUnlocked: true),
        const Achievement(id: 'a', title: 'A', isUnlocked: true),
      );
    });

    test('toString includes the type and field values', () {
      expect(
        const Stat(key: 'kills', value: 3).toString(),
        allOf(contains('Stat'), contains('kills'), contains('3')),
      );
    });

    test('events compare by value and switch exhaustively', () {
      final t = DateTime.utc(2026);
      final a = AchievementUnlockedEvent(
        achievement: const Achievement(id: 'a', title: 'A', isUnlocked: true),
        timestamp: t,
      );
      final b = AchievementUnlockedEvent(
        achievement: const Achievement(id: 'a', title: 'A', isUnlocked: true),
        timestamp: t,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        UserSignedOutEvent(timestamp: t),
        UserSignedOutEvent(timestamp: t),
      );
      expect(PresenceChangedEvent(timestamp: t).presence, isNull);

      String kind(GameServiceEvent e) => switch (e) {
        UserSignedInEvent() => 'in',
        UserSignedOutEvent() => 'out',
        AchievementUnlockedEvent() => 'ach',
        ScoreSubmittedEvent() => 'score',
        StatUpdatedEvent() => 'stat',
        PresenceChangedEvent() => 'presence',
        InvitationReceivedEvent() => 'invite',
      };
      expect(kind(a), 'ach');
    });
  });

  group('UnifiedGameServicesPlatform', () {
    test('a provider supports only what it advertises', () {
      final platform = _FakeProviderA();
      expect(platform.supports(GameCapability.achievements), isFalse);
      expect(platform.signIn, throwsUnimplementedError);
    });
  });

  group('providerId', () {
    test('is exposed by implementations', () {
      expect(_FakeProviderA().providerId, 'fake_a');
    });
  });

  group('UnifiedIdTable', () {
    final table = UnifiedAchievementTable({
      'first_win': ProviderIdMap(googlePlay: 'CgkShared'),
      'boss': ProviderIdMap(
        googlePlay: 'CgkShared2',
        googlePlayRest: 'CgkRest',
      ),
    });

    test('googlePlay entries apply to both Google Play tiers', () {
      for (final id in [
        ProviderId.googlePlayRest,
        ProviderId.googlePlayAndroid,
      ]) {
        expect(table.forProvider(id)['first_win'], 'CgkShared');
        expect(table.reverseForProvider(id)['CgkShared'], 'first_win');
      }
    });

    test('a tier-specific entry overrides googlePlay', () {
      expect(table.forProvider(ProviderId.googlePlayRest)['boss'], 'CgkRest');
      expect(
        table.forProvider(ProviderId.googlePlayAndroid)['boss'],
        'CgkShared2',
      );
    });

    test('googlePlay entries do not leak to other providers', () {
      expect(table.forProvider(ProviderId.steam), isEmpty);
    });
  });
}
