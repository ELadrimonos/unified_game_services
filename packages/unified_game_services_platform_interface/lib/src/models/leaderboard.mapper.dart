// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'leaderboard.dart';

class LeaderboardEntryMapper extends ClassMapperBase<LeaderboardEntry> {
  LeaderboardEntryMapper._();

  static LeaderboardEntryMapper? _instance;
  static LeaderboardEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LeaderboardEntryMapper._());
      PlayerProfileMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'LeaderboardEntry';

  static int _$rank(LeaderboardEntry v) => v.rank;
  static const Field<LeaderboardEntry, int> _f$rank = Field('rank', _$rank);
  static PlayerProfile _$player(LeaderboardEntry v) => v.player;
  static const Field<LeaderboardEntry, PlayerProfile> _f$player = Field(
    'player',
    _$player,
  );
  static int _$score(LeaderboardEntry v) => v.score;
  static const Field<LeaderboardEntry, int> _f$score = Field('score', _$score);
  static String? _$formattedScore(LeaderboardEntry v) => v.formattedScore;
  static const Field<LeaderboardEntry, String> _f$formattedScore = Field(
    'formattedScore',
    _$formattedScore,
    opt: true,
  );
  static DateTime? _$achievedAt(LeaderboardEntry v) => v.achievedAt;
  static const Field<LeaderboardEntry, DateTime> _f$achievedAt = Field(
    'achievedAt',
    _$achievedAt,
    opt: true,
  );

  @override
  final MappableFields<LeaderboardEntry> fields = const {
    #rank: _f$rank,
    #player: _f$player,
    #score: _f$score,
    #formattedScore: _f$formattedScore,
    #achievedAt: _f$achievedAt,
  };

  static LeaderboardEntry _instantiate(DecodingData data) {
    return LeaderboardEntry(
      rank: data.dec(_f$rank),
      player: data.dec(_f$player),
      score: data.dec(_f$score),
      formattedScore: data.dec(_f$formattedScore),
      achievedAt: data.dec(_f$achievedAt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LeaderboardEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LeaderboardEntry>(map);
  }

  static LeaderboardEntry fromJson(String json) {
    return ensureInitialized().decodeJson<LeaderboardEntry>(json);
  }
}

mixin LeaderboardEntryMappable {
  String toJson() {
    return LeaderboardEntryMapper.ensureInitialized()
        .encodeJson<LeaderboardEntry>(this as LeaderboardEntry);
  }

  Map<String, dynamic> toMap() {
    return LeaderboardEntryMapper.ensureInitialized()
        .encodeMap<LeaderboardEntry>(this as LeaderboardEntry);
  }

  LeaderboardEntryCopyWith<LeaderboardEntry, LeaderboardEntry, LeaderboardEntry>
  get copyWith =>
      _LeaderboardEntryCopyWithImpl<LeaderboardEntry, LeaderboardEntry>(
        this as LeaderboardEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LeaderboardEntryMapper.ensureInitialized().stringifyValue(
      this as LeaderboardEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return LeaderboardEntryMapper.ensureInitialized().equalsValue(
      this as LeaderboardEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return LeaderboardEntryMapper.ensureInitialized().hashValue(
      this as LeaderboardEntry,
    );
  }
}

extension LeaderboardEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LeaderboardEntry, $Out> {
  LeaderboardEntryCopyWith<$R, LeaderboardEntry, $Out>
  get $asLeaderboardEntry =>
      $base.as((v, t, t2) => _LeaderboardEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LeaderboardEntryCopyWith<$R, $In extends LeaderboardEntry, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  PlayerProfileCopyWith<$R, PlayerProfile, PlayerProfile> get player;
  $R call({
    int? rank,
    PlayerProfile? player,
    int? score,
    String? formattedScore,
    DateTime? achievedAt,
  });
  LeaderboardEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _LeaderboardEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LeaderboardEntry, $Out>
    implements LeaderboardEntryCopyWith<$R, LeaderboardEntry, $Out> {
  _LeaderboardEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LeaderboardEntry> $mapper =
      LeaderboardEntryMapper.ensureInitialized();
  @override
  PlayerProfileCopyWith<$R, PlayerProfile, PlayerProfile> get player =>
      $value.player.copyWith.$chain((v) => call(player: v));
  @override
  $R call({
    int? rank,
    PlayerProfile? player,
    int? score,
    Object? formattedScore = $none,
    Object? achievedAt = $none,
  }) => $apply(
    FieldCopyWithData({
      if (rank != null) #rank: rank,
      if (player != null) #player: player,
      if (score != null) #score: score,
      if (formattedScore != $none) #formattedScore: formattedScore,
      if (achievedAt != $none) #achievedAt: achievedAt,
    }),
  );
  @override
  LeaderboardEntry $make(CopyWithData data) => LeaderboardEntry(
    rank: data.get(#rank, or: $value.rank),
    player: data.get(#player, or: $value.player),
    score: data.get(#score, or: $value.score),
    formattedScore: data.get(#formattedScore, or: $value.formattedScore),
    achievedAt: data.get(#achievedAt, or: $value.achievedAt),
  );

  @override
  LeaderboardEntryCopyWith<$R2, LeaderboardEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LeaderboardEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LeaderboardMapper extends ClassMapperBase<Leaderboard> {
  LeaderboardMapper._();

  static LeaderboardMapper? _instance;
  static LeaderboardMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LeaderboardMapper._());
      LeaderboardOrderMapper.ensureInitialized();
      LeaderboardTimeScopeMapper.ensureInitialized();
      LeaderboardCollectionMapper.ensureInitialized();
      LeaderboardEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Leaderboard';

  static String _$id(Leaderboard v) => v.id;
  static const Field<Leaderboard, String> _f$id = Field('id', _$id);
  static String? _$displayName(Leaderboard v) => v.displayName;
  static const Field<Leaderboard, String> _f$displayName = Field(
    'displayName',
    _$displayName,
    opt: true,
  );
  static LeaderboardOrder _$order(Leaderboard v) => v.order;
  static const Field<Leaderboard, LeaderboardOrder> _f$order = Field(
    'order',
    _$order,
    opt: true,
    def: LeaderboardOrder.highToLow,
  );
  static LeaderboardTimeScope _$timeScope(Leaderboard v) => v.timeScope;
  static const Field<Leaderboard, LeaderboardTimeScope> _f$timeScope = Field(
    'timeScope',
    _$timeScope,
    opt: true,
    def: LeaderboardTimeScope.allTime,
  );
  static LeaderboardCollection _$collection(Leaderboard v) => v.collection;
  static const Field<Leaderboard, LeaderboardCollection> _f$collection = Field(
    'collection',
    _$collection,
    opt: true,
    def: LeaderboardCollection.global,
  );
  static List<LeaderboardEntry> _$entries(Leaderboard v) => v.entries;
  static const Field<Leaderboard, List<LeaderboardEntry>> _f$entries = Field(
    'entries',
    _$entries,
    opt: true,
    def: const [],
  );
  static LeaderboardEntry? _$playerEntry(Leaderboard v) => v.playerEntry;
  static const Field<Leaderboard, LeaderboardEntry> _f$playerEntry = Field(
    'playerEntry',
    _$playerEntry,
    opt: true,
  );

  @override
  final MappableFields<Leaderboard> fields = const {
    #id: _f$id,
    #displayName: _f$displayName,
    #order: _f$order,
    #timeScope: _f$timeScope,
    #collection: _f$collection,
    #entries: _f$entries,
    #playerEntry: _f$playerEntry,
  };

  static Leaderboard _instantiate(DecodingData data) {
    return Leaderboard(
      id: data.dec(_f$id),
      displayName: data.dec(_f$displayName),
      order: data.dec(_f$order),
      timeScope: data.dec(_f$timeScope),
      collection: data.dec(_f$collection),
      entries: data.dec(_f$entries),
      playerEntry: data.dec(_f$playerEntry),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Leaderboard fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Leaderboard>(map);
  }

  static Leaderboard fromJson(String json) {
    return ensureInitialized().decodeJson<Leaderboard>(json);
  }
}

mixin LeaderboardMappable {
  String toJson() {
    return LeaderboardMapper.ensureInitialized().encodeJson<Leaderboard>(
      this as Leaderboard,
    );
  }

  Map<String, dynamic> toMap() {
    return LeaderboardMapper.ensureInitialized().encodeMap<Leaderboard>(
      this as Leaderboard,
    );
  }

  LeaderboardCopyWith<Leaderboard, Leaderboard, Leaderboard> get copyWith =>
      _LeaderboardCopyWithImpl<Leaderboard, Leaderboard>(
        this as Leaderboard,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LeaderboardMapper.ensureInitialized().stringifyValue(
      this as Leaderboard,
    );
  }

  @override
  bool operator ==(Object other) {
    return LeaderboardMapper.ensureInitialized().equalsValue(
      this as Leaderboard,
      other,
    );
  }

  @override
  int get hashCode {
    return LeaderboardMapper.ensureInitialized().hashValue(this as Leaderboard);
  }
}

extension LeaderboardValueCopy<$R, $Out>
    on ObjectCopyWith<$R, Leaderboard, $Out> {
  LeaderboardCopyWith<$R, Leaderboard, $Out> get $asLeaderboard =>
      $base.as((v, t, t2) => _LeaderboardCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LeaderboardCopyWith<$R, $In extends Leaderboard, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    LeaderboardEntry,
    LeaderboardEntryCopyWith<$R, LeaderboardEntry, LeaderboardEntry>
  >
  get entries;
  LeaderboardEntryCopyWith<$R, LeaderboardEntry, LeaderboardEntry>?
  get playerEntry;
  $R call({
    String? id,
    String? displayName,
    LeaderboardOrder? order,
    LeaderboardTimeScope? timeScope,
    LeaderboardCollection? collection,
    List<LeaderboardEntry>? entries,
    LeaderboardEntry? playerEntry,
  });
  LeaderboardCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _LeaderboardCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Leaderboard, $Out>
    implements LeaderboardCopyWith<$R, Leaderboard, $Out> {
  _LeaderboardCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Leaderboard> $mapper =
      LeaderboardMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    LeaderboardEntry,
    LeaderboardEntryCopyWith<$R, LeaderboardEntry, LeaderboardEntry>
  >
  get entries => ListCopyWith(
    $value.entries,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(entries: v),
  );
  @override
  LeaderboardEntryCopyWith<$R, LeaderboardEntry, LeaderboardEntry>?
  get playerEntry =>
      $value.playerEntry?.copyWith.$chain((v) => call(playerEntry: v));
  @override
  $R call({
    String? id,
    Object? displayName = $none,
    LeaderboardOrder? order,
    LeaderboardTimeScope? timeScope,
    LeaderboardCollection? collection,
    List<LeaderboardEntry>? entries,
    Object? playerEntry = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (displayName != $none) #displayName: displayName,
      if (order != null) #order: order,
      if (timeScope != null) #timeScope: timeScope,
      if (collection != null) #collection: collection,
      if (entries != null) #entries: entries,
      if (playerEntry != $none) #playerEntry: playerEntry,
    }),
  );
  @override
  Leaderboard $make(CopyWithData data) => Leaderboard(
    id: data.get(#id, or: $value.id),
    displayName: data.get(#displayName, or: $value.displayName),
    order: data.get(#order, or: $value.order),
    timeScope: data.get(#timeScope, or: $value.timeScope),
    collection: data.get(#collection, or: $value.collection),
    entries: data.get(#entries, or: $value.entries),
    playerEntry: data.get(#playerEntry, or: $value.playerEntry),
  );

  @override
  LeaderboardCopyWith<$R2, Leaderboard, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LeaderboardCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

