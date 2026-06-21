import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:steamworks/steamworks.dart' as sw;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Steam provider backed by the pure-Dart [`steamworks`](https://pub.dev/packages/steamworks)
/// FFI wrapper of the Steamworks SDK.
///
/// ## Runtime requirements (supplied by the integrating app)
/// - The Steamworks redistributable native library next to the executable
///   (`steam_api64.dll` on Windows, `libsteam_api.so` on Linux,
///   `libsteam_api.dylib` on macOS).
/// - A `steam_appid.txt` containing the app id, or pass [appId].
/// - The Steam client running and the user logged in.
///
/// ## Platform support
/// The published `steamworks` ships Windows bindings. Linux/macOS require
/// bindings regenerated with `steamworks_gen` against that platform's
/// `steam_api.json` (see steamworks issue #17). The Dart adapter below is
/// platform-agnostic; only the underlying bindings differ.
///
/// Steam delivers async results through a callback pump; this provider drives
/// it with a periodic [Timer] calling `runFrame`.
class SteamProvider extends UnifiedGameServicesPlatform {
  SteamProvider({this.appId});

  /// Optional Steam application id. If omitted, a `steam_appid.txt` file must
  /// be present.
  final int? appId;

  /// Friend flag `k_EFriendFlagImmediate` — the player's regular friends.
  static const int _friendFlagImmediate = 0x04;

  sw.SteamClient? _client;
  Timer? _pump;
  final StreamController<GameServiceEvent> _events =
      StreamController<GameServiceEvent>.broadcast();

  /// Registers a [SteamProvider] as the active platform implementation.
  static void registerWith({int? appId}) {
    UnifiedGameServicesPlatform.instance = SteamProvider(appId: appId);
  }

  @override
  Set<GameCapability> get capabilities => const {
        GameCapability.achievements,
        GameCapability.leaderboards,
        GameCapability.stats,
        GameCapability.cloudSave,
        GameCapability.friends,
        GameCapability.presence,
      };

