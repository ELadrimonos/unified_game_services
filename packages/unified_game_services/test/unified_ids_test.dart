import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:test/test.dart';
import 'package:unified_game_services/unified_game_services.dart';

/// A provider that reports **native** ids, like Steam / GameJolt do, and keeps
/// its achievements' unlocked state so unlocks are observable.
class NativeIdProvider extends UnifiedGameServicesPlatform
    with MockPlatformInterfaceMixin {
  NativeIdProvider(this.name, Map<String, bool> achievements)
    : _unlocked = {...achievements};

  final String name;
  final Map<String, bool> _unlocked; // native id -> unlocked
  final List<String> unlocked = []; // native ids unlocked via the facade
  bool failRead = false;

  @override
  String get providerId => name;

  @override
  Set<GameCapability> get capabilities => {
    GameCapability.achievements,
    GameCapability.leaderboards,
    GameCapability.stats,
  };

  @override
  Future<List<Achievement>> getAchievements() async {
    if (failRead) throw PlatformOperationException('$name read failed');
    return [
      for (final e in _unlocked.entries)
        Achievement(id: e.key, title: e.key, isUnlocked: e.value),
    ];
  }

  @override
  Future<void> unlockAchievement(String id) async {
    final nativeId = resolveAchievementId(id);
    _unlocked[nativeId] = true;
    unlocked.add(nativeId);
  }

  @override
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) async => Leaderboard(id: resolveLeaderboardId(leaderboardId));

  @override
  Future<Stat?> getStat(String key) async =>
      Stat(key: resolveStatId(key), value: 3);
}

void main() {
  late NativeIdProvider steam;
  late NativeIdProvider jolt;
  late UnifiedGameServices services;

  final achievements = UnifiedAchievementTable({
    'first_win': ProviderIdMap(steam: 'ACH_WIN', gameJolt: '111'),
  });

  setUp(() {
    steam = NativeIdProvider('steam', {
      'ACH_WIN': true,
      'ACH_ONLY_STEAM': false,
    });
    jolt = NativeIdProvider('gamejolt', {'111': false});
    services = UnifiedGameServices(
      providers: [steam, jolt],
      achievements: achievements,
      leaderboards: UnifiedLeaderboardTable({
        'global': ProviderIdMap(steam: 'Quickest Win', gameJolt: '654321'),
      }),
      stats: UnifiedStatTable({'kills': ProviderIdMap(steam: 'stat_kills')}),
    );
  });

  group('id translation on reads', () {
    test(
      'achievement id is the unified key, nativeId the provider id',
      () async {
        final a = (await services.getAchievements(
          from: steam,
        )).firstWhere((a) => a.nativeId == 'ACH_WIN');
        expect(a.id, 'first_win');
        expect(a.providerId, 'steam');
      },
    );

    test('same achievement from two providers shares one id', () async {
      final fromSteam = (await services.getAchievements(from: steam)).first;
      final fromJolt = (await services.getAchievements(from: jolt)).single;
      expect(fromSteam.id, fromJolt.id);
      expect(fromSteam.nativeId, isNot(fromJolt.nativeId));
    });

    test('nativeIds lists every provider and is read-only', () async {
      final a = (await services.getAchievements(from: steam)).first;
      expect(a.nativeIds, {'steam': 'ACH_WIN', 'gamejolt': '111'});
      expect(() => a.nativeIds['epic'] = 'x', throwsUnsupportedError);
    });

    test('unmapped achievements only know their own native id', () async {
      final a = (await services.getAchievements(
        from: steam,
      )).firstWhere((a) => a.id == 'ACH_ONLY_STEAM');
      expect(a.nativeIds, {'steam': 'ACH_ONLY_STEAM'});
    });

    test('unmapped achievements keep their native id', () async {
      final a = (await services.getAchievements(
        from: steam,
      )).firstWhere((a) => a.nativeId == 'ACH_ONLY_STEAM');
      expect(a.id, 'ACH_ONLY_STEAM');
    });

    test('leaderboard: unified id requested, nativeId resolved', () async {
      final b = await services.getLeaderboard('global', from: jolt);
      expect(b.id, 'global');
      expect(b.nativeId, '654321');
      expect(b.nativeIds, {'steam': 'Quickest Win', 'gamejolt': '654321'});
    });

    test('stat: unified key requested, nativeKey resolved', () async {
      final s = await services.getStat('kills');
      expect(s!.key, 'kills');
      expect(s.nativeKey, 'stat_kills');
      expect(s.nativeKeys, {'steam': 'stat_kills'});
    });
  });

  group('getAchievementOverview', () {
    test('merges providers by unified id without duplicates', () async {
      final overview = await services.getAchievementOverview();
      expect(overview.achievements.map((a) => a.id), [
        'first_win',
        'ACH_ONLY_STEAM',
      ]);
      final win = overview['first_win']!;
      expect(win.providers, {'steam', 'gamejolt'});
      expect(win.unlockedOn, {'steam'});
      expect(win.lockedOn, {'gamejolt'});
      expect(win.isUnlockedOn('steam'), isTrue);
      expect(win.isUnlockedOn('gamejolt'), isFalse);
      expect(win.isUnlockedOn('epic'), isNull);
      expect(win.isUnlockedAnywhere, isTrue);
      expect(win.isUnlockedEverywhere, isFalse);
    });

    test('a failing provider is reported, not thrown', () async {
      jolt.failRead = true;
      final overview = await services.getAchievementOverview();
      expect(overview.failed.single.providerId, 'gamejolt');
      expect(overview['first_win']!.providers, {'steam'});
    });
  });

  group('syncAchievements', () {
    test('unlocks on providers where it is locked, by native id', () async {
      final result = await services.syncAchievements();
      expect(result.failed, isEmpty);
      expect(jolt.unlocked, ['111']);
      expect(steam.unlocked, isEmpty);
      final win = (await services.getAchievementOverview())['first_win']!;
      expect(win.isUnlockedEverywhere, isTrue);
    });

    test('does not touch achievements locked everywhere', () async {
      await services.syncAchievements();
      expect(steam.unlocked, isNot(contains('ACH_ONLY_STEAM')));
    });

    test('is a no-op when already in sync', () async {
      await services.syncAchievements();
      jolt.unlocked.clear();
      final result = await services.syncAchievements();
      expect(result.results, isEmpty);
      expect(jolt.unlocked, isEmpty);
    });
  });
}
