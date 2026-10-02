/// Mapping structures for unified keys to platform-specific native IDs.
library;

import 'dart:collection';

/// Constants for official provider IDs.
abstract final class ProviderId {
  static const String steam = 'steam';
  static const String epic = 'epic';
  static const String gameCenter = 'game_center';
  static const String googlePlay = 'google_play';
  static const String googlePlayRest = 'google_play_rest';
  static const String googlePlayAndroid = 'google_play_android';
  static const String gameJolt = 'gamejolt';
  static const String playFab = 'playfab';
  static const String xboxPc = 'xbox_pc';
}

/// Strongly-typed map helper for associating provider IDs with platform-specific IDs.
///
/// Implements [Map<String, String>] so it can be used directly inside
/// [UnifiedAchievementTable], [UnifiedLeaderboardTable], or [UnifiedStatTable].
///
/// Example:
/// ```dart
/// UnifiedAchievementTable({
///   'first_win': ProviderIdMap(
///     steam: 'ACH_WIN_ONE_GAME',
///     googlePlay: 'CgkI123456789_AQ',
///   ),
/// })
/// ```
class ProviderIdMap extends MapView<String, String> {
  ProviderIdMap({
    String? steam,
    String? epic,
    String? gameCenter,
    String? googlePlay,
    String? googlePlayRest,
    String? googlePlayAndroid,
    String? gameJolt,
    String? playFab,
    String? xboxPc,
    Map<String, String>? custom,
  }) : super(
         UnmodifiableMapView({
           ProviderId.steam: ?steam,
           ProviderId.epic: ?epic,
           ProviderId.gameCenter: ?gameCenter,
           ProviderId.googlePlay: ?googlePlay,
           ProviderId.googlePlayRest: ?googlePlayRest,
           ProviderId.googlePlayAndroid: ?googlePlayAndroid,
           ProviderId.gameJolt: ?gameJolt,
           ProviderId.playFab: ?playFab,
           ProviderId.xboxPc: ?xboxPc,
           ...?custom,
         }),
       );
}

/// Base class for mapping a unified key (e.g. `'first_win'`) to platform-specific
/// native IDs across providers (e.g. `'steam' => 'ACH_WIN_ONE_GAME'`).
abstract class UnifiedIdTable {
  /// Maps a unified key to a map of `providerId` -> native ID.
  ///
  /// Example:
  /// ```dart
  /// UnifiedAchievementTable({
  ///   'first_win': ProviderIdMap(
  ///     steam: 'ACH_WIN_ONE_GAME',
  ///     googlePlay: 'CgkI123456789_AQ',
  ///   ),
  /// })
  /// ```
  final Map<String, Map<String, String>> mappings;

  const UnifiedIdTable(this.mappings);

  /// Extracts the native ID map for a specific [providerId].
  Map<String, String> forProvider(String providerId) {
    final result = <String, String>{};
    for (final entry in mappings.entries) {
      final nativeId = entry.value[providerId];
      if (nativeId != null) {
        result[entry.key] = nativeId;
      }
    }
    return result;
  }
}

/// Table mapping unified achievement keys to platform-specific achievement IDs.
class UnifiedAchievementTable extends UnifiedIdTable {
  const UnifiedAchievementTable(super.mappings);

  factory UnifiedAchievementTable.fromMap(
    Map<String, Map<String, String>> map,
  ) => UnifiedAchievementTable(map);
}

/// Table mapping unified leaderboard keys to platform-specific leaderboard IDs.
class UnifiedLeaderboardTable extends UnifiedIdTable {
  const UnifiedLeaderboardTable(super.mappings);

  factory UnifiedLeaderboardTable.fromMap(
    Map<String, Map<String, String>> map,
  ) => UnifiedLeaderboardTable(map);
}

/// Extension allowing any `Map<String, Map<String, String>>` to extract provider-specific mappings.
extension UnifiedIdMapExtension on Map<String, Map<String, String>> {
  /// Extracts the native ID map for a specific [providerId].
  Map<String, String> forProvider(String providerId) {
    final result = <String, String>{};
    for (final entry in entries) {
      final nativeId = entry.value[providerId];
      if (nativeId != null) {
        result[entry.key] = nativeId;
      }
    }
    return result;
  }
}
