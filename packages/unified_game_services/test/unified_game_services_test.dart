import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:test/test.dart';
import 'package:unified_game_services/unified_game_services.dart';

/// Records which operations were invoked, and can be told which capabilities it
/// supports and whether to fail.
class FakeProvider extends UnifiedGameServicesPlatform
    with MockPlatformInterfaceMixin {
  FakeProvider({
    required this.name,
    Set<GameCapability> caps = const {},
    this.failOn = const {},
  }) : capabilities = caps;

  final String name;
  final Set<String> failOn;

  @override
  String get providerId => name;

  final List<String> calls = [];
  final controller = StreamController<GameServiceEvent>.broadcast();

  @override
  final Set<GameCapability> capabilities;

  @override
  Stream<GameServiceEvent> get events => controller.stream;

  Future<void> _record(String op) async {
    calls.add(op);
    if (failOn.contains(op)) throw PlatformOperationException('$name:$op');
  }

  @override
  Future<PlayerProfile?> signIn() async {
    await _record('signIn');
    return PlayerProfile(id: name, displayName: name);
  }

  @override
  Future<PlayerProfile?> getCurrentPlayer() async =>
      PlayerProfile(id: name, displayName: name);

  @override
  Future<void> unlockAchievement(String id) => _record('unlock:$id');

  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) => _record('score:$leaderboardId:$score');

  @override
  Future<bool> isSignedIn() async => true;

  @override
  Future<void> revealAchievement(String id) => _record('reveal:$id');

  @override
  Future<void> deleteSave(String slot) => _record('delete:$slot');

  @override
  Future<List<Achievement>> getAchievements() async {
    calls.add('getAchievements');
    return [Achievement(id: '$name-a', title: name)];
  }

  @override
  Future<LeaderboardEntry?> getPlayerScore(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
  }) async {
    await _record('getPlayerScore:$leaderboardId');
    return name == 'none'
        ? null
        : LeaderboardEntry(
            rank: 1,
            player: PlayerProfile(id: name, displayName: name),
            score: 10,
          );
  }

  @override
  Future<List<PlayerProfile>> getFriends() async {
    await _record('getFriends');
    return [PlayerProfile(id: '$name-f', displayName: 'f')];
  }

  @override
  Future<List<CloudSaveMetadata>> listSaves() async {
    await _record('listSaves');
    return [CloudSaveMetadata(slot: '$name-slot')];
  }

  @override
  Future<CloudSave?> loadData(String slot) async {
    await _record('loadData:$slot');
    return name == 'none'
        ? null
        : CloudSave(
            metadata: CloudSaveMetadata(slot: slot),
            data: [1],
          );
  }

  @override
  Future<List<Stat>> getStats() async {
    await _record('getStats');
    return [Stat(key: '$name-kills', value: 3)];
  }

  @override
  Future<Stat?> getStat(String key) async {
    await _record('getStat:$key');
    return name == 'none' ? null : Stat(key: key, value: 7);
  }

  @override
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) async {
    await _record('getLeaderboard:$leaderboardId');
    return Leaderboard(id: leaderboardId);
  }
}

