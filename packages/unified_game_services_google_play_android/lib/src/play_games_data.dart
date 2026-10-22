// Reflective JNI access to the Play Games read-path payloads.
//
// The committed bindings generate `AnnotatedData`, the data buffers,
// `Achievement` and `LeaderboardScore` as opaque types without methods, and
// regenerating them needs an Android SDK. These helpers call the few getters
// the provider reads by name and JNI signature instead. The class and method
// ids are top-level finals, so they are resolved lazily, on Android only.

import 'package:jni/jni.dart';

import 'playgames_bindings.dart' show Player, Player$$Methods;

final _annotatedData = JClass.forName(
  'com/google/android/gms/games/AnnotatedData',
);
final _annotatedGet = _annotatedData.instanceMethodId(
  'get',
  '()Ljava/lang/Object;',
);

final _dataBuffer = JClass.forName(
  'com/google/android/gms/common/data/DataBuffer',
);
final _bufferCount = _dataBuffer.instanceMethodId('getCount', '()I');
final _bufferGet = _dataBuffer.instanceMethodId('get', '(I)Ljava/lang/Object;');
final _bufferRelease = _dataBuffer.instanceMethodId('release', '()V');

final _achievement = JClass.forName(
  'com/google/android/gms/games/achievement/Achievement',
);
final _achievementId = _achievement.instanceMethodId(
  'getAchievementId',
  '()Ljava/lang/String;',
);
final _achievementName = _achievement.instanceMethodId(
  'getName',
  '()Ljava/lang/String;',
);
final _achievementDescription = _achievement.instanceMethodId(
  'getDescription',
  '()Ljava/lang/String;',
);
final _achievementState = _achievement.instanceMethodId('getState', '()I');
final _achievementType = _achievement.instanceMethodId('getType', '()I');
final _achievementCurrentSteps = _achievement.instanceMethodId(
  'getCurrentSteps',
  '()I',
);
final _achievementTotalSteps = _achievement.instanceMethodId(
  'getTotalSteps',
  '()I',
);
final _achievementUpdatedAt = _achievement.instanceMethodId(
  'getLastUpdatedTimestamp',
  '()J',
);

final _score = JClass.forName(
  'com/google/android/gms/games/leaderboard/LeaderboardScore',
);
final _scoreRank = _score.instanceMethodId('getRank', '()J');
final _scoreRaw = _score.instanceMethodId('getRawScore', '()J');
final _scoreDisplay = _score.instanceMethodId(
  'getDisplayScore',
  '()Ljava/lang/String;',
);
final _scoreHolderName = _score.instanceMethodId(
  'getScoreHolderDisplayName',
  '()Ljava/lang/String;',
);
final _scoreHolder = _score.instanceMethodId(
  'getScoreHolder',
  '()Lcom/google/android/gms/games/Player;',
);
final _scoreTimestamp = _score.instanceMethodId('getTimestampMillis', '()J');

/// `Achievement.STATE_UNLOCKED`.
const achievementStateUnlocked = 0;

/// `Achievement.STATE_HIDDEN`.
const achievementStateHidden = 2;

/// `Achievement.TYPE_INCREMENTAL`.
const achievementTypeIncremental = 1;

/// One `com.google.android.gms.games.achievement.Achievement`, copied to Dart.
typedef AchievementData = ({
  String id,
  String name,
  String? description,
  int state,
  int currentSteps,
  int totalSteps,
  int updatedAtMillis,
});

/// One `com.google.android.gms.games.leaderboard.LeaderboardScore`, copied to
/// Dart.
typedef ScoreData = ({
  int rank,
  int rawScore,
  String? displayScore,
  String? holderId,
  String holderName,
  int timestampMillis,
});

/// Returns `AnnotatedData.get()` of [annotated] and releases [annotated].
JObject? unwrapAnnotated(JObject annotated) {
  try {
    return _annotatedGet.callNullable(annotated, JObject.type, []);
  } finally {
    annotated.release();
  }
}

/// Maps every element of the `DataBuffer` [buffer] with [read], then releases
/// the buffer.
///
/// Elements are backed by the buffer, so [read] must copy what it needs.
List<T> readBuffer<T>(JObject buffer, T Function(JObject element) read) {
  try {
    final count = _bufferCount.call(buffer, jint.type, []);
    return [
      for (var i = 0; i < count; i++)
        _readElement(
          _bufferGet.call(buffer, JObject.type, [JValueInt(i)]),
          read,
        ),
    ];
  } finally {
    _bufferRelease.call(buffer, jvoid.type, []);
    buffer.release();
  }
}

T _readElement<T>(JObject element, T Function(JObject element) read) {
  try {
    return read(element);
  } finally {
    element.release();
  }
}

/// Copies the fields of an `Achievement` element.
AchievementData readAchievement(JObject a) {
  final incremental =
      _achievementType.call(a, jint.type, []) == achievementTypeIncremental;
  return (
    id: _string(_achievementId, a) ?? '',
    name: _string(_achievementName, a) ?? '',
    description: _string(_achievementDescription, a),
    state: _achievementState.call(a, jint.type, []),
    // getCurrentSteps/getTotalSteps throw for standard achievements.
    currentSteps: incremental
        ? _achievementCurrentSteps.call(a, jint.type, [])
        : 0,
    totalSteps: incremental ? _achievementTotalSteps.call(a, jint.type, []) : 0,
    updatedAtMillis: _achievementUpdatedAt.call(a, jlong.type, []),
  );
}

/// Copies the fields of a `LeaderboardScore` element or object.
ScoreData readScore(JObject s) {
  final holder = _scoreHolder.callNullable(s, Player.type, []);
  String? holderId;
  if (holder != null) {
    try {
      holderId = holder.getPlayerId().toDartString(releaseOriginal: true);
    } finally {
      holder.release();
    }
  }
  return (
    rank: _scoreRank.call(s, jlong.type, []),
    rawScore: _scoreRaw.call(s, jlong.type, []),
    displayScore: _string(_scoreDisplay, s),
    holderId: holderId,
    holderName: _string(_scoreHolderName, s) ?? '',
    timestampMillis: _scoreTimestamp.call(s, jlong.type, []),
  );
}

String? _string(JInstanceMethodId method, JObject object) => method
    .callNullable(object, JString.type, [])
    ?.toDartString(releaseOriginal: true);
