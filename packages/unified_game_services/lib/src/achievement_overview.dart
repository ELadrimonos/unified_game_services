import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'multi_provider_result.dart';

/// One achievement across every provider that reports it, keyed by its unified
/// [id].
///
/// Built by `UnifiedGameServices.getAchievementOverview`, which merges each
/// provider's achievements by unified id. Answers "is this unlocked on Steam?
/// on GameJolt?" without comparing native ids by hand.
///
/// ```dart
/// final overview = await services.getAchievementOverview();
/// final win = overview['first_win'];
/// if (win != null && win.isUnlockedAnywhere && !win.isUnlockedEverywhere) {
///   print('still locked on ${win.lockedOn}');
/// }
/// ```
class AchievementStatus {
  /// Creates an entry for [id] from the per-provider [byProvider] views.
  ///
  /// [byProvider] is copied into an unmodifiable map.
  AchievementStatus(this.id, Map<String, Achievement> byProvider)
    : byProvider = Map.unmodifiable(byProvider);

  /// The unified achievement id (see [Achievement.id]).
  final String id;

  /// The achievement as each provider reports it, keyed by `providerId`.
  ///
  /// Only providers that actually list this achievement appear here.
  final Map<String, Achievement> byProvider;

  /// The `providerId`s that report this achievement.
  Set<String> get providers => byProvider.keys.toSet();

  /// Whether it is unlocked on [providerId].
  ///
  /// Returns `null` when that provider does not list this achievement (or is
  /// not one of the providers read), which differs from `false` (listed but
  /// locked).
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

  /// The earliest [Achievement.unlockedAt] across providers.
  ///
  /// `null` when no provider reports an unlock time, even if the achievement is
  /// unlocked (not every provider exposes timestamps).
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
      'AchievementStatus($id, unlockedOn: $unlockedOn, lockedOn: $lockedOn)';
}

/// Every provider's achievements merged by unified id, plus the providers that
/// could not be read.
///
/// Returned by `UnifiedGameServices.getAchievementOverview`. Achievements merge
/// only when they share a unified id: ids come from the `achievements` table
/// given to the `UnifiedGameServices` constructor, and an achievement with no table row
/// keeps its native id, so it merges with another provider's only if both
/// natives are spelled identically.
class AchievementOverview {
  /// Creates an overview from merged [achievements] and the [failed] reads.
  ///
  /// Both are copied into unmodifiable lists.
  AchievementOverview(
    Iterable<AchievementStatus> achievements,
    Iterable<OperationFailure<List<Achievement>>> failed,
  ) : achievements = List.unmodifiable(achievements),
      failed = List.unmodifiable(failed);

  /// One entry per unified id, ordered by first appearance (providers in facade
  /// priority order, then each provider's own order).
  ///
  /// Empty when no provider reported any achievement.
  final List<AchievementStatus> achievements;

  /// Providers whose achievements could not be read. They are absent from
  /// every [AchievementStatus.byProvider].
  final List<OperationFailure<List<Achievement>>> failed;

  /// The entry for the unified [id], or `null` if no provider reported it.
  ///
  /// Linear scan over [achievements].
  AchievementStatus? operator [](String id) {
    for (final a in achievements) {
      if (a.id == id) return a;
    }
    return null;
  }
}
