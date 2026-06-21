// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'events.dart';

class GameServiceEventMapper extends ClassMapperBase<GameServiceEvent> {
  GameServiceEventMapper._();

  static GameServiceEventMapper? _instance;
  static GameServiceEventMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = GameServiceEventMapper._());
      UserSignedInEventMapper.ensureInitialized();
      UserSignedOutEventMapper.ensureInitialized();
      AchievementUnlockedEventMapper.ensureInitialized();
      ScoreSubmittedEventMapper.ensureInitialized();
      StatUpdatedEventMapper.ensureInitialized();
      PresenceChangedEventMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'GameServiceEvent';

  static DateTime _$timestamp(GameServiceEvent v) => v.timestamp;
  static const Field<GameServiceEvent, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );

  @override
  final MappableFields<GameServiceEvent> fields = const {
    #timestamp: _f$timestamp,
  };

  static GameServiceEvent _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'GameServiceEvent',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static GameServiceEvent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<GameServiceEvent>(map);
  }

  static GameServiceEvent fromJson(String json) {
    return ensureInitialized().decodeJson<GameServiceEvent>(json);
  }
}

mixin GameServiceEventMappable {
  String toJson();
  Map<String, dynamic> toMap();
  GameServiceEventCopyWith<GameServiceEvent, GameServiceEvent, GameServiceEvent>
  get copyWith;
}

