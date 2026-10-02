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
  Future<List<Achievement>> getAchievements() async {
    calls.add('getAchievements');
    return [Achievement(id: '$name-a', title: name)];
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
      expect(error!.message, 'b:unlock:x');
      expect(result['b']!.success, isFalse);
      expect(result['zzz'], isNull);
      // Every provider was attempted.
      expect(a.calls, contains('unlock:x'));
      expect(b.calls, contains('unlock:x'));
      expect(c.calls, contains('unlock:x'));
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
      expect(result.results.every((r) => r.error == null), isTrue);
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
      expect(result.failed.map((r) => r.error!.message), [
        'a:score:lb:5',
        'b:score:lb:5',
      ]);
    });

    test(
      'non-GameServiceException errors are wrapped with their cause',
      () async {
        // Base-class default throws UnimplementedError for stats.
        final a = FakeProvider(name: 'a', caps: {GameCapability.stats});
        final result = await UnifiedGameServices(
          providers: [a],
        ).setStat('k', 1);

        final error = result.failed.single.error;
        expect(error, isA<PlatformOperationException>());
        expect(error!.cause, isA<UnimplementedError>());
        expect(result.failed.single.stackTrace, isNotNull);
      },
    );

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
      final a = FakeProvider(name: 'a');
      final b = FakeProvider(name: 'b');
      final services = UnifiedGameServices(providers: [a, b]);

      final list = await services.getAchievements();
      expect(list.single.id, 'a-a');
      expect(a.calls, contains('getAchievements'));
      expect(b.calls, isEmpty);
    });

    test('reads tag results with the source providerId', () async {
      final a = FakeProvider(name: 'a');
      final b = FakeProvider(name: 'b');
      final services = UnifiedGameServices(providers: [a, b]);

      expect((await services.getAchievements()).single.providerId, 'a');
      expect((await services.getAchievements(from: b)).single.providerId, 'b');
      expect((await services.getCurrentPlayer(from: b))?.providerId, 'b');
      final signIn = await services.signIn();
      expect(signIn['b']!.value?.providerId, 'b');
    });

    test('reads can target a specific provider with from:', () async {
      final a = FakeProvider(name: 'a');
      final b = FakeProvider(name: 'b');
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
      expect(result['a']!.value?.id, 'a');
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
          }).mappings,
          leaderboards: UnifiedLeaderboardTable({
            'global': ProviderIdMap(
              steam: 'SteamGlobalBoard',
              googlePlay: 'PlayGlobalBoard',
            ),
          }).mappings,
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
          () => GameServices.sendInvitation('friend1'),
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
