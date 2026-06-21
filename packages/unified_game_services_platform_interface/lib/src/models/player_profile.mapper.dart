// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'player_profile.dart';

class PlayerProfileMapper extends ClassMapperBase<PlayerProfile> {
  PlayerProfileMapper._();

  static PlayerProfileMapper? _instance;
  static PlayerProfileMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PlayerProfileMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PlayerProfile';

  static String _$id(PlayerProfile v) => v.id;
  static const Field<PlayerProfile, String> _f$id = Field('id', _$id);
  static String _$displayName(PlayerProfile v) => v.displayName;
  static const Field<PlayerProfile, String> _f$displayName = Field(
    'displayName',
    _$displayName,
  );
  static String? _$avatarUrl(PlayerProfile v) => v.avatarUrl;
  static const Field<PlayerProfile, String> _f$avatarUrl = Field(
    'avatarUrl',
    _$avatarUrl,
    opt: true,
  );
  static bool? _$isOnline(PlayerProfile v) => v.isOnline;
  static const Field<PlayerProfile, bool> _f$isOnline = Field(
    'isOnline',
    _$isOnline,
    opt: true,
  );
  static String? _$title(PlayerProfile v) => v.title;
  static const Field<PlayerProfile, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
  );
  static bool? _$isFriend(PlayerProfile v) => v.isFriend;
  static const Field<PlayerProfile, bool> _f$isFriend = Field(
    'isFriend',
    _$isFriend,
    opt: true,
  );
  static Map<String, dynamic> _$extra(PlayerProfile v) => v.extra;
  static const Field<PlayerProfile, Map<String, dynamic>> _f$extra = Field(
    'extra',
    _$extra,
    opt: true,
    def: const {},
  );

  @override
  final MappableFields<PlayerProfile> fields = const {
    #id: _f$id,
    #displayName: _f$displayName,
    #avatarUrl: _f$avatarUrl,
    #isOnline: _f$isOnline,
    #title: _f$title,
    #isFriend: _f$isFriend,
    #extra: _f$extra,
  };

  static PlayerProfile _instantiate(DecodingData data) {
    return PlayerProfile(
      id: data.dec(_f$id),
      displayName: data.dec(_f$displayName),
      avatarUrl: data.dec(_f$avatarUrl),
      isOnline: data.dec(_f$isOnline),
      title: data.dec(_f$title),
      isFriend: data.dec(_f$isFriend),
      extra: data.dec(_f$extra),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PlayerProfile fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PlayerProfile>(map);
  }

  static PlayerProfile fromJson(String json) {
    return ensureInitialized().decodeJson<PlayerProfile>(json);
  }
}

mixin PlayerProfileMappable {
  String toJson() {
    return PlayerProfileMapper.ensureInitialized().encodeJson<PlayerProfile>(
      this as PlayerProfile,
    );
  }

  Map<String, dynamic> toMap() {
    return PlayerProfileMapper.ensureInitialized().encodeMap<PlayerProfile>(
      this as PlayerProfile,
    );
  }

  PlayerProfileCopyWith<PlayerProfile, PlayerProfile, PlayerProfile>
  get copyWith => _PlayerProfileCopyWithImpl<PlayerProfile, PlayerProfile>(
    this as PlayerProfile,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return PlayerProfileMapper.ensureInitialized().stringifyValue(
      this as PlayerProfile,
    );
  }

  @override
  bool operator ==(Object other) {
    return PlayerProfileMapper.ensureInitialized().equalsValue(
      this as PlayerProfile,
      other,
    );
  }

  @override
  int get hashCode {
    return PlayerProfileMapper.ensureInitialized().hashValue(
      this as PlayerProfile,
    );
  }
}

extension PlayerProfileValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PlayerProfile, $Out> {
  PlayerProfileCopyWith<$R, PlayerProfile, $Out> get $asPlayerProfile =>
      $base.as((v, t, t2) => _PlayerProfileCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PlayerProfileCopyWith<$R, $In extends PlayerProfile, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, dynamic, ObjectCopyWith<$R, dynamic, dynamic>?>
  get extra;
  $R call({
    String? id,
    String? displayName,
    String? avatarUrl,
    bool? isOnline,
    String? title,
    bool? isFriend,
    Map<String, dynamic>? extra,
  });
  PlayerProfileCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PlayerProfileCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PlayerProfile, $Out>
    implements PlayerProfileCopyWith<$R, PlayerProfile, $Out> {
  _PlayerProfileCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PlayerProfile> $mapper =
      PlayerProfileMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, dynamic, ObjectCopyWith<$R, dynamic, dynamic>?>
  get extra => MapCopyWith(
    $value.extra,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(extra: v),
  );
  @override
  $R call({
    String? id,
    String? displayName,
    Object? avatarUrl = $none,
    Object? isOnline = $none,
    Object? title = $none,
    Object? isFriend = $none,
    Map<String, dynamic>? extra,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (displayName != null) #displayName: displayName,
      if (avatarUrl != $none) #avatarUrl: avatarUrl,
      if (isOnline != $none) #isOnline: isOnline,
      if (title != $none) #title: title,
      if (isFriend != $none) #isFriend: isFriend,
      if (extra != null) #extra: extra,
    }),
  );
  @override
  PlayerProfile $make(CopyWithData data) => PlayerProfile(
    id: data.get(#id, or: $value.id),
    displayName: data.get(#displayName, or: $value.displayName),
    avatarUrl: data.get(#avatarUrl, or: $value.avatarUrl),
    isOnline: data.get(#isOnline, or: $value.isOnline),
    title: data.get(#title, or: $value.title),
    isFriend: data.get(#isFriend, or: $value.isFriend),
    extra: data.get(#extra, or: $value.extra),
  );

  @override
  PlayerProfileCopyWith<$R2, PlayerProfile, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PlayerProfileCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