abstract class GameServiceEventCopyWith<$R, $In extends GameServiceEvent, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({DateTime? timestamp});
  GameServiceEventCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class UserSignedInEventMapper extends SubClassMapperBase<UserSignedInEvent> {
  UserSignedInEventMapper._();

  static UserSignedInEventMapper? _instance;
  static UserSignedInEventMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = UserSignedInEventMapper._());
      GameServiceEventMapper.ensureInitialized().addSubMapper(_instance!);
      PlayerProfileMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'UserSignedInEvent';

  static PlayerProfile _$player(UserSignedInEvent v) => v.player;
  static const Field<UserSignedInEvent, PlayerProfile> _f$player = Field(
    'player',
    _$player,
  );
  static DateTime _$timestamp(UserSignedInEvent v) => v.timestamp;
  static const Field<UserSignedInEvent, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );

  @override
  final MappableFields<UserSignedInEvent> fields = const {
    #player: _f$player,
    #timestamp: _f$timestamp,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'userSignedIn';
  @override
  late final ClassMapperBase superMapper =
      GameServiceEventMapper.ensureInitialized();

  static UserSignedInEvent _instantiate(DecodingData data) {
    return UserSignedInEvent(
      player: data.dec(_f$player),
      timestamp: data.dec(_f$timestamp),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static UserSignedInEvent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<UserSignedInEvent>(map);
  }

  static UserSignedInEvent fromJson(String json) {
    return ensureInitialized().decodeJson<UserSignedInEvent>(json);
  }
}

mixin UserSignedInEventMappable {
  String toJson() {
    return UserSignedInEventMapper.ensureInitialized()
        .encodeJson<UserSignedInEvent>(this as UserSignedInEvent);
  }

  Map<String, dynamic> toMap() {
    return UserSignedInEventMapper.ensureInitialized()
        .encodeMap<UserSignedInEvent>(this as UserSignedInEvent);
  }

  UserSignedInEventCopyWith<
    UserSignedInEvent,
    UserSignedInEvent,
    UserSignedInEvent
  >
  get copyWith =>
      _UserSignedInEventCopyWithImpl<UserSignedInEvent, UserSignedInEvent>(
        this as UserSignedInEvent,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return UserSignedInEventMapper.ensureInitialized().stringifyValue(
      this as UserSignedInEvent,
    );
  }

  @override
  bool operator ==(Object other) {
    return UserSignedInEventMapper.ensureInitialized().equalsValue(
      this as UserSignedInEvent,
      other,
    );
  }

  @override
  int get hashCode {
    return UserSignedInEventMapper.ensureInitialized().hashValue(
      this as UserSignedInEvent,
    );
  }
}

extension UserSignedInEventValueCopy<$R, $Out>
    on ObjectCopyWith<$R, UserSignedInEvent, $Out> {
  UserSignedInEventCopyWith<$R, UserSignedInEvent, $Out>
  get $asUserSignedInEvent => $base.as(
    (v, t, t2) => _UserSignedInEventCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class UserSignedInEventCopyWith<
  $R,
  $In extends UserSignedInEvent,
  $Out
>
    implements GameServiceEventCopyWith<$R, $In, $Out> {
  PlayerProfileCopyWith<$R, PlayerProfile, PlayerProfile> get player;
  @override
  $R call({PlayerProfile? player, DateTime? timestamp});
  UserSignedInEventCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _UserSignedInEventCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, UserSignedInEvent, $Out>
    implements UserSignedInEventCopyWith<$R, UserSignedInEvent, $Out> {
  _UserSignedInEventCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<UserSignedInEvent> $mapper =
      UserSignedInEventMapper.ensureInitialized();
  @override
  PlayerProfileCopyWith<$R, PlayerProfile, PlayerProfile> get player =>
      $value.player.copyWith.$chain((v) => call(player: v));
  @override
  $R call({PlayerProfile? player, DateTime? timestamp}) => $apply(
    FieldCopyWithData({
      if (player != null) #player: player,
      if (timestamp != null) #timestamp: timestamp,
    }),
  );
  @override
  UserSignedInEvent $make(CopyWithData data) => UserSignedInEvent(
    player: data.get(#player, or: $value.player),
    timestamp: data.get(#timestamp, or: $value.timestamp),
  );

  @override
  UserSignedInEventCopyWith<$R2, UserSignedInEvent, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _UserSignedInEventCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class UserSignedOutEventMapper extends SubClassMapperBase<UserSignedOutEvent> {
  UserSignedOutEventMapper._();

  static UserSignedOutEventMapper? _instance;
  static UserSignedOutEventMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = UserSignedOutEventMapper._());
      GameServiceEventMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'UserSignedOutEvent';

  static DateTime _$timestamp(UserSignedOutEvent v) => v.timestamp;
  static const Field<UserSignedOutEvent, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );

  @override
  final MappableFields<UserSignedOutEvent> fields = const {
    #timestamp: _f$timestamp,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'userSignedOut';
  @override
  late final ClassMapperBase superMapper =
      GameServiceEventMapper.ensureInitialized();

  static UserSignedOutEvent _instantiate(DecodingData data) {
    return UserSignedOutEvent(timestamp: data.dec(_f$timestamp));
  }

  @override
  final Function instantiate = _instantiate;

  static UserSignedOutEvent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<UserSignedOutEvent>(map);
  }

  static UserSignedOutEvent fromJson(String json) {
    return ensureInitialized().decodeJson<UserSignedOutEvent>(json);
  }
}

mixin UserSignedOutEventMappable {
  String toJson() {
    return UserSignedOutEventMapper.ensureInitialized()
        .encodeJson<UserSignedOutEvent>(this as UserSignedOutEvent);
  }

  Map<String, dynamic> toMap() {
    return UserSignedOutEventMapper.ensureInitialized()
        .encodeMap<UserSignedOutEvent>(this as UserSignedOutEvent);
  }

  UserSignedOutEventCopyWith<
    UserSignedOutEvent,
    UserSignedOutEvent,
    UserSignedOutEvent
  >
  get copyWith =>
      _UserSignedOutEventCopyWithImpl<UserSignedOutEvent, UserSignedOutEvent>(
        this as UserSignedOutEvent,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return UserSignedOutEventMapper.ensureInitialized().stringifyValue(
      this as UserSignedOutEvent,
    );
  }

  @override
  bool operator ==(Object other) {
    return UserSignedOutEventMapper.ensureInitialized().equalsValue(
      this as UserSignedOutEvent,
      other,
    );
  }

  @override
  int get hashCode {
    return UserSignedOutEventMapper.ensureInitialized().hashValue(
      this as UserSignedOutEvent,
    );
  }
}

extension UserSignedOutEventValueCopy<$R, $Out>
    on ObjectCopyWith<$R, UserSignedOutEvent, $Out> {
  UserSignedOutEventCopyWith<$R, UserSignedOutEvent, $Out>
  get $asUserSignedOutEvent => $base.as(
    (v, t, t2) => _UserSignedOutEventCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class UserSignedOutEventCopyWith<
  $R,
  $In extends UserSignedOutEvent,
  $Out
>
    implements GameServiceEventCopyWith<$R, $In, $Out> {
  @override
  $R call({DateTime? timestamp});
  UserSignedOutEventCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _UserSignedOutEventCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, UserSignedOutEvent, $Out>
    implements UserSignedOutEventCopyWith<$R, UserSignedOutEvent, $Out> {
  _UserSignedOutEventCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<UserSignedOutEvent> $mapper =
      UserSignedOutEventMapper.ensureInitialized();
  @override
  $R call({DateTime? timestamp}) =>
      $apply(FieldCopyWithData({if (timestamp != null) #timestamp: timestamp}));
  @override
  UserSignedOutEvent $make(CopyWithData data) =>
      UserSignedOutEvent(timestamp: data.get(#timestamp, or: $value.timestamp));

  @override
  UserSignedOutEventCopyWith<$R2, UserSignedOutEvent, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _UserSignedOutEventCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AchievementUnlockedEventMapper
    extends SubClassMapperBase<AchievementUnlockedEvent> {
  AchievementUnlockedEventMapper._();

  static AchievementUnlockedEventMapper? _instance;
  static AchievementUnlockedEventMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = AchievementUnlockedEventMapper._(),
      );
      GameServiceEventMapper.ensureInitialized().addSubMapper(_instance!);
      AchievementMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'AchievementUnlockedEvent';

  static Achievement _$achievement(AchievementUnlockedEvent v) => v.achievement;
  static const Field<AchievementUnlockedEvent, Achievement> _f$achievement =
      Field('achievement', _$achievement);
  static DateTime _$timestamp(AchievementUnlockedEvent v) => v.timestamp;
  static const Field<AchievementUnlockedEvent, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );

  @override
  final MappableFields<AchievementUnlockedEvent> fields = const {
    #achievement: _f$achievement,
    #timestamp: _f$timestamp,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'achievementUnlocked';
  @override
  late final ClassMapperBase superMapper =
      GameServiceEventMapper.ensureInitialized();

  static AchievementUnlockedEvent _instantiate(DecodingData data) {
    return AchievementUnlockedEvent(
      achievement: data.dec(_f$achievement),
      timestamp: data.dec(_f$timestamp),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static AchievementUnlockedEvent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AchievementUnlockedEvent>(map);
  }

  static AchievementUnlockedEvent fromJson(String json) {
    return ensureInitialized().decodeJson<AchievementUnlockedEvent>(json);
  }
}

mixin AchievementUnlockedEventMappable {
  String toJson() {
    return AchievementUnlockedEventMapper.ensureInitialized()
        .encodeJson<AchievementUnlockedEvent>(this as AchievementUnlockedEvent);
  }

  Map<String, dynamic> toMap() {
    return AchievementUnlockedEventMapper.ensureInitialized()
        .encodeMap<AchievementUnlockedEvent>(this as AchievementUnlockedEvent);
  }

  AchievementUnlockedEventCopyWith<
    AchievementUnlockedEvent,
    AchievementUnlockedEvent,
    AchievementUnlockedEvent
  >
  get copyWith =>
      _AchievementUnlockedEventCopyWithImpl<
        AchievementUnlockedEvent,
        AchievementUnlockedEvent
      >(this as AchievementUnlockedEvent, $identity, $identity);
  @override
  String toString() {
    return AchievementUnlockedEventMapper.ensureInitialized().stringifyValue(
      this as AchievementUnlockedEvent,
    );
  }

  @override
  bool operator ==(Object other) {
    return AchievementUnlockedEventMapper.ensureInitialized().equalsValue(
      this as AchievementUnlockedEvent,
      other,
    );
  }

  @override
  int get hashCode {
    return AchievementUnlockedEventMapper.ensureInitialized().hashValue(
      this as AchievementUnlockedEvent,
    );
  }
}

extension AchievementUnlockedEventValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AchievementUnlockedEvent, $Out> {
  AchievementUnlockedEventCopyWith<$R, AchievementUnlockedEvent, $Out>
  get $asAchievementUnlockedEvent => $base.as(
    (v, t, t2) => _AchievementUnlockedEventCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class AchievementUnlockedEventCopyWith<
  $R,
  $In extends AchievementUnlockedEvent,
  $Out
>
    implements GameServiceEventCopyWith<$R, $In, $Out> {
  AchievementCopyWith<$R, Achievement, Achievement> get achievement;
  @override
  $R call({Achievement? achievement, DateTime? timestamp});
  AchievementUnlockedEventCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _AchievementUnlockedEventCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AchievementUnlockedEvent, $Out>
    implements
        AchievementUnlockedEventCopyWith<$R, AchievementUnlockedEvent, $Out> {
  _AchievementUnlockedEventCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AchievementUnlockedEvent> $mapper =
      AchievementUnlockedEventMapper.ensureInitialized();
  @override
  AchievementCopyWith<$R, Achievement, Achievement> get achievement =>
      $value.achievement.copyWith.$chain((v) => call(achievement: v));
  @override
  $R call({Achievement? achievement, DateTime? timestamp}) => $apply(
    FieldCopyWithData({
      if (achievement != null) #achievement: achievement,
      if (timestamp != null) #timestamp: timestamp,
    }),
  );
  @override
  AchievementUnlockedEvent $make(CopyWithData data) => AchievementUnlockedEvent(
    achievement: data.get(#achievement, or: $value.achievement),
    timestamp: data.get(#timestamp, or: $value.timestamp),
  );

  @override
  AchievementUnlockedEventCopyWith<$R2, AchievementUnlockedEvent, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _AchievementUnlockedEventCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ScoreSubmittedEventMapper
    extends SubClassMapperBase<ScoreSubmittedEvent> {
  ScoreSubmittedEventMapper._();

  static ScoreSubmittedEventMapper? _instance;
  static ScoreSubmittedEventMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ScoreSubmittedEventMapper._());
      GameServiceEventMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ScoreSubmittedEvent';

  static String _$leaderboardId(ScoreSubmittedEvent v) => v.leaderboardId;
  static const Field<ScoreSubmittedEvent, String> _f$leaderboardId = Field(
    'leaderboardId',
    _$leaderboardId,
  );
  static int _$score(ScoreSubmittedEvent v) => v.score;
  static const Field<ScoreSubmittedEvent, int> _f$score = Field(
    'score',
    _$score,
  );
  static DateTime _$timestamp(ScoreSubmittedEvent v) => v.timestamp;
  static const Field<ScoreSubmittedEvent, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );

  @override
  final MappableFields<ScoreSubmittedEvent> fields = const {
    #leaderboardId: _f$leaderboardId,
    #score: _f$score,
    #timestamp: _f$timestamp,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'scoreSubmitted';
  @override
  late final ClassMapperBase superMapper =
      GameServiceEventMapper.ensureInitialized();

  static ScoreSubmittedEvent _instantiate(DecodingData data) {
    return ScoreSubmittedEvent(
      leaderboardId: data.dec(_f$leaderboardId),
      score: data.dec(_f$score),
      timestamp: data.dec(_f$timestamp),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ScoreSubmittedEvent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ScoreSubmittedEvent>(map);
  }

  static ScoreSubmittedEvent fromJson(String json) {
    return ensureInitialized().decodeJson<ScoreSubmittedEvent>(json);
  }
}

mixin ScoreSubmittedEventMappable {
  String toJson() {
    return ScoreSubmittedEventMapper.ensureInitialized()
        .encodeJson<ScoreSubmittedEvent>(this as ScoreSubmittedEvent);
  }

  Map<String, dynamic> toMap() {
    return ScoreSubmittedEventMapper.ensureInitialized()
        .encodeMap<ScoreSubmittedEvent>(this as ScoreSubmittedEvent);
  }

  ScoreSubmittedEventCopyWith<
    ScoreSubmittedEvent,
    ScoreSubmittedEvent,
    ScoreSubmittedEvent
  >
  get copyWith =>
      _ScoreSubmittedEventCopyWithImpl<
        ScoreSubmittedEvent,
        ScoreSubmittedEvent
      >(this as ScoreSubmittedEvent, $identity, $identity);
  @override
  String toString() {
    return ScoreSubmittedEventMapper.ensureInitialized().stringifyValue(
      this as ScoreSubmittedEvent,
    );
  }

  @override
  bool operator ==(Object other) {
    return ScoreSubmittedEventMapper.ensureInitialized().equalsValue(
      this as ScoreSubmittedEvent,
      other,
    );
  }

  @override
  int get hashCode {
    return ScoreSubmittedEventMapper.ensureInitialized().hashValue(
      this as ScoreSubmittedEvent,
    );
  }
}

extension ScoreSubmittedEventValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ScoreSubmittedEvent, $Out> {
  ScoreSubmittedEventCopyWith<$R, ScoreSubmittedEvent, $Out>
  get $asScoreSubmittedEvent => $base.as(
    (v, t, t2) => _ScoreSubmittedEventCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ScoreSubmittedEventCopyWith<
  $R,
  $In extends ScoreSubmittedEvent,
  $Out
>
    implements GameServiceEventCopyWith<$R, $In, $Out> {
  @override
  $R call({String? leaderboardId, int? score, DateTime? timestamp});
  ScoreSubmittedEventCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ScoreSubmittedEventCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ScoreSubmittedEvent, $Out>
    implements ScoreSubmittedEventCopyWith<$R, ScoreSubmittedEvent, $Out> {
  _ScoreSubmittedEventCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ScoreSubmittedEvent> $mapper =
      ScoreSubmittedEventMapper.ensureInitialized();
  @override
  $R call({String? leaderboardId, int? score, DateTime? timestamp}) => $apply(
    FieldCopyWithData({
      if (leaderboardId != null) #leaderboardId: leaderboardId,
      if (score != null) #score: score,
      if (timestamp != null) #timestamp: timestamp,
    }),
  );
  @override
  ScoreSubmittedEvent $make(CopyWithData data) => ScoreSubmittedEvent(
    leaderboardId: data.get(#leaderboardId, or: $value.leaderboardId),
    score: data.get(#score, or: $value.score),
    timestamp: data.get(#timestamp, or: $value.timestamp),
  );

  @override
  ScoreSubmittedEventCopyWith<$R2, ScoreSubmittedEvent, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ScoreSubmittedEventCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class StatUpdatedEventMapper extends SubClassMapperBase<StatUpdatedEvent> {
  StatUpdatedEventMapper._();

  static StatUpdatedEventMapper? _instance;
  static StatUpdatedEventMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = StatUpdatedEventMapper._());
      GameServiceEventMapper.ensureInitialized().addSubMapper(_instance!);
      StatMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'StatUpdatedEvent';

  static Stat _$stat(StatUpdatedEvent v) => v.stat;
  static const Field<StatUpdatedEvent, Stat> _f$stat = Field('stat', _$stat);
  static DateTime _$timestamp(StatUpdatedEvent v) => v.timestamp;
  static const Field<StatUpdatedEvent, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );

  @override
  final MappableFields<StatUpdatedEvent> fields = const {
    #stat: _f$stat,
    #timestamp: _f$timestamp,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'statUpdated';
  @override
  late final ClassMapperBase superMapper =
      GameServiceEventMapper.ensureInitialized();

  static StatUpdatedEvent _instantiate(DecodingData data) {
    return StatUpdatedEvent(
      stat: data.dec(_f$stat),
      timestamp: data.dec(_f$timestamp),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static StatUpdatedEvent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<StatUpdatedEvent>(map);
  }

  static StatUpdatedEvent fromJson(String json) {
    return ensureInitialized().decodeJson<StatUpdatedEvent>(json);
  }
}

mixin StatUpdatedEventMappable {
  String toJson() {
    return StatUpdatedEventMapper.ensureInitialized()
        .encodeJson<StatUpdatedEvent>(this as StatUpdatedEvent);
  }

  Map<String, dynamic> toMap() {
    return StatUpdatedEventMapper.ensureInitialized()
        .encodeMap<StatUpdatedEvent>(this as StatUpdatedEvent);
  }

  StatUpdatedEventCopyWith<StatUpdatedEvent, StatUpdatedEvent, StatUpdatedEvent>
  get copyWith =>
      _StatUpdatedEventCopyWithImpl<StatUpdatedEvent, StatUpdatedEvent>(
        this as StatUpdatedEvent,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return StatUpdatedEventMapper.ensureInitialized().stringifyValue(
      this as StatUpdatedEvent,
    );
  }

  @override
  bool operator ==(Object other) {
    return StatUpdatedEventMapper.ensureInitialized().equalsValue(
      this as StatUpdatedEvent,
      other,
    );
  }

  @override
  int get hashCode {
    return StatUpdatedEventMapper.ensureInitialized().hashValue(
      this as StatUpdatedEvent,
    );
  }
}

extension StatUpdatedEventValueCopy<$R, $Out>
    on ObjectCopyWith<$R, StatUpdatedEvent, $Out> {
  StatUpdatedEventCopyWith<$R, StatUpdatedEvent, $Out>
  get $asStatUpdatedEvent =>
      $base.as((v, t, t2) => _StatUpdatedEventCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class StatUpdatedEventCopyWith<$R, $In extends StatUpdatedEvent, $Out>
    implements GameServiceEventCopyWith<$R, $In, $Out> {
  StatCopyWith<$R, Stat, Stat> get stat;
  @override
  $R call({Stat? stat, DateTime? timestamp});
  StatUpdatedEventCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _StatUpdatedEventCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, StatUpdatedEvent, $Out>
    implements StatUpdatedEventCopyWith<$R, StatUpdatedEvent, $Out> {
  _StatUpdatedEventCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<StatUpdatedEvent> $mapper =
      StatUpdatedEventMapper.ensureInitialized();
  @override
  StatCopyWith<$R, Stat, Stat> get stat =>
      $value.stat.copyWith.$chain((v) => call(stat: v));
  @override
  $R call({Stat? stat, DateTime? timestamp}) => $apply(
    FieldCopyWithData({
      if (stat != null) #stat: stat,
      if (timestamp != null) #timestamp: timestamp,
    }),
  );
  @override
  StatUpdatedEvent $make(CopyWithData data) => StatUpdatedEvent(
    stat: data.get(#stat, or: $value.stat),
    timestamp: data.get(#timestamp, or: $value.timestamp),
  );

  @override
  StatUpdatedEventCopyWith<$R2, StatUpdatedEvent, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _StatUpdatedEventCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PresenceChangedEventMapper
    extends SubClassMapperBase<PresenceChangedEvent> {
  PresenceChangedEventMapper._();

  static PresenceChangedEventMapper? _instance;
  static PresenceChangedEventMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PresenceChangedEventMapper._());
      GameServiceEventMapper.ensureInitialized().addSubMapper(_instance!);
      RichPresenceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PresenceChangedEvent';

  static RichPresence? _$presence(PresenceChangedEvent v) => v.presence;
  static const Field<PresenceChangedEvent, RichPresence> _f$presence = Field(
    'presence',
    _$presence,
    opt: true,
  );
  static DateTime _$timestamp(PresenceChangedEvent v) => v.timestamp;
  static const Field<PresenceChangedEvent, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );

  @override
  final MappableFields<PresenceChangedEvent> fields = const {
    #presence: _f$presence,
    #timestamp: _f$timestamp,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'presenceChanged';
  @override
  late final ClassMapperBase superMapper =
      GameServiceEventMapper.ensureInitialized();

  static PresenceChangedEvent _instantiate(DecodingData data) {
    return PresenceChangedEvent(
      presence: data.dec(_f$presence),
      timestamp: data.dec(_f$timestamp),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PresenceChangedEvent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PresenceChangedEvent>(map);
  }

  static PresenceChangedEvent fromJson(String json) {
    return ensureInitialized().decodeJson<PresenceChangedEvent>(json);
  }
}

mixin PresenceChangedEventMappable {
  String toJson() {
    return PresenceChangedEventMapper.ensureInitialized()
        .encodeJson<PresenceChangedEvent>(this as PresenceChangedEvent);
  }

  Map<String, dynamic> toMap() {
    return PresenceChangedEventMapper.ensureInitialized()
        .encodeMap<PresenceChangedEvent>(this as PresenceChangedEvent);
  }

  PresenceChangedEventCopyWith<
    PresenceChangedEvent,
    PresenceChangedEvent,
    PresenceChangedEvent
  >
  get copyWith =>
      _PresenceChangedEventCopyWithImpl<
        PresenceChangedEvent,
        PresenceChangedEvent
      >(this as PresenceChangedEvent, $identity, $identity);
  @override
  String toString() {
    return PresenceChangedEventMapper.ensureInitialized().stringifyValue(
      this as PresenceChangedEvent,
    );
  }

  @override
  bool operator ==(Object other) {
    return PresenceChangedEventMapper.ensureInitialized().equalsValue(
      this as PresenceChangedEvent,
      other,
    );
  }

  @override
  int get hashCode {
    return PresenceChangedEventMapper.ensureInitialized().hashValue(
      this as PresenceChangedEvent,
    );
  }
}

extension PresenceChangedEventValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PresenceChangedEvent, $Out> {
  PresenceChangedEventCopyWith<$R, PresenceChangedEvent, $Out>
  get $asPresenceChangedEvent => $base.as(
    (v, t, t2) => _PresenceChangedEventCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PresenceChangedEventCopyWith<
  $R,
  $In extends PresenceChangedEvent,
  $Out
>
    implements GameServiceEventCopyWith<$R, $In, $Out> {
  RichPresenceCopyWith<$R, RichPresence, RichPresence>? get presence;
  @override
  $R call({RichPresence? presence, DateTime? timestamp});
  PresenceChangedEventCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PresenceChangedEventCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PresenceChangedEvent, $Out>
    implements PresenceChangedEventCopyWith<$R, PresenceChangedEvent, $Out> {
  _PresenceChangedEventCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PresenceChangedEvent> $mapper =
      PresenceChangedEventMapper.ensureInitialized();
  @override
  RichPresenceCopyWith<$R, RichPresence, RichPresence>? get presence =>
      $value.presence?.copyWith.$chain((v) => call(presence: v));
  @override
  $R call({Object? presence = $none, DateTime? timestamp}) => $apply(
    FieldCopyWithData({
      if (presence != $none) #presence: presence,
      if (timestamp != null) #timestamp: timestamp,
    }),
  );
  @override
  PresenceChangedEvent $make(CopyWithData data) => PresenceChangedEvent(
    presence: data.get(#presence, or: $value.presence),
    timestamp: data.get(#timestamp, or: $value.timestamp),
  );

  @override
  PresenceChangedEventCopyWith<$R2, PresenceChangedEvent, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PresenceChangedEventCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