void main() {
  group('UnifiedGameServices', () {
    group('global instance', () {
      setUp(GameServices.reset);
      tearDown(GameServices.reset);

      test('instance throws StateError before initialize', () {
        expect(GameServices.maybeInstance, isNull);
        expect(() => GameServices.instance, throwsStateError);
      });

      test('initialize sets and returns the global instance', () {
        final fake = FakeProvider(name: 'reg');
        final services = GameServices.initialize(providers: [fake]);
        expect(GameServices.instance, same(services));
        expect(GameServices.maybeInstance, same(services));
        expect(services.providers, [fake]);
        expect(services.primary, fake);
      });

      test('initialize replaces the previous global instance', () {
        final first = GameServices.initialize(
          providers: [FakeProvider(name: 'a')],
        );
        final second = GameServices.initialize(
          providers: [FakeProvider(name: 'b')],
        );
        expect(GameServices.instance, same(second));
        expect(GameServices.instance, isNot(same(first)));
      });

      test('reset clears the global instance', () {
        GameServices.initialize(providers: [FakeProvider(name: 'a')]);
        GameServices.reset();
        expect(GameServices.maybeInstance, isNull);
      });

      test('provider<T>() is reachable through instance', () {
        final fake = FakeProvider(name: 'a');
        GameServices.initialize(providers: [fake]);
        expect(GameServices.provider<FakeProvider>(), same(fake));
      });

      test('does not touch the standalone constructor', () {
        UnifiedGameServices(providers: [FakeProvider(name: 'x')]);
        expect(GameServices.maybeInstance, isNull);
      });
    });

    test('empty providers throw ArgumentError', () {
      expect(() => UnifiedGameServices(providers: []), throwsArgumentError);
      expect(() => GameServices.initialize(providers: []), throwsArgumentError);
      expect(GameServices.maybeInstance, isNull);
    });

    test('supports is any-provider; supportsEverywhere is all', () {
      final services = UnifiedGameServices(
        providers: [
          FakeProvider(name: 'a', caps: {GameCapability.achievements}),
          FakeProvider(name: 'b', caps: {GameCapability.leaderboards}),
        ],
      );
      expect(services.supports(GameCapability.achievements), isTrue);
      expect(services.supportsEverywhere(GameCapability.achievements), isFalse);
    });

    test('write fans out only to capable providers', () async {
      final a = FakeProvider(name: 'a', caps: {GameCapability.achievements});
      final b = FakeProvider(name: 'b', caps: {GameCapability.leaderboards});
      final services = UnifiedGameServices(providers: [a, b]);

      await services.unlockAchievement('x');
      expect(a.calls, contains('unlock:x'));
      expect(b.calls, isEmpty);

      await services.submitScore(leaderboardId: 'lb', score: 10);
      expect(b.calls, contains('score:lb:10'));
    });

    test(
      'write throws CapabilityNotSupported when nobody supports it',
      () async {
        final services = UnifiedGameServices(
          providers: [FakeProvider(name: 'a')],
        );
        expect(
          () => services.unlockAchievement('x'),
          throwsA(isA<CapabilityNotSupportedException>()),
        );
      },
    );

    test('partial failure is returned, not thrown', () async {
      final a = FakeProvider(name: 'a', caps: {GameCapability.achievements});
      final b = FakeProvider(
        name: 'b',
        caps: {GameCapability.achievements},
        failOn: {'unlock:x'},
      );
      final c = FakeProvider(name: 'c', caps: {GameCapability.achievements});
      final services = UnifiedGameServices(providers: [a, b, c]);

      final result = await services.unlockAchievement('x');

      expect(result.operation, 'unlockAchievement');
      expect(result.successfulProviders, ['a', 'c']);
      expect(result.failedProviders, ['b']);
      expect(result.succeeded.map((r) => r.providerId), ['a', 'c']);
      expect(result.failed.single.providerId, 'b');
      expect(result.allSucceeded, isFalse);
      expect(result.anySucceeded, isTrue);
      expect(result.allFailed, isFalse);
      // Original provider error is preserved, not discarded.
      final error = result.failed.single.error;
      expect(error, isA<PlatformOperationException>());
      expect(error.message, 'b:unlock:x');
      expect(result['b']!.isFailure, isTrue);
      expect(result['zzz'], isNull);
      // Every provider was attempted.
      expect(a.calls, contains('unlock:x'));
      expect(b.calls, contains('unlock:x'));
      expect(c.calls, contains('unlock:x'));
    });

    test('results are sealed: exhaustive switch, typed accessors', () async {
      final a = FakeProvider(name: 'a', caps: {GameCapability.achievements});
      final b = FakeProvider(
        name: 'b',
        caps: {GameCapability.achievements},
        failOn: {'unlock:x'},
      );
      final result = await UnifiedGameServices(
        providers: [a, b],
      ).unlockAchievement('x');

      final labels = [
        for (final r in result.results)
          switch (r) {
            OperationSuccess(:final providerId) => '$providerId:ok',
            OperationFailure(:final providerId, :final error) =>
              '$providerId:${error.message}',
          },
      ];
      expect(labels, ['a:ok', 'b:b:unlock:x']);
      expect(result['a']!.isSuccess, isTrue);
      expect(result['b']!.errorOrNull, isA<PlatformOperationException>());
      expect(result['a']!.errorOrNull, isNull);
      expect(result.anyFailed, isTrue);
      expect(result.errors, hasLength(1));
      expect(result['a']!.when(success: (_) => 1, failure: (_) => 0), 1);
      expect(result['b']!.when(success: (_) => 1, failure: (_) => 0), 0);
      expect(result['a']!.getOrThrow, returnsNormally);
      expect(result['b']!.getOrThrow, throwsA(isA<GameServiceException>()));
      expect(result.throwIfAnyFailed, throwsA(isA<GameServiceException>()));
    });

    group('reads from all providers', () {
      late FakeProvider a, b, c;
      late UnifiedGameServices services;

      setUp(() {
        const caps = {
          GameCapability.achievements,
          GameCapability.leaderboards,
          GameCapability.stats,
        };
        a = FakeProvider(name: 'a', caps: caps);
        b = FakeProvider(
          name: 'b',
          caps: caps,
          failOn: {'getStats', 'getStat:k', 'getLeaderboard:lb'},
        );
        c = FakeProvider(name: 'none', caps: caps);
        services = UnifiedGameServices(providers: [a, b, c]);
      });

      test(
        'getAchievementsFromAll returns one tagged list per provider',
        () async {
          final r = await services.getAchievementsFromAll();
          expect(r.operation, 'getAchievements');
          expect(r.successfulProviders, ['a', 'b', 'none']);
          expect(r['b']!.valueOrNull!.single.providerId, 'b');
        },
      );

      test(
        'getStatsFromAll reports a failing provider without throwing',
        () async {
          final r = await services.getStatsFromAll();
          expect(r.successfulProviders, ['a', 'none']);
          expect(r.failedProviders, ['b']);
          expect(r['a']!.valueOrNull!.single.providerId, 'a');
          expect(r['a']!.valueOrNull!.single.nativeKeys, {'a': 'a-kills'});
        },
      );

      test(
        'getStatFromAll keeps null for providers without the stat',
        () async {
          final r = await services.getStatFromAll('k');
          expect(r['a']!.valueOrNull!.providerId, 'a');
          expect(r['none']!.isSuccess, isTrue);
          expect(r['none']!.valueOrNull, isNull);
          expect(r['b']!.isFailure, isTrue);
        },
      );

      test(
        'getLeaderboardFromAll tags each leaderboard with its provider',
        () async {
          final r = await services.getLeaderboardFromAll('lb');
          expect(r['a']!.valueOrNull!.providerId, 'a');
          expect(r['none']!.valueOrNull!.providerId, 'none');
          expect(r.failedProviders, ['b']);
        },
      );

      test(
        'getPlayerScoreFromAll tags the player, null when no entry',
        () async {
          final r = await services.getPlayerScoreFromAll('lb');
          expect(r['a']!.valueOrNull!.player.providerId, 'a');
          expect(r['none']!.isSuccess, isTrue);
          expect(r['none']!.valueOrNull, isNull);
          expect(
            (await services.getPlayerScore('lb', from: a))!.player.providerId,
            'a',
          );
        },
      );

      test('getCurrentPlayerFromAll asks every provider', () async {
        final r = await services.getCurrentPlayerFromAll();
        expect(r.successfulProviders, ['a', 'b', 'none']);
        expect(r['b']!.valueOrNull!.providerId, 'b');
      });

      test(
        'getFriendsFromAll and loadDataFromAll are capability-gated',
        () async {
          final x = FakeProvider(
            name: 'x',
            caps: {GameCapability.friends, GameCapability.cloudSave},
          );
          final y = FakeProvider(
            name: 'y',
            caps: {GameCapability.achievements},
          );
          final svc = UnifiedGameServices(providers: [x, y]);
          final friends = await svc.getFriendsFromAll();
          expect(friends.results.map((r) => r.providerId), ['x']);
          expect(friends['x']!.valueOrNull!.single.providerId, 'x');
          final saves = await svc.loadDataFromAll('s1');
          expect(saves['x']!.valueOrNull!.metadata.providerId, 'x');
          expect(y.calls, isEmpty);
          final lists = await svc.listSavesFromAll();
          expect(lists.results.map((r) => r.providerId), ['x']);
          expect(lists['x']!.valueOrNull!.single.providerId, 'x');
          expect((await svc.listSaves(from: x)).single.slot, 'x-slot');
        },
      );

      test('throws CapabilityNotSupported when nobody supports it', () {
        final bare = UnifiedGameServices(providers: [FakeProvider(name: 'x')]);
        expect(
          bare.getStatsFromAll,
          throwsA(isA<CapabilityNotSupportedException>()),
        );
        expect(
          () => bare.getLeaderboardFromAll('lb'),
          throwsA(isA<CapabilityNotSupportedException>()),
        );
      });

      test('static GameServices delegates', () async {
        GameServices.initialize(providers: [a]);
        addTearDown(GameServices.reset);
        expect((await GameServices.getStatsFromAll()).allSucceeded, isTrue);
        expect((await GameServices.getStatFromAll('k')).allSucceeded, isTrue);
        expect(
          (await GameServices.getAchievementsFromAll()).allSucceeded,
          isTrue,
        );
        expect(
          (await GameServices.getLeaderboardFromAll('lb')).allSucceeded,
          isTrue,
        );
        expect((await GameServices.getStats()).single.providerId, 'a');
      });
    });

    test('all providers succeed', () async {
      final ps = [
        for (final n in ['a', 'b', 'c'])
          FakeProvider(name: n, caps: {GameCapability.leaderboards}),
      ];
      final result = await UnifiedGameServices(
        providers: ps,
      ).submitScore(leaderboardId: 'lb', score: 5);

      expect(result.allSucceeded, isTrue);
      expect(result.anySucceeded, isTrue);
      expect(result.allFailed, isFalse);
      expect(result.failed, isEmpty);
      expect(result.results.map((r) => r.providerId), ['a', 'b', 'c']);
      expect(result.results.every((r) => r.isSuccess), isTrue);
    });

    test('all providers fail without throwing', () async {
      final ps = [
        for (final n in ['a', 'b'])
          FakeProvider(
            name: n,
            caps: {GameCapability.leaderboards},
            failOn: {'score:lb:5'},
          ),
      ];
      final result = await UnifiedGameServices(
        providers: ps,
      ).submitScore(leaderboardId: 'lb', score: 5);

      expect(result.allSucceeded, isFalse);
      expect(result.anySucceeded, isFalse);
      expect(result.allFailed, isTrue);
      expect(result.failed.map((r) => r.error.message), [
        'a:score:lb:5',
        'b:score:lb:5',
      ]);
    });

    test(
      'non-GameServiceException errors are wrapped with their cause',
      () async {
        // Base-class default throws UnimplementedError for signOut.
        final a = FakeProvider(name: 'a');
        final result = await UnifiedGameServices(providers: [a]).signOut();

        final error = result.failed.single.error;
        expect(error, isA<PlatformOperationException>());
        expect(error.cause, isA<UnimplementedError>());
        expect(result.failed.single.stackTrace, isNotNull);
      },
    );

    test('facade covers the remaining reads and writes', () async {
      final a = FakeProvider(
        name: 'a',
        caps: {
          GameCapability.achievements,
          GameCapability.leaderboards,
          GameCapability.stats,
          GameCapability.cloudSave,
        },
      );
      final services = UnifiedGameServices(
        providers: [a],
        stats: UnifiedStatTable.fromMap({
          'kills': {'a': 'a-kills'},
        }),
      );

      expect(await services.isSignedIn(), isTrue);
      expect((await services.getPlayerScore('lb'))!.player.providerId, 'a');

      final stat = (await services.getStats()).single;
      expect(stat.key, 'kills');
      expect(stat.nativeKeys['a'], 'a-kills');
      expect(stat.providerId, 'a');

      expect((await services.listSaves()).single.providerId, 'a');

      await services.revealAchievement('x');
      await services.deleteSave('main');
      expect(a.calls, containsAll(['reveal:x', 'delete:main']));
    });

    test('reads from a provider lacking the capability throw', () {
      final services = UnifiedGameServices(
        providers: [FakeProvider(name: 'a')],
      );
      expect(
        services.listSaves(),
        throwsA(isA<CapabilityNotSupportedException>()),
      );
      expect(
        services.getStats(),
        throwsA(isA<CapabilityNotSupportedException>()),
      );
    });

    test('unsupported providers are not invoked', () async {
      final a = FakeProvider(name: 'a', caps: {GameCapability.achievements});
      final b = FakeProvider(name: 'b', caps: {GameCapability.leaderboards});
      final result = await UnifiedGameServices(
        providers: [a, b],
      ).unlockAchievement('x');

      expect(result.results.map((r) => r.providerId), ['a']);
      expect(b.calls, isEmpty);
    });

    test('signIn returns per-provider profiles and failures', () async {
      final a = FakeProvider(name: 'a');
      final b = FakeProvider(name: 'b', failOn: {'signIn'});
      final result = await UnifiedGameServices(providers: [a, b]).signIn();

      expect(result.succeeded.single.value?.id, 'a');
      expect(result.failedProviders, ['b']);
    });

    test('signOut and dispose report per-provider results', () async {
      final services = UnifiedGameServices(
        providers: [
          FakeProvider(name: 'a'),
          FakeProvider(name: 'b'),
        ],
      );
      // Fake leaves signOut unimplemented → failures, but never a throw.
      final out = await services.signOut();
      expect(out.allFailed, isTrue);
      final disposed = await services.dispose();
      expect(disposed.allSucceeded, isTrue);
      expect(disposed.operation, 'dispose');
    });

    group('capability discovery', () {
      test('providersFor returns only providers advertising it', () {
        final a = FakeProvider(
          name: 'a',
          caps: {GameCapability.friends, GameCapability.stats},
        );
        final b = FakeProvider(name: 'b', caps: {GameCapability.stats});
        final c = FakeProvider(name: 'c', caps: {GameCapability.friends});
        final services = UnifiedGameServices(providers: [a, b, c]);

        expect(services.providersFor(GameCapability.friends), [a, c]);
        expect(services.providersFor(GameCapability.stats), [a, b]);
        expect(services.providersFor(GameCapability.cloudSave), isEmpty);
      });

      test('capabilities is the union across providers', () {
        final services = UnifiedGameServices(
          providers: [
            FakeProvider(name: 'a', caps: {GameCapability.friends}),
            FakeProvider(name: 'b', caps: {GameCapability.stats}),
          ],
        );
        expect(services.capabilities, {
          GameCapability.friends,
          GameCapability.stats,
        });
      });
    });

    test('writes throw CapabilityNotSupported when no provider has it', () {
      final services = UnifiedGameServices(
        providers: [FakeProvider(name: 'a')],
      );
      expect(services.capabilities, isEmpty);
      expect(services.providersFor(GameCapability.stats), isEmpty);
      expect(
        () => services.submitScore(leaderboardId: 'l', score: 1),
        throwsA(isA<CapabilityNotSupportedException>()),
      );
    });

    test('reads come from the primary provider by default', () async {
      final a = FakeProvider(name: 'a', caps: {GameCapability.achievements});
      final b = FakeProvider(name: 'b', caps: {GameCapability.achievements});
      final services = UnifiedGameServices(providers: [a, b]);

      final list = await services.getAchievements();
      expect(list.single.id, 'a-a');
      expect(a.calls, contains('getAchievements'));
      expect(b.calls, isEmpty);
    });

    test('reads tag results with the source providerId', () async {
      final a = FakeProvider(name: 'a', caps: {GameCapability.achievements});
      final b = FakeProvider(name: 'b', caps: {GameCapability.achievements});
      final services = UnifiedGameServices(providers: [a, b]);

      expect((await services.getAchievements()).single.providerId, 'a');
      expect((await services.getAchievements(from: b)).single.providerId, 'b');
      expect((await services.getCurrentPlayer(from: b))?.providerId, 'b');
      final signIn = await services.signIn();
      expect(signIn['b']!.valueOrNull?.providerId, 'b');
    });

    test('reads can target a specific provider with from:', () async {
      final a = FakeProvider(name: 'a', caps: {GameCapability.achievements});
      final b = FakeProvider(name: 'b', caps: {GameCapability.achievements});
      final services = UnifiedGameServices(providers: [a, b]);

      final list = await services.getAchievements(from: b);
      expect(list.single.id, 'b-a');
      expect(b.calls, contains('getAchievements'));
    });

    test('signIn fans out to every provider', () async {
      final a = FakeProvider(name: 'a');
      final b = FakeProvider(name: 'b');
      final services = UnifiedGameServices(providers: [a, b]);

      final result = await services.signIn();
      expect(a.calls, contains('signIn'));
      expect(b.calls, contains('signIn'));
      expect(result.allSucceeded, isTrue);
      expect(result['a']!.valueOrNull?.id, 'a');
    });

    test('provider<T>() finds a provider by type', () {
      final a = FakeProvider(name: 'a');
      final services = UnifiedGameServices(providers: [a]);
      expect(services.provider<FakeProvider>(), same(a));
    });

    test('events merges all provider streams', () async {
      final a = FakeProvider(name: 'a');
      final b = FakeProvider(name: 'b');
      final services = UnifiedGameServices(providers: [a, b]);

      final received = <String>[];
      final sub = services.events.listen(
        (e) => received.add((e as ScoreSubmittedEvent).leaderboardId),
      );

      a.controller.add(
        ScoreSubmittedEvent(
          leaderboardId: 'from-a',
          score: 1,
          timestamp: DateTime.now(),
        ),
      );
      b.controller.add(
        ScoreSubmittedEvent(
          leaderboardId: 'from-b',
          score: 2,
          timestamp: DateTime.now(),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, containsAll(['from-a', 'from-b']));
      await sub.cancel();
    });
  });

  group('GameServices (static)', () {
    setUp(GameServices.reset);
    tearDown(GameServices.reset);

    test('static calls delegate to the global facade', () async {
      final a = FakeProvider(
        name: 'a',
        caps: {GameCapability.leaderboards, GameCapability.achievements},
      );
      GameServices.initialize(providers: [a]);

      final result = await GameServices.submitScore(
        leaderboardId: 'lb',
        score: 7,
      );
      expect(result.allSucceeded, isTrue);
      expect(a.calls, contains('score:lb:7'));
      expect(GameServices.supports(GameCapability.achievements), isTrue);
      expect((await GameServices.getAchievements()).single.providerId, 'a');
      expect(GameServices.provider<FakeProvider>(), same(a));
    });

    test('calls before initialize throw StateError', () {
      expect(
        () => GameServices.submitScore(leaderboardId: 'lb', score: 1),
        throwsStateError,
      );
    });

    test(
      'unified tables inject provider-specific mappings during initialize',
      () {
        final a = FakeProvider(name: 'steam');
        final b = FakeProvider(name: 'google_play');

        GameServices.initialize(
          providers: [a, b],
          achievements: UnifiedAchievementTable({
            'first_win': ProviderIdMap(
              steam: 'ACH_WIN_ONE_GAME',
              googlePlay: 'CgkI123456789_AQ',
            ),
          }),
          leaderboards: UnifiedLeaderboardTable({
            'global': ProviderIdMap(
              steam: 'SteamGlobalBoard',
              googlePlay: 'PlayGlobalBoard',
            ),
          }),
        );

        expect(a.resolveAchievementId('first_win'), 'ACH_WIN_ONE_GAME');
        expect(b.resolveAchievementId('first_win'), 'CgkI123456789_AQ');
        expect(a.resolveLeaderboardId('global'), 'SteamGlobalBoard');
        expect(b.resolveLeaderboardId('global'), 'PlayGlobalBoard');
      },
    );

    test(
      'reserved capability calls throw CapabilityNotSupportedException when unsupported',
      () {
        final a = FakeProvider(name: 'a');
        GameServices.initialize(providers: [a]);

        expect(
          () => GameServices.findLobbies(),
          throwsA(isA<CapabilityNotSupportedException>()),
        );
        expect(
          () => GameServices.createLobby(),
          throwsA(isA<CapabilityNotSupportedException>()),
        );
        expect(
          () => GameServices.startMatchmaking(),
          throwsA(isA<CapabilityNotSupportedException>()),
        );
        expect(
          () => GameServices.showAchievementsUI(),
          throwsA(isA<CapabilityNotSupportedException>()),
        );
        expect(
          () => GameServices.getIdentityToken(),
          throwsA(isA<CapabilityNotSupportedException>()),
        );
      },
    );
  });
}
