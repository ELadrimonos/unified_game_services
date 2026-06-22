import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Pure transforms from Google Play Games REST JSON to the unified models.
///
/// Kept as free functions (no `dart_mappable` codegen) because GPG field names
/// differ from the unified model and several fields are int64 values encoded as
/// strings.

/// Maps a GPG `Player` resource to a [PlayerProfile].
PlayerProfile playerProfileFromJson(Map<String, dynamic> json) {
  return PlayerProfile(
    id: '${json['playerId'] ?? ''}',
    displayName: (json['displayName'] as String?) ?? 'Player',
    avatarUrl: json['avatarImageUrl'] as String?,
    extra: json,
  );
}

/// Joins achievement **definitions** with the player's **progress** into the
/// unified [Achievement] list.
///
/// [definitions] come from `GET /achievements`; [progressById] is keyed by
/// achievement id from `GET /players/me/achievements`.
List<Achievement> achievementsFromJson(
  List<Map<String, dynamic>> definitions,
  Map<String, Map<String, dynamic>> progressById,
) {
  return definitions.map((def) {
    final id = '${def['id']}';
    final progress = progressById[id];
    final state =
        (progress?['achievementState'] as String?) ??
        (def['initialState'] as String?) ??
        'HIDDEN';
    final isUnlocked = state == 'UNLOCKED';
    // `totalSteps` is present on INCREMENTAL definitions; 0 for STANDARD.
    final totalSteps = (def['totalSteps'] as num?)?.toInt() ?? 0;
    return Achievement(
      id: id,
      title: (def['name'] as String?) ?? id,
      description: def['description'] as String?,
      isUnlocked: isUnlocked,
      isHidden: state == 'HIDDEN',
      iconUrl:
          (isUnlocked ? def['unlockedIconUrl'] : def['revealedIconUrl'])
              as String?,
      currentSteps: (progress?['currentSteps'] as num?)?.toInt() ?? 0,
      totalSteps: totalSteps,
      unlockedAt: isUnlocked
          ? _millisToDate(progress?['lastUpdatedTimestamp'])
          : null,
    );
  }).toList();
}

/// Maps one row of a `leaderboards/.../scores` response to a [LeaderboardEntry].
///
/// [fallbackRank] is used when the row carries no `scoreRank` (1-based index).
LeaderboardEntry leaderboardEntryFromJson(
  Map<String, dynamic> json, {
  required int fallbackRank,
}) {
  final playerJson = json['player'];
  final player = playerJson is Map<String, dynamic>
      ? playerProfileFromJson(playerJson)
      : const PlayerProfile(id: 'unknown', displayName: 'Player');
  return LeaderboardEntry(
    rank: _parseInt(json['scoreRank']) ?? fallbackRank,
    player: player,
    score: _parseInt(json['scoreValue']) ?? 0,
    formattedScore: json['formattedScore'] as String?,
    achievedAt: _millisToDate(json['writeTimestampMillis']),
  );
}

/// Parses an int that may arrive as an int or as an int64-in-a-string.
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

/// Converts a millisecond epoch (int or string) to a [DateTime], or `null`.
DateTime? _millisToDate(dynamic millis) {
  final value = _parseInt(millis);
  if (value == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(value);
}