  @override
  Stream<GameServiceEvent> get events => _events.stream;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initializes the Steam client and starts the callback pump. Idempotent.
  sw.SteamClient _ensureInit() {
    final existing = _client;
    if (existing != null) return existing;
    try {
      sw.SteamClient.init(appId: appId);
    } catch (e) {
      throw SignInFailedException('Failed to initialize Steam.', e);
    }
    final client = sw.SteamClient.instance;
    _client = client;
    _pump ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => client.runFrame(),
    );
    return client;
  }

  /// Stops the callback pump, shuts the Steam API down and releases the events
  /// stream.
  ///
  /// Calling [sw.SteamApi.shutdown] (`SteamAPI_Shutdown`) is what frees Steam's
  /// internal resources; skipping it makes Steam log teardown warnings such as
  /// "Trying to close low level socket support, but we still have sockets
  /// open!" when the process exits.
  Future<void> dispose() async {
    _pump?.cancel();
    _pump = null;
    if (_client != null) {
      sw.SteamApi.shutdown();
      _client = null;
    }
    await _events.close();
  }

  // ─── Authentication ──────────────────────────────────────────────────────

  @override
  Future<bool> isSignedIn() async => _client != null;

  @override
  Future<PlayerProfile?> signIn() async {
    final client = _ensureInit();
    final steamId = client.steamUser.getSteamId();
    // Warm up the player's stats/achievements so later reads are populated.
    final callId = client.steamUserStats.requestUserStats(steamId);
    await _awaitCall<sw.UserStatsReceived, void>(callId, (_) {});
    final profile = _currentProfile(client);
    _emit(UserSignedInEvent(player: profile, timestamp: DateTime.now()));
    return profile;
  }

  @override
  Future<void> signOut() async {
    // Steam has no programmatic sign-out; the user manages the Steam client.
    throw const PlatformOperationException(
      'Steam does not support programmatic sign-out.',
    );
  }

  @override
  Future<PlayerProfile?> getCurrentPlayer() async {
    final client = _client;
    if (client == null) return null;
    return _currentProfile(client);
  }

  PlayerProfile _currentProfile(sw.SteamClient client) {
    final id = client.steamUser.getSteamId();
    final name = client.steamFriends.getPersonaName().toDartString();
    return PlayerProfile(id: id.toString(), displayName: name, isOnline: true);
  }

  // ─── Achievements ──────────────────────────────────────────────────────────

  @override
  Future<List<Achievement>> getAchievements() async {
    final stats = _ensureInit().steamUserStats;
    final count = stats.getNumAchievements();
    final result = <Achievement>[];
    for (var i = 0; i < count; i++) {
      final id = stats.getAchievementName(i).toDartString();
      result.add(_readAchievement(stats, id));
    }
    return result;
  }

  Achievement _readAchievement(Pointer<sw.ISteamUserStats> stats, String id) {
    return _withUtf8(id, (namePtr) {
      final pAchieved = calloc<Bool>();
      final pTime = calloc<UnsignedInt>();
      try {
        final ok =
            stats.getAchievementAndUnlockTime(namePtr, pAchieved, pTime);
        final unlocked = ok && pAchieved.value;
        final unlockedAt = unlocked && pTime.value > 0
            ? DateTime.fromMillisecondsSinceEpoch(pTime.value * 1000,
                isUtc: true)
            : null;
        return Achievement(
          id: id,
          title: _displayAttr(stats, namePtr, 'name') ?? id,
          description: _displayAttr(stats, namePtr, 'desc'),
          isUnlocked: unlocked,
          unlockedAt: unlockedAt,
          isHidden: _displayAttr(stats, namePtr, 'hidden') == '1',
        );
      } finally {
        calloc.free(pAchieved);
        calloc.free(pTime);
      }
    });
  }

  String? _displayAttr(
    Pointer<sw.ISteamUserStats> stats,
    Pointer<Utf8> namePtr,
    String key,
  ) {
    return _withUtf8(key, (keyPtr) {
      final value =
          stats.getAchievementDisplayAttribute(namePtr, keyPtr).toDartString();
      return value.isEmpty ? null : value;
    });
  }

  @override
  Future<void> unlockAchievement(String achievementId) async {
    final stats = _ensureInit().steamUserStats;
    _withUtf8(achievementId, (namePtr) {
      stats.setAchievement(namePtr);
      return null;
    });
    if (!stats.storeStats()) {
      throw PlatformOperationException(
          'Failed to store achievement "$achievementId".');
    }
    _emit(AchievementUnlockedEvent(
      achievement: _readAchievement(stats, achievementId),
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> incrementAchievement(String achievementId, int steps) async {
    // Steam models incremental achievements with a backing stat, not a direct
    // step API. Drive progress through [setStat]/[incrementStat] on that stat
    // instead; `indicateAchievementProgress` only shows a toast.
    throw CapabilityNotSupportedException(GameCapability.achievements);
  }

  @override
  Future<void> revealAchievement(String achievementId) async {
    // Steam reveals hidden achievements automatically on unlock; no-op.
  }

  // ─── GameJolt-style? No — Steam-specific helpers (not in the unified API) ───
  //
  // Clearing achievements / resetting stats is invaluable when iterating
  // against the Spacewar (appId 480) test app, but it has no portable
  // equivalent across providers, so it lives on the concrete provider.

  /// Clears a single unlocked achievement (Steam `ClearAchievement`). Useful
  /// for re-testing. Reach it via
  /// `UnifiedGameServicesPlatform.getInstance<SteamProvider>()`.
  Future<void> clearAchievement(String achievementId) async {
    final stats = _ensureInit().steamUserStats;
    _withUtf8(achievementId, (namePtr) {
      stats.clearAchievement(namePtr);
      return null;
    });
    if (!stats.storeStats()) {
      throw PlatformOperationException(
          'Failed to clear achievement "$achievementId".');
    }
  }

  /// Resets all stats, and optionally all achievements
  /// ([includeAchievements]). Steam `ResetAllStats`.
  Future<void> resetAllStats({bool includeAchievements = false}) async {
    final stats = _ensureInit().steamUserStats;
    if (!stats.resetAllStats(includeAchievements)) {
      throw const PlatformOperationException('Failed to reset stats.');
    }
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  @override
  Future<Stat?> getStat(String key) async {
    final stats = _ensureInit().steamUserStats;
    return _withUtf8(key, (keyPtr) {
      final pData = calloc<Int>();
      try {
        if (!stats.getStatInt32(keyPtr, pData)) return null;
        return Stat(key: key, value: pData.value);
      } finally {
        calloc.free(pData);
      }
    });
  }

  @override
  Future<void> setStat(String key, num value) async {
    final stats = _ensureInit().steamUserStats;
    _withUtf8(key, (keyPtr) {
      stats.setStatInt32(keyPtr, value.toInt());
      return null;
    });
    if (!stats.storeStats()) {
      throw PlatformOperationException('Failed to store stat "$key".');
    }
    _emit(StatUpdatedEvent(
      stat: Stat(key: key, value: value),
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> incrementStat(String key, {num by = 1}) async {
    final current = await getStat(key);
    await setStat(key, (current?.value ?? 0) + by);
  }

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    final stats = _ensureInit().steamUserStats;
    final handle = await _findLeaderboard(stats, leaderboardId);
    final callId = stats.uploadLeaderboardScore(
      handle,
      sw.ELeaderboardUploadScoreMethod.keepBest,
      score,
      nullptr,
      0,
    );
    await _awaitCall<sw.LeaderboardScoreUploaded, void>(callId, (ptr) {
      if (ptr.ref.success == 0) {
        throw PlatformOperationException(
            'Failed to upload score to "$leaderboardId".');
      }
    });
    _emit(ScoreSubmittedEvent(
      leaderboardId: leaderboardId,
      score: score,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) async {
    final client = _ensureInit();
    final stats = client.steamUserStats;
    final handle = await _findLeaderboard(stats, leaderboardId);
    final request = collection == LeaderboardCollection.friends
        ? sw.ELeaderboardDataRequest.friends
        : sw.ELeaderboardDataRequest.global;
    final callId =
        stats.downloadLeaderboardEntries(handle, request, 1, maxResults);
    final entries = await _awaitCall<sw.LeaderboardScoresDownloaded,
        List<LeaderboardEntry>>(callId, (ptr) {
      final downloaded = ptr.ref;
      return _readEntries(
          client, downloaded.steamLeaderboardEntries, downloaded.entryCount);
    });
    return Leaderboard(
      id: leaderboardId,
      timeScope: timeScope,
      collection: collection,
      entries: entries,
    );
  }

  List<LeaderboardEntry> _readEntries(
    sw.SteamClient client,
    int entriesHandle,
    int count,
  ) {
    final stats = client.steamUserStats;
    final pEntry = calloc<sw.LeaderboardEntry>();
    try {
      final result = <LeaderboardEntry>[];
      for (var i = 0; i < count; i++) {
        if (!stats.getDownloadedLeaderboardEntry(
            entriesHandle, i, pEntry, nullptr, 0)) {
          continue;
        }
        final e = pEntry.ref;
        result.add(LeaderboardEntry(
          rank: e.globalRank,
          score: e.score,
          player: _profileForId(client, e.steamIdUser),
        ));
      }
      return result;
    } finally {
      calloc.free(pEntry);
    }
  }

  Future<int> _findLeaderboard(
    Pointer<sw.ISteamUserStats> stats,
    String name,
  ) {
    final callId = _withUtf8(name, stats.findLeaderboard);
    return _awaitCall<sw.LeaderboardFindResult, int>(callId, (ptr) {
      final found = ptr.ref;
      if (found.leaderboardFound == 0) {
        throw PlatformOperationException('Leaderboard "$name" not found.');
      }
      return found.steamLeaderboard;
    });
  }

  // ─── Cloud save (ISteamRemoteStorage) ───────────────────────────────────────

  @override
  Future<void> saveData(String slot, Uint8List data) async {
    final storage = _ensureInit().steamRemoteStorage;
    _withUtf8(slot, (slotPtr) {
      final buffer = calloc<Uint8>(data.length);
      try {
        buffer.asTypedList(data.length).setAll(0, data);
        if (!storage.fileWrite(slotPtr, buffer.cast<Void>(), data.length)) {
          throw PlatformOperationException('Failed to write save "$slot".');
        }
      } finally {
        calloc.free(buffer);
      }
      return null;
    });
  }

  @override
  Future<CloudSave?> loadData(String slot) async {
    final storage = _ensureInit().steamRemoteStorage;
    return _withUtf8(slot, (slotPtr) {
      if (!storage.fileExists(slotPtr)) return null;
      final size = storage.getFileSize(slotPtr);
      final buffer = calloc<Uint8>(size);
      try {
        final read = storage.fileRead(slotPtr, buffer.cast<Void>(), size);
        final bytes = Uint8List.fromList(buffer.asTypedList(read));
        return CloudSave.fromBytes(
          metadata: CloudSaveMetadata(slot: slot, sizeBytes: read),
          bytes: bytes,
        );
      } finally {
        calloc.free(buffer);
      }
    });
  }

  @override
  Future<List<CloudSaveMetadata>> listSaves() async {
    final storage = _ensureInit().steamRemoteStorage;
    final count = storage.getFileCount();
    final result = <CloudSaveMetadata>[];
    final pSize = calloc<Int>();
    try {
      for (var i = 0; i < count; i++) {
        final name = storage.getFileNameAndSize(i, pSize).toDartString();
        result.add(CloudSaveMetadata(slot: name, sizeBytes: pSize.value));
      }
    } finally {
      calloc.free(pSize);
    }
    return result;
  }

  @override
  Future<void> deleteSave(String slot) async {
    final storage = _ensureInit().steamRemoteStorage;
    _withUtf8(slot, (slotPtr) {
      if (!storage.fileDelete(slotPtr)) {
        throw PlatformOperationException('Failed to delete save "$slot".');
      }
      return null;
    });
  }

  // ─── Rich presence ───────────────────────────────────────────────────────

  @override
  Future<void> setPresence(RichPresence presence) async {
    final friends = _ensureInit().steamFriends;
    _withUtf8('status', (keyPtr) {
      _withUtf8(presence.state, (valuePtr) {
        friends.setRichPresence(keyPtr, valuePtr);
        return null;
      });
      return null;
    });
    _emit(PresenceChangedEvent(presence: presence, timestamp: DateTime.now()));
  }

  @override
  Future<void> clearPresence() async {
    _ensureInit().steamFriends.clearRichPresence();
    _emit(PresenceChangedEvent(timestamp: DateTime.now()));
  }

  // ─── Friends ─────────────────────────────────────────────────────────────

  @override
  Future<List<PlayerProfile>> getFriends() async {
    final client = _ensureInit();
    final friends = client.steamFriends;
    final count = friends.getFriendCount(_friendFlagImmediate);
    final result = <PlayerProfile>[];
    for (var i = 0; i < count; i++) {
      final id = friends.getFriendByIndex(i, _friendFlagImmediate);
      result.add(_profileForId(client, id, isFriend: true));
    }
    return result;
  }

  PlayerProfile _profileForId(
    sw.SteamClient client,
    int steamId, {
    bool? isFriend,
  }) {
    final friends = client.steamFriends;
    final name = friends.getFriendPersonaName(steamId).toDartString();
    final online =
        friends.getFriendPersonaState(steamId) != sw.EPersonaState.offline;
    return PlayerProfile(
      id: steamId.toString(),
      displayName: name.isEmpty ? steamId.toString() : name,
      isOnline: online,
      isFriend: isFriend,
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Allocates a NUL-terminated UTF-8 copy of [value], passes it to [body],
  /// then frees it. The pointer must not escape [body].
  R _withUtf8<R>(String value, R Function(Pointer<Utf8>) body) {
    final ptr = value.toNativeUtf8();
    try {
      return body(ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  /// Bridges a Steam async call to a [Future], mapping the result struct with
  /// [onOk]. Completes with an error if Steam reports the call failed.
  Future<R> _awaitCall<T extends NativeType, R>(
    int callId,
    R Function(Pointer<T>) onOk,
  ) {
    final completer = Completer<R>();
    _ensureInit().registerCallResult<T>(
      asyncCallId: callId,
      cb: (Pointer<T> data, bool hasFailed) {
        if (completer.isCompleted) return;
        if (hasFailed) {
          completer.completeError(
              const PlatformOperationException('Steam async call failed.'));
          return;
        }
        try {
          completer.complete(onOk(data));
        } catch (e) {
          completer.completeError(e);
        }
      },
    );
    return completer.future;
  }

  void _emit(GameServiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
