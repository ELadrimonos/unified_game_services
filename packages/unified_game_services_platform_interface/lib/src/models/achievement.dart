import '../internal/equality.dart';

/// A single achievement and the signed-in player's progress on it.
///
/// Achievements come in two shapes:
/// - **Standard**: unlocked in one step ([isIncremental] is `false`).
/// - **Incremental**: unlocked by accumulating [currentSteps] up to
///   [totalSteps] (e.g. "win 50 matches"). Providers that model progress as a
///   percentage map it onto steps out of 100.
class Achievement {
  /// Unified identifier: the key from the `UnifiedAchievementTable` when the
  /// provider's native id is mapped there, otherwise the native id itself.
  ///
  /// Stable across providers, so the same achievement read from Steam and
  /// GameJolt compares equal by [id]. See [nativeIds] for the native ids.
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

  /// [UnifiedGameServicesPlatform.providerId] of the provider this came from.
  ///
  /// Set by the `UnifiedGameServices` facade on reads; `null` when the object
  /// was built by a provider or by hand.
  final String? providerId;

  /// The native id of this achievement on each provider, keyed by
  /// `providerId` (e.g. `{'steam': 'ACH_WIN_ONE_GAME', 'gamejolt': '123456'}`).
  ///
  /// Read-only. Holds the row of the `UnifiedAchievementTable` for [id], plus
  /// the native id the [providerId] provider itself reported. Set by the
  /// `UnifiedGameServices` facade on reads; empty when the object was built by
  /// a provider or by hand.
  final Map<String, String> nativeIds;

  /// The native id on the provider this came from ([providerId]), or `null`
  /// when unknown.
  String? get nativeId => providerId == null ? null : nativeIds[providerId];

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
    this.providerId,
    this.nativeIds = const {},
  });

  /// Whether this achievement tracks step-based progress.
  bool get isIncremental => totalSteps > 0;

  /// Progress in the range `0.0`–`1.0`. Unlocked achievements report `1.0`.
  double get progressPercentage {
    if (isUnlocked) return 1.0;
    if (totalSteps == 0) return 0.0;
    return (currentSteps / totalSteps).clamp(0.0, 1.0);
  }

  /// Returns a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the current value, so a field cannot be reset to
  /// `null` through this method; build a new instance for that.
  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    bool? isUnlocked,
    DateTime? unlockedAt,
    bool? isHidden,
    String? iconUrl,
    int? currentSteps,
    int? totalSteps,
    String? providerId,
    Map<String, String>? nativeIds,
  }) => Achievement(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    isUnlocked: isUnlocked ?? this.isUnlocked,
    unlockedAt: unlockedAt ?? this.unlockedAt,
    isHidden: isHidden ?? this.isHidden,
    iconUrl: iconUrl ?? this.iconUrl,
    currentSteps: currentSteps ?? this.currentSteps,
    totalSteps: totalSteps ?? this.totalSteps,
    providerId: providerId ?? this.providerId,
    nativeIds: nativeIds ?? this.nativeIds,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Achievement &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.isUnlocked == isUnlocked &&
          other.unlockedAt == unlockedAt &&
          other.isHidden == isHidden &&
          other.iconUrl == iconUrl &&
          other.currentSteps == currentSteps &&
          other.totalSteps == totalSteps &&
          other.providerId == providerId &&
          mapEquals(other.nativeIds, nativeIds);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    isUnlocked,
    unlockedAt,
    isHidden,
    iconUrl,
    currentSteps,
    totalSteps,
    providerId,
    mapHash(nativeIds),
  );

  @override
  String toString() =>
      'Achievement(id: $id, title: $title, description: $description, '
      'isUnlocked: $isUnlocked, unlockedAt: $unlockedAt, isHidden: $isHidden, '
      'iconUrl: $iconUrl, currentSteps: $currentSteps, '
      'totalSteps: $totalSteps, providerId: $providerId, '
      'nativeIds: $nativeIds)';
}
