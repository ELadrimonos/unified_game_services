// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'achievement.dart';

class AchievementMapper extends ClassMapperBase<Achievement> {
  AchievementMapper._();

  static AchievementMapper? _instance;
  static AchievementMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AchievementMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Achievement';

  static String _$id(Achievement v) => v.id;
  static const Field<Achievement, String> _f$id = Field('id', _$id);
  static String _$title(Achievement v) => v.title;
  static const Field<Achievement, String> _f$title = Field('title', _$title);
  static String? _$description(Achievement v) => v.description;
  static const Field<Achievement, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static bool _$isUnlocked(Achievement v) => v.isUnlocked;
  static const Field<Achievement, bool> _f$isUnlocked = Field(
    'isUnlocked',
    _$isUnlocked,
    opt: true,
    def: false,
  );
  static DateTime? _$unlockedAt(Achievement v) => v.unlockedAt;
  static const Field<Achievement, DateTime> _f$unlockedAt = Field(
    'unlockedAt',
    _$unlockedAt,
    opt: true,
  );
  static bool? _$isHidden(Achievement v) => v.isHidden;
  static const Field<Achievement, bool> _f$isHidden = Field(
    'isHidden',
    _$isHidden,
    opt: true,
  );
  static String? _$iconUrl(Achievement v) => v.iconUrl;
  static const Field<Achievement, String> _f$iconUrl = Field(
    'iconUrl',
    _$iconUrl,
    opt: true,
  );
  static int _$currentSteps(Achievement v) => v.currentSteps;
  static const Field<Achievement, int> _f$currentSteps = Field(
    'currentSteps',
    _$currentSteps,
    opt: true,
    def: 0,
  );
  static int _$totalSteps(Achievement v) => v.totalSteps;
  static const Field<Achievement, int> _f$totalSteps = Field(
    'totalSteps',
    _$totalSteps,
    opt: true,
    def: 0,
  );

  @override
  final MappableFields<Achievement> fields = const {
    #id: _f$id,
    #title: _f$title,
    #description: _f$description,
    #isUnlocked: _f$isUnlocked,
    #unlockedAt: _f$unlockedAt,
    #isHidden: _f$isHidden,
    #iconUrl: _f$iconUrl,
    #currentSteps: _f$currentSteps,
    #totalSteps: _f$totalSteps,
  };

  static Achievement _instantiate(DecodingData data) {
    return Achievement(
      id: data.dec(_f$id),
      title: data.dec(_f$title),
      description: data.dec(_f$description),
      isUnlocked: data.dec(_f$isUnlocked),
      unlockedAt: data.dec(_f$unlockedAt),
      isHidden: data.dec(_f$isHidden),
      iconUrl: data.dec(_f$iconUrl),
      currentSteps: data.dec(_f$currentSteps),
      totalSteps: data.dec(_f$totalSteps),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Achievement fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Achievement>(map);
  }

  static Achievement fromJson(String json) {
    return ensureInitialized().decodeJson<Achievement>(json);
  }
}

mixin AchievementMappable {
  String toJson() {
    return AchievementMapper.ensureInitialized().encodeJson<Achievement>(
      this as Achievement,
    );
  }

  Map<String, dynamic> toMap() {
    return AchievementMapper.ensureInitialized().encodeMap<Achievement>(
      this as Achievement,
    );
  }

  AchievementCopyWith<Achievement, Achievement, Achievement> get copyWith =>
      _AchievementCopyWithImpl<Achievement, Achievement>(
        this as Achievement,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AchievementMapper.ensureInitialized().stringifyValue(
      this as Achievement,
    );
  }

  @override
  bool operator ==(Object other) {
    return AchievementMapper.ensureInitialized().equalsValue(
      this as Achievement,
      other,
    );
  }

  @override
  int get hashCode {
    return AchievementMapper.ensureInitialized().hashValue(this as Achievement);
  }
}

extension AchievementValueCopy<$R, $Out>
    on ObjectCopyWith<$R, Achievement, $Out> {
  AchievementCopyWith<$R, Achievement, $Out> get $asAchievement =>
      $base.as((v, t, t2) => _AchievementCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AchievementCopyWith<$R, $In extends Achievement, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? title,
    String? description,
    bool? isUnlocked,
    DateTime? unlockedAt,
    bool? isHidden,
    String? iconUrl,
    int? currentSteps,
    int? totalSteps,
  });
  AchievementCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AchievementCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Achievement, $Out>
    implements AchievementCopyWith<$R, Achievement, $Out> {
  _AchievementCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Achievement> $mapper =
      AchievementMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? title,
    Object? description = $none,
    bool? isUnlocked,
    Object? unlockedAt = $none,
    Object? isHidden = $none,
    Object? iconUrl = $none,
    int? currentSteps,
    int? totalSteps,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (title != null) #title: title,
      if (description != $none) #description: description,
      if (isUnlocked != null) #isUnlocked: isUnlocked,
      if (unlockedAt != $none) #unlockedAt: unlockedAt,
      if (isHidden != $none) #isHidden: isHidden,
      if (iconUrl != $none) #iconUrl: iconUrl,
      if (currentSteps != null) #currentSteps: currentSteps,
      if (totalSteps != null) #totalSteps: totalSteps,
    }),
  );
  @override
  Achievement $make(CopyWithData data) => Achievement(
    id: data.get(#id, or: $value.id),
    title: data.get(#title, or: $value.title),
    description: data.get(#description, or: $value.description),
    isUnlocked: data.get(#isUnlocked, or: $value.isUnlocked),
    unlockedAt: data.get(#unlockedAt, or: $value.unlockedAt),
    isHidden: data.get(#isHidden, or: $value.isHidden),
    iconUrl: data.get(#iconUrl, or: $value.iconUrl),
    currentSteps: data.get(#currentSteps, or: $value.currentSteps),
    totalSteps: data.get(#totalSteps, or: $value.totalSteps),
  );

  @override
  AchievementCopyWith<$R2, Achievement, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AchievementCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

