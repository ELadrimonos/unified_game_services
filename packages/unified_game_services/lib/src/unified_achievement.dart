import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'multi_provider_result.dart';

/// One achievement across every provider that reports it, keyed by its unified
/// [id].
///
/// Built by `UnifiedGameServices.getUnifiedAchievements`. Answers "is this
/// unlocked on Steam? on GameJolt?" without comparing native ids by hand.
class UnifiedAchievement {
  /// Creates an entry for [id] from the per-provider [byProvider] views.
  UnifiedAchievement(this.id, Map<String, Achievement> byProvider)
    : byProvider = Map.unmodifiable(byProvider);

  /// The unified achievement id (see [Achievement.id]).
  final String id;

  /// The achievement as each provider reports it, keyed by `providerId`.
  ///
  /// Only providers that actually list this achievement appear here.
  final Map<String, Achievement> byProvider;

  /// The `providerId`s that report this achievement.
  Set<String> get providers => byProvider.keys.toSet();

  /// Whether it is unlocked on [providerId]. `null` when that provider does not
  /// list this achievement.
  bool? isUnlockedOn(String providerId) => byProvider[providerId]?.isUnlocked;

  /// The `providerId`s where it is unlocked.
  Set<String> get unlockedOn => {
    for (final e in byProvider.entries)
      if (e.value.isUnlocked) e.key,
  };

  /// The `providerId`s that list it but still have it locked.
  Set<String> get lockedOn => {
    for (final e in byProvider.entries)
      if (!e.value.isUnlocked) e.key,
  };

  /// Whether it is unlocked on at least one provider.
  bool get isUnlockedAnywhere => byProvider.values.any((a) => a.isUnlocked);

  /// Whether it is unlocked on every provider that lists it.
  bool get isUnlockedEverywhere =>
      byProvider.isNotEmpty && byProvider.values.every((a) => a.isUnlocked);

  /// The earliest known unlock time across providers.
  DateTime? get firstUnlockedAt {
    DateTime? first;
    for (final a in byProvider.values) {
      final t = a.unlockedAt;
      if (t != null && (first == null || t.isBefore(first))) first = t;
    }
    return first;
  }

  @override
  String toString() =>
      'UnifiedAchievement($id, unlockedOn: $unlockedOn, lockedOn: $lockedOn)';
}

/// Every provider's achievements merged by unified id, plus the providers that
/// could not be read.
class AchievementOverview {
  /// Creates an overview.
  AchievementOverview(
    Iterable<UnifiedAchievement> achievements,
    Iterable<ProviderOperationResult<List<Achievement>>> failed,
  ) : achievements = List.unmodifiable(achievements),
      failed = List.unmodifiable(failed);

  /// One entry per unified id, in first-seen order.
  final List<UnifiedAchievement> achievements;

  /// Providers whose achievements could not be read. They are absent from
  /// every [UnifiedAchievement.byProvider].
  final List<ProviderOperationResult<List<Achievement>>> failed;

  /// The entry for [id], or `null`.
  UnifiedAchievement? operator [](String id) {
    for (final a in achievements) {
      if (a.id == id) return a;
    }
    return null;
  }
}
