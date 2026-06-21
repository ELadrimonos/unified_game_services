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
  Future<void> submitScore({required String leaderboardId, required int score}) =>
      _record('score:$leaderboardId:$score');

  @override
  Future<List<Achievement>> getAchievements() async {
    calls.add('getAchievements');
    return [Achievement(id: '$name-a', title: name)];
  }
}

void main() {
  group('UnifiedGameServices', () {
    test('defaults to the registered platform instance', () {
      final fake = FakeProvider(name: 'reg');
      UnifiedGameServicesPlatform.instance = fake;
      final services = UnifiedGameServices();
      expect(services.providers, [fake]);
      expect(services.primary, fake);
    });

    test('supports is any-provider; supportsEverywhere is all', () {
      final services = UnifiedGameServices(providers: [
        FakeProvider(name: 'a', caps: {GameCapability.achievements}),
        FakeProvider(name: 'b', caps: {GameCapability.leaderboards}),
      ]);
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

    test('write throws CapabilityNotSupported when nobody supports it',
        () async {
      final services =
          UnifiedGameServices(providers: [FakeProvider(name: 'a')]);
      expect(
        () => services.unlockAchievement('x'),
        throwsA(isA<CapabilityNotSupportedException>()),
      );
    });

    test('partial fan-out failure throws AggregateGameServiceException',
        () async {
      final a = FakeProvider(name: 'a', caps: {GameCapability.achievements});
      final b = FakeProvider(
          name: 'b',
          caps: {GameCapability.achievements},
          failOn: {'unlock:x'});
      final services = UnifiedGameServices(providers: [a, b]);

      await expectLater(
        services.unlockAchievement('x'),
        throwsA(isA<AggregateGameServiceException>()),
      );
      // The op was still attempted on the healthy provider.
      expect(a.calls, contains('unlock:x'));
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

    test('reads can target a specific provider with from:', () async {
      final a = FakeProvider(name: 'a');
      final b = FakeProvider(name: 'b');
      final services = UnifiedGameServices(providers: [a, b]);

      final list = await services.getAchievements(from: b);
      expect(list.single.id, 'b-a');
      expect(b.calls, contains('getAchievements'));
    });

    test('signIn fans out and returns the primary profile', () async {
      final a = FakeProvider(name: 'a');
      final b = FakeProvider(name: 'b');
      final services = UnifiedGameServices(providers: [a, b]);

      final profile = await services.signIn();
      expect(a.calls, contains('signIn'));
      expect(b.calls, contains('signIn'));
      expect(profile?.id, 'a');
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
          (e) => received.add((e as ScoreSubmittedEvent).leaderboardId));

      a.controller.add(
          ScoreSubmittedEvent(leaderboardId: 'from-a', score: 1, timestamp: DateTime.now()));
      b.controller.add(
          ScoreSubmittedEvent(leaderboardId: 'from-b', score: 2, timestamp: DateTime.now()));
      await Future<void>.delayed(Duration.zero);

      expect(received, containsAll(['from-a', 'from-b']));
      await sub.cancel();
    });
  });
}
