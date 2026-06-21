// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'rich_presence.dart';

class RichPresenceMapper extends ClassMapperBase<RichPresence> {
  RichPresenceMapper._();

  static RichPresenceMapper? _instance;
  static RichPresenceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RichPresenceMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'RichPresence';

  static String _$state(RichPresence v) => v.state;
  static const Field<RichPresence, String> _f$state = Field('state', _$state);
  static String? _$details(RichPresence v) => v.details;
  static const Field<RichPresence, String> _f$details = Field(
    'details',
    _$details,
    opt: true,
  );
  static DateTime? _$startedAt(RichPresence v) => v.startedAt;
  static const Field<RichPresence, DateTime> _f$startedAt = Field(
    'startedAt',
    _$startedAt,
    opt: true,
  );
  static int? _$partySize(RichPresence v) => v.partySize;
  static const Field<RichPresence, int> _f$partySize = Field(
    'partySize',
    _$partySize,
    opt: true,
  );
  static int? _$partyMax(RichPresence v) => v.partyMax;
  static const Field<RichPresence, int> _f$partyMax = Field(
    'partyMax',
    _$partyMax,
    opt: true,
  );

  @override
  final MappableFields<RichPresence> fields = const {
    #state: _f$state,
    #details: _f$details,
    #startedAt: _f$startedAt,
    #partySize: _f$partySize,
    #partyMax: _f$partyMax,
  };

  static RichPresence _instantiate(DecodingData data) {
    return RichPresence(
      state: data.dec(_f$state),
      details: data.dec(_f$details),
      startedAt: data.dec(_f$startedAt),
      partySize: data.dec(_f$partySize),
      partyMax: data.dec(_f$partyMax),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static RichPresence fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RichPresence>(map);
  }

  static RichPresence fromJson(String json) {
    return ensureInitialized().decodeJson<RichPresence>(json);
  }
}

mixin RichPresenceMappable {
  String toJson() {
    return RichPresenceMapper.ensureInitialized().encodeJson<RichPresence>(
      this as RichPresence,
    );
  }

  Map<String, dynamic> toMap() {
    return RichPresenceMapper.ensureInitialized().encodeMap<RichPresence>(
      this as RichPresence,
    );
  }

  RichPresenceCopyWith<RichPresence, RichPresence, RichPresence> get copyWith =>
      _RichPresenceCopyWithImpl<RichPresence, RichPresence>(
        this as RichPresence,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RichPresenceMapper.ensureInitialized().stringifyValue(
      this as RichPresence,
    );
  }

  @override
  bool operator ==(Object other) {
    return RichPresenceMapper.ensureInitialized().equalsValue(
      this as RichPresence,
      other,
    );
  }

  @override
  int get hashCode {
    return RichPresenceMapper.ensureInitialized().hashValue(
      this as RichPresence,
    );
  }
}

extension RichPresenceValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RichPresence, $Out> {
  RichPresenceCopyWith<$R, RichPresence, $Out> get $asRichPresence =>
      $base.as((v, t, t2) => _RichPresenceCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RichPresenceCopyWith<$R, $In extends RichPresence, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? state,
    String? details,
    DateTime? startedAt,
    int? partySize,
    int? partyMax,
  });
  RichPresenceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RichPresenceCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RichPresence, $Out>
    implements RichPresenceCopyWith<$R, RichPresence, $Out> {
  _RichPresenceCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RichPresence> $mapper =
      RichPresenceMapper.ensureInitialized();
  @override
  $R call({
    String? state,
    Object? details = $none,
    Object? startedAt = $none,
    Object? partySize = $none,
    Object? partyMax = $none,
  }) => $apply(
    FieldCopyWithData({
      if (state != null) #state: state,
      if (details != $none) #details: details,
      if (startedAt != $none) #startedAt: startedAt,
      if (partySize != $none) #partySize: partySize,
      if (partyMax != $none) #partyMax: partyMax,
    }),
  );
  @override
  RichPresence $make(CopyWithData data) => RichPresence(
    state: data.get(#state, or: $value.state),
    details: data.get(#details, or: $value.details),
    startedAt: data.get(#startedAt, or: $value.startedAt),
    partySize: data.get(#partySize, or: $value.partySize),
    partyMax: data.get(#partyMax, or: $value.partyMax),
  );

  @override
  RichPresenceCopyWith<$R2, RichPresence, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RichPresenceCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

