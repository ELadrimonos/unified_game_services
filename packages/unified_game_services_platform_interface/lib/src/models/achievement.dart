import 'package:dart_mappable/dart_mappable.dart';

part 'achievement.mapper.dart';

/// A single achievement and the signed-in player's progress on it.
///
/// Achievements come in two shapes:
/// - **Standard**: unlocked in one step ([isIncremental] is `false`).
/// - **Incremental**: unlocked by accumulating [currentSteps] up to
///   [totalSteps] (e.g. "win 50 matches"). Providers that model progress as a
///   percentage map it onto steps out of 100.
@MappableClass()
class Achievement with AchievementMappable {
  /// Provider-scoped unique identifier.
  final String id;

  /// Localized title.
  final String title;

  /// Localized description, if available.
  final String? description;

  /// Whether the player has unlocked this achievement.
  final bool isUnlocked;

  /// When the achievement was unlocked, if known.
  final DateTime? unlockedAt;

  /// Whether the achievement is hidden until unlocked.
  final bool? isHidden;

  /// Icon URL for the current (locked/unlocked) state, if available.
  final String? iconUrl;

  /// Steps the player has completed (incremental achievements only).
  final int currentSteps;

  /// Total steps required to unlock (0 for standard achievements).
  final int totalSteps;

  const Achievement({
    required this.id,
    required this.title,
    this.description,
    this.isUnlocked = false,
    this.unlockedAt,
    this.isHidden,
    this.iconUrl,
    this.currentSteps = 0,
    this.totalSteps = 0,
  });

  /// Whether this achievement tracks step-based progress.
  bool get isIncremental => totalSteps > 0;

  /// Progress in the range `0.0`–`1.0`. Unlocked achievements report `1.0`.
  double get progressPercentage {
    if (isUnlocked) return 1.0;
    if (totalSteps == 0) return 0.0;
    return (currentSteps / totalSteps).clamp(0.0, 1.0);
  }
}
