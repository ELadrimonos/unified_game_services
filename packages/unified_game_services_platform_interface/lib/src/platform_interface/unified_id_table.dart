/// Mapping structures for unified keys to platform-specific native IDs.
///
/// A [UnifiedIdTable] translates one portable key (e.g. `'first_win'`) into the
/// native id each provider uses. Tables are handed to the `UnifiedGameServices`
/// facade, which registers each provider's slice through
/// [UnifiedGameServicesPlatform.registerMappings].
///
/// @docImport 'platform_interface.dart';
library;

import 'dart:collection';

/// Constants for the well-known [UnifiedGameServicesPlatform.providerId]
/// values.
///
/// These are the keys used inside a [ProviderIdMap]. Lookups compare against
/// the exact id a provider reports, so a custom provider with its own id is
/// addressed through the `custom` argument of [ProviderIdMap.new].
abstract final class ProviderId {
  /// The id of the Steam provider.
  static const String steam = 'steam';

  /// The id of the Epic Online Services provider.
  static const String epic = 'epic';

  /// The id of the Apple Game Center provider.
  static const String gameCenter = 'game_center';

  /// A key shared by both Google Play Games providers.
  ///
  /// No provider reports this id. An entry under it applies to both
  /// [googlePlayRest] and [googlePlayAndroid] (Play Console ids are the same
  /// for either tier); an entry under the tier's own id takes precedence.
  static const String googlePlay = 'google_play';

  /// The fallback key looked up for [providerId] when its row has no entry
  /// of its own, or `null` if there is none.
  static String? _fallbackFor(String providerId) => switch (providerId) {
    googlePlayRest || googlePlayAndroid => googlePlay,
    _ => null,
  };

  /// The id of the Google Play Games REST provider.
  static const String googlePlayRest = 'google_play_rest';

  /// The id of the Google Play Games on-device Android provider.
  static const String googlePlayAndroid = 'google_play_android';

  /// The id of the GameJolt provider.
  static const String gameJolt = 'gamejolt';

  /// The id of the PlayFab provider.
  static const String playFab = 'playfab';

  /// The id of the Xbox (PC) provider.
  static const String xboxPc = 'xbox_pc';
}

/// An unmodifiable map from provider id to native id for one unified key.
///
/// A [Map] of `providerId -> nativeId` built from named arguments, so it can
/// be used as a row of [UnifiedAchievementTable], [UnifiedLeaderboardTable] or
/// [UnifiedStatTable]. Arguments left `null` are omitted from the map.
///
/// ```dart
/// UnifiedAchievementTable({
///   'first_win': ProviderIdMap(
///     steam: 'ACH_WIN_ONE_GAME',
///     googlePlay: 'CgkI123456789_AQ',
///   ),
/// })
/// ```
class ProviderIdMap extends MapView<String, String> {
  /// Creates a map with one entry per non-`null` argument.
  ///
  /// Each named argument is keyed by its matching [ProviderId] constant.
  /// [custom] adds entries for providers without a named argument (keyed by
  /// their [UnifiedGameServicesPlatform.providerId]); on a key clash it
  /// overrides the named arguments.
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

/// Base class for mapping a unified key to platform-specific native IDs.
///
/// A unified key such as `'first_win'` maps to the native id on each provider,
/// e.g. `'steam' => 'ACH_WIN_ONE_GAME'`. Subclasses only fix what kind of id
/// the table holds (achievement, leaderboard or stat).
abstract class UnifiedIdTable {
  /// Maps a unified key to a map of `providerId` -> native ID.
  ///
  /// ```dart
  /// UnifiedAchievementTable({
  ///   'first_win': ProviderIdMap(
  ///     steam: 'ACH_WIN_ONE_GAME',
  ///     googlePlay: 'CgkI123456789_AQ',
  ///   ),
  /// })
  /// ```
  final Map<String, Map<String, String>> mappings;

  /// Creates a table backed by [mappings].
  ///
  /// The map is not copied, so it should not be mutated afterwards.
  const UnifiedIdTable(this.mappings);

  /// The native ID of [unifiedId] on every provider, keyed by `providerId`.
  ///
  /// Read-only; empty when [unifiedId] has no row.
  Map<String, String> nativeIdsFor(String unifiedId) =>
      Map.unmodifiable(mappings[unifiedId] ?? const <String, String>{});

  /// Extracts the unified key -> native ID map for [providerId].
  ///
  /// This is the slice a provider receives through
  /// [UnifiedGameServicesPlatform.registerMappings]. Unified keys with no entry
  /// for [providerId] are omitted. For the Google Play providers, an entry
  /// under [ProviderId.googlePlay] is used when the row has none under the
  /// provider's own id.
  Map<String, String> forProvider(String providerId) {
    final result = <String, String>{};
    for (final entry in mappings.entries) {
      final nativeId = _nativeIdIn(entry.value, providerId);
      if (nativeId != null) {
        result[entry.key] = nativeId;
      }
    }
    return result;
  }

  /// The inverse of [forProvider]: native ID -> unified key for [providerId].
  ///
  /// When two unified keys map to the same native ID, the first one wins.
  Map<String, String> reverseForProvider(String providerId) {
    final result = <String, String>{};
    for (final entry in mappings.entries) {
      final nativeId = _nativeIdIn(entry.value, providerId);
      if (nativeId != null) result.putIfAbsent(nativeId, () => entry.key);
    }
    return result;
  }

  static String? _nativeIdIn(Map<String, String> row, String providerId) {
    final fallback = ProviderId._fallbackFor(providerId);
    return row[providerId] ?? (fallback == null ? null : row[fallback]);
  }
}

/// Table mapping unified achievement keys to platform-specific achievement IDs.
class UnifiedAchievementTable extends UnifiedIdTable {
  /// Creates a table from [mappings] of unified key -> `providerId` -> id.
  const UnifiedAchievementTable(super.mappings);

  /// Creates a table from [map], equivalent to the default constructor.
  factory UnifiedAchievementTable.fromMap(
    Map<String, Map<String, String>> map,
  ) => UnifiedAchievementTable(map);
}

/// Table mapping unified leaderboard keys to platform-specific leaderboard IDs.
class UnifiedLeaderboardTable extends UnifiedIdTable {
  /// Creates a table from [mappings] of unified key -> `providerId` -> id.
  const UnifiedLeaderboardTable(super.mappings);

  /// Creates a table from [map], equivalent to the default constructor.
  factory UnifiedLeaderboardTable.fromMap(
    Map<String, Map<String, String>> map,
  ) => UnifiedLeaderboardTable(map);
}

/// Table mapping unified stat keys to platform-specific stat IDs.
class UnifiedStatTable extends UnifiedIdTable {
  /// Creates a table from [mappings] of unified key -> `providerId` -> key.
  const UnifiedStatTable(super.mappings);

  /// Creates a table from [map], equivalent to the default constructor.
  factory UnifiedStatTable.fromMap(Map<String, Map<String, String>> map) =>
      UnifiedStatTable(map);
}
