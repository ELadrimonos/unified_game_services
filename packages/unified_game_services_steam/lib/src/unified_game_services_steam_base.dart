import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:steamworks/steamworks.dart' as sw;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'steam_auth_ticket.dart';
import 'steam_exceptions.dart';

export 'steam_auth_ticket.dart';
export 'steam_exceptions.dart';

/// Runs [unregister] once the current dispatch finishes.
///
/// `Dispatcher.runFrame` iterates its callback/call-result `Set` while invoking
/// our handlers; removing from that set inside a handler throws
/// `ConcurrentModificationError`, so handlers must unregister asynchronously.
@visibleForTesting
void unregisterAfterDispatch(void Function() unregister) =>
    scheduleMicrotask(unregister);

/// Maps an error thrown by `SteamClient.init` to a [GameServiceException].
///
/// A restart request becomes [SteamRestartRequiredException]; any other
/// failure becomes [SignInFailedException] with [error] as its cause.
@visibleForTesting
GameServiceException mapSteamInitError(Object error) => switch (error) {
  sw.SteamRestartAppIfNecessaryError() => SteamRestartRequiredException(
    'Steam is relaunching the app; this process must exit.',
    error,
  ),
  sw.SteamInitializationError(:final message) => SignInFailedException(
    message.isEmpty
        ? 'Failed to initialize Steam.'
        : 'Failed to initialize Steam: $message',
    error,
  ),
  _ => SignInFailedException('Failed to initialize Steam.', error),
};

/// A provider for Steam, backed by the Steamworks SDK through the pure-Dart
/// [`steamworks`](https://pub.dev/packages/steamworks) FFI wrapper.
///
/// Advertises [GameCapability.achievements], [GameCapability.leaderboards],
/// [GameCapability.stats], [GameCapability.cloudSave],
/// [GameCapability.friends] and [GameCapability.presence].
///
/// **Availability.** Desktop only (Windows, macOS, Linux). The constructor
/// throws [UnsupportedError] on Android and iOS. On web the package exports a
/// stub with the same name whose constructor always throws [UnsupportedError].
/// Check [isSupported] before registering the provider.
///
/// **Host requirements.** The host app supplies:
///
/// - The Steamworks redistributable library next to the executable
///   (`steam_api64.dll` on Windows, `libsteam_api.so` on Linux,
///   `libsteam_api.dylib` on macOS).
/// - The app id, either as [appId] or in a `steam_appid.txt` file.
/// - The Steam client, running with the user logged in.
///
/// The published `steamworks` package ships Windows bindings; Linux and macOS
/// need bindings regenerated with `steamworks_gen`.
///
/// **Initialization.** The SDK initializes lazily on the first operation, and
/// [signIn] is the intended first call. If the game was not launched through
/// Steam, initialization throws [SteamRestartRequiredException]; any other
/// initialization failure throws [SignInFailedException]. Async results are
/// delivered through a callback pump that the provider runs every 50
/// milliseconds until [dispose].
///
/// **Gaps.** Steam has no programmatic sign-out, so [signOut] throws. There is
/// no direct incremental achievement API, so [incrementAchievement] throws.
///
/// **Steam-specific extras** that are not part of the unified interface:
/// [clearAchievement], [resetAllStats], [getSteamId64], [getWebApiAuthTicket]
/// and [cancelAuthTicket]. Reach them with
/// `GameServices.provider<SteamProvider>()`.
class SteamProvider extends UnifiedGameServicesPlatform {
  @override
  String get providerId => 'steam';

  /// Whether Steam can run on the current platform.
  ///
  /// `true` on Windows, macOS and Linux, `false` elsewhere.
  static bool get isSupported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Creates a Steam provider.
  ///
  /// The Steamworks SDK is not initialized until the first operation. Throws
  /// [UnsupportedError] when [isSupported] is `false`.
  ///
  /// When [appId] is omitted, Steam reads the app id from `steam_appid.txt`.
  SteamProvider({this.appId}) {
    // Steam is desktop-only. dart:ffi compiles on Android/iOS, but the
    // Steamworks runtime lib does not exist there — fail fast with a clear
    // message instead of a cryptic DynamicLibrary.open error later.
    if (!isSupported) {
      throw UnsupportedError(
        'SteamProvider is desktop-only (Steamworks via dart:ffi) and cannot '
        'run on Android/iOS. Do not register it in a mobile build. See the '
        'package README.',
      );
    }
  }

  /// The Steam application id, or `null` to read it from `steam_appid.txt`.
  final int? appId;

  /// Friend flag `k_EFriendFlagImmediate` — the player's regular friends.
  static const int _friendFlagImmediate = 0x04;

  sw.SteamClient? _client;
  Timer? _pump;
  final StreamController<GameServiceEvent> _events =
      StreamController<GameServiceEvent>.broadcast();

  @override
  Set<GameCapability> get capabilities => const {
    GameCapability.achievements,
    GameCapability.leaderboards,
    GameCapability.stats,
    GameCapability.cloudSave,
    GameCapability.friends,
    GameCapability.presence,
    GameCapability.identityTokens,
    GameCapability.lobbies,
    GameCapability.invitations,
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
      throw mapSteamInitError(e);
    }
    final client = sw.SteamClient.instance;
    _client = client;
    _pump ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => client.runFrame(),
    );
    _registerLobbyCallbacks(client);
    return client;
  }

  /// Stops the callback pump, shuts the Steam API down and releases the events
  /// stream.
  ///
  /// Calling [sw.SteamApi.shutdown] (`SteamAPI_Shutdown`) is what frees Steam's
  /// internal resources; skipping it makes Steam log teardown warnings such as
  /// "Trying to close low level socket support, but we still have sockets
  /// open!" when the process exits.
  @override
  Future<void> dispose() async {
    _pump?.cancel();
    _pump = null;
    // Leave explicitly so other members see the player go (and ownership
    // migrate) right away instead of after Steam notices the process is gone.
    final client = _client;
    if (client != null) {
      for (final id in _watched.keys) {
        client.steamMatchmaking.leaveLobby(id);
      }
    }
    _watched.clear();
    _lobbyCallbacks.clear();
    if (_client != null) {
      sw.SteamApi.shutdown();
      _client = null;
    }
    await _events.close();
  }

  // ─── Authentication ──────────────────────────────────────────────────────

  /// Whether the Steamworks SDK has been initialized by this provider.
  ///
  /// This reflects initialization through [signIn] or any other operation,
  /// not a query of the Steam client.
  @override
  Future<bool> isSignedIn() async => _client != null;

  /// Initializes the SDK, loads the player's stats and emits a
  /// [UserSignedInEvent].
  ///
  /// The returned profile's `id` is the 64-bit Steam ID as a string. Throws
  /// [SteamRestartRequiredException] when the game was not launched through
  /// Steam, [SignInFailedException] on other initialization failures, and
  /// [NetworkException] when Steam does not deliver the stats within 10
  /// seconds.
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

  /// Always throws [PlatformOperationException]: Steam has no programmatic
  /// sign-out, because the user signs out in the Steam client.
  @override
  Future<void> signOut() async {
    // Steam has no programmatic sign-out; the user manages the Steam client.
    throw const PlatformOperationException(
      'Steam does not support programmatic sign-out.',
    );
  }

  /// Returns the Steam user's profile, or `null` before the SDK is
  /// initialized.
  ///
  /// Unlike most operations, this does not initialize the SDK.
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

  /// Returns the app's achievements with the player's unlock state.
  ///
  /// `title`, `description` and `isHidden` come from the achievement's Steamworks
  /// display attributes. Progress is not reported.
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
        final ok = stats.getAchievementAndUnlockTime(namePtr, pAchieved, pTime);
        final unlocked = ok && pAchieved.value;
        final unlockedAt = unlocked && pTime.value > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                pTime.value * 1000,
                isUtc: true,
              )
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
      final value = stats
          .getAchievementDisplayAttribute(namePtr, keyPtr)
          .toDartString();
      return value.isEmpty ? null : value;
    });
  }

  /// Unlocks the achievement and stores it to Steam, then emits an
  /// [AchievementUnlockedEvent].
  ///
  /// [achievementId] is mapped through `resolveAchievementId` and must be the
  /// API name from Steamworks. Throws [PlatformOperationException] when Steam
  /// rejects `SetAchievement` (an unknown, archived or not-owned achievement,
  /// or user stats that are not loaded yet) or when `StoreStats` fails.
  @override
  Future<void> unlockAchievement(String achievementId) async {
    final id = resolveAchievementId(achievementId);
    final stats = _ensureInit().steamUserStats;
    final set = _withUtf8(id, (namePtr) => stats.setAchievement(namePtr));
    if (!set) {
      // Steam rejects unknown, archived (Achievement Sets) or DLC-gated
      // achievements, and calls made before user stats are received.
      throw PlatformOperationException(
        'Steam rejected unlocking achievement "$id" (unknown, archived, '
        'not owned, or stats not ready).',
      );
    }
    if (!stats.storeStats()) {
      throw PlatformOperationException('Failed to store achievement "$id".');
    }
    _emit(
      AchievementUnlockedEvent(
        achievement: _readAchievement(stats, id),
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Always throws [CapabilityNotSupportedException]: Steam has no step API
  /// for achievements.
  ///
  /// Drive the achievement's backing stat with [setStat] or [incrementStat]
  /// instead.
  @override
  Future<void> incrementAchievement(String achievementId, int steps) async {
    // Steam models incremental achievements with a backing stat, not a direct
    // step API. Drive progress through [setStat]/[incrementStat] on that stat
    // instead; `indicateAchievementProgress` only shows a toast.
    throw CapabilityNotSupportedException(GameCapability.achievements);
  }

  /// Does nothing: Steam reveals a hidden achievement when it is unlocked.
  @override
  Future<void> revealAchievement(String achievementId) async {
    // Steam reveals hidden achievements automatically on unlock; no-op.
  }

  // ─── Steam-specific helpers (not in the unified API) ───────────────────────
  //
  // Clearing achievements / resetting stats is invaluable when iterating
  // against the Spacewar (appId 480) test app, but it has no portable
  // equivalent across providers, so it lives on the concrete provider.

  /// Clears a single unlocked achievement with `ClearAchievement`.
  ///
  /// Steam-specific, not part of the unified interface; intended for
  /// re-testing. [achievementId] is mapped through `resolveAchievementId`.
  /// Throws [PlatformOperationException] when `StoreStats` fails.
  Future<void> clearAchievement(String achievementId) async {
    final id = resolveAchievementId(achievementId);
    final stats = _ensureInit().steamUserStats;
    _withUtf8(id, (namePtr) {
      stats.clearAchievement(namePtr);
      return null;
    });
    if (!stats.storeStats()) {
      throw PlatformOperationException(
        'Failed to clear achievement "$achievementId".',
      );
    }
  }

  /// Resets all stats with `ResetAllStats`, and the achievements too when
  /// [includeAchievements] is `true`.
  ///
  /// Steam-specific, not part of the unified interface. Throws
  /// [PlatformOperationException] when Steam reports failure.
  Future<void> resetAllStats({bool includeAchievements = false}) async {
    final stats = _ensureInit().steamUserStats;
    if (!stats.resetAllStats(includeAchievements)) {
      throw const PlatformOperationException('Failed to reset stats.');
    }
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  /// Returns the stat [key] as a 32-bit integer, or `null` when Steam does
  /// not know it as an integer stat.
  ///
  /// Float stats are not supported. [key] is mapped through `resolveStatId`
  /// and must resolve to the stat API name from Steamworks.
  @override
  Future<Stat?> getStat(String key) async {
    final id = resolveStatId(key);
    final stats = _ensureInit().steamUserStats;
    return _withUtf8(id, (keyPtr) {
      final pData = calloc<Int>();
      try {
        if (!stats.getStatInt32(keyPtr, pData)) return null;
        return Stat(key: id, value: pData.value);
      } finally {
        calloc.free(pData);
      }
    });
  }

  /// Sets the integer stat [key] and stores it to Steam, then emits a
  /// [StatUpdatedEvent].
  ///
  /// Steam receives [value] truncated to an integer; the event carries the
  /// original [value]. [key] is mapped through `resolveStatId`; the event
  /// carries the resolved id. Throws [PlatformOperationException] when
  /// `StoreStats` fails.
  @override
  Future<void> setStat(String key, num value) async {
    final id = resolveStatId(key);
    final stats = _ensureInit().steamUserStats;
    _withUtf8(id, (keyPtr) {
      stats.setStatInt32(keyPtr, value.toInt());
      return null;
    });
    if (!stats.storeStats()) {
      throw PlatformOperationException('Failed to store stat "$id".');
    }
    _emit(
      StatUpdatedEvent(
        stat: Stat(key: id, value: value),
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Reads the stat, treating a missing stat as zero, then stores the sum.
  ///
  /// The read-modify-write is not atomic.
  @override
  Future<void> incrementStat(String key, {num by = 1}) async {
    final current = await getStat(key);
    await setStat(key, (current?.value ?? 0) + by);
  }

  // ─── Leaderboards ──────────────────────────────────────────────────────────

  /// Uploads [score] to the leaderboard with the keep-best rule.
  ///
  /// [leaderboardId] is mapped through `resolveLeaderboardId` and must be the
  /// leaderboard name from Steamworks; a lower score than the player's best
  /// does not replace it. The emitted [ScoreSubmittedEvent] carries the
  /// resolved id. Throws [PlatformOperationException] when the leaderboard
  /// cannot be found or the upload fails.
  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    final id = resolveLeaderboardId(leaderboardId);
    final stats = _ensureInit().steamUserStats;
    final handle = await _findLeaderboard(stats, id);
    final callId = stats.uploadLeaderboardScore(
      handle,
      sw.ELeaderboardUploadScoreMethod.keepBest,
      score,
      nullptr,
      0,
    );
    await _awaitCall<sw.LeaderboardScoreUploaded, void>(callId, (ptr) {
      if (ptr.ref.success == 0) {
        throw PlatformOperationException('Failed to upload score to "$id".');
      }
    });
    _emit(
      ScoreSubmittedEvent(
        leaderboardId: id,
        score: score,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Returns up to [maxResults] entries from the start of the leaderboard.
  ///
  /// [collection] selects the global or the friends board. [timeScope] is only
  /// echoed into the returned [Leaderboard]; Steam leaderboards are not
  /// time-scoped.
  @override
  Future<Leaderboard> getLeaderboard(
    String leaderboardId, {
    LeaderboardTimeScope timeScope = LeaderboardTimeScope.allTime,
    LeaderboardCollection collection = LeaderboardCollection.global,
    int maxResults = 25,
  }) async {
    final client = _ensureInit();
    final stats = client.steamUserStats;
    final handle = await _findLeaderboard(
      stats,
      resolveLeaderboardId(leaderboardId),
    );
    final request = collection == LeaderboardCollection.friends
        ? sw.ELeaderboardDataRequest.friends
        : sw.ELeaderboardDataRequest.global;
    final callId = stats.downloadLeaderboardEntries(
      handle,
      request,
      1,
      maxResults,
    );
    final entries =
        await _awaitCall<
          sw.LeaderboardScoresDownloaded,
          List<LeaderboardEntry>
        >(callId, (ptr) {
          final downloaded = ptr.ref;
          return _readEntries(
            client,
            downloaded.steamLeaderboardEntries,
            downloaded.entryCount,
          );
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
          entriesHandle,
          i,
          pEntry,
          nullptr,
          0,
        )) {
          continue;
        }
        final e = pEntry.ref;
        result.add(
          LeaderboardEntry(
            rank: e.globalRank,
            score: e.score,
            player: _profileForId(client, e.steamIdUser),
          ),
        );
      }
      return result;
    } finally {
      calloc.free(pEntry);
    }
  }

  Future<int> _findLeaderboard(Pointer<sw.ISteamUserStats> stats, String name) {
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

  /// Writes [data] to the Steam Cloud file named [slot] with `FileWrite`.
  ///
  /// Throws [PlatformOperationException] when Steam rejects the write, for
  /// example when Steam Cloud is disabled for the app or the user.
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

  /// Reads the Steam Cloud file named [slot], or returns `null` when it does
  /// not exist.
  ///
  /// The returned metadata carries only the slot and the size.
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

  /// Lists every Steam Cloud file of the app, with its name and size.
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

  /// Sets the Steam rich presence `status` key to `presence.state`, then
  /// emits a [PresenceChangedEvent].
  ///
  /// Only the state is sent; details, party size and the start time have no
  /// mapping here.
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

  /// Clears all rich presence keys of the user, then emits a
  /// [PresenceChangedEvent].
  @override
  Future<void> clearPresence() async {
    _ensureInit().steamFriends.clearRichPresence();
    _emit(PresenceChangedEvent(timestamp: DateTime.now()));
  }

  // ─── Friends ─────────────────────────────────────────────────────────────

  /// Returns the player's regular Steam friends (`k_EFriendFlagImmediate`).
  ///
  /// Each profile's `id` is the friend's Steam ID as a string.
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

  // ─── Lobbies (ISteamMatchmaking) ───────────────────────────────────────────
  //
  // Mapping and limits:
  //  * `Lobby.joinToken` and `Lobby.id` are the lobby's 64-bit Steam id as a
  //    decimal string. Members and owner are Steam ids as strings, like
  //    [PlayerProfile.id].
  //  * Steam cannot read a lobby's type back and cannot list a member's data
  //    keys, so the provider stores two reserved entries: `ugs_vis` in lobby
  //    data (visibility) and `ugs_md` in each member's data (a JSON map of all
  //    that member's data). Both are hidden from `Lobby.data` and
  //    `LobbyMember.data`; `lobbyKindDataKey` holds the lobby kind.
  //  * `findLobbies` returns Steam's public lobbies worldwide; friends-only and
  //    private lobbies are not searchable on Steam.
  //  * Steam has no owner-changed callback; the provider compares the owner
  //    after every member or data update.
  //  * Only lobbies this provider created or joined emit events.

  static const String _visibilityKey = 'ugs_vis';
  static const String _memberDataKey = 'ugs_md';

  /// Latest snapshot of every lobby this provider is in, by Steam lobby id.
  final Map<int, Lobby> _watched = {};
  final List<sw.Callback<dynamic>> _lobbyCallbacks = [];

  void _registerLobbyCallbacks(sw.SteamClient client) {
    if (_lobbyCallbacks.isNotEmpty) return;
    _lobbyCallbacks.addAll([
      client.registerCallback<sw.LobbyChatUpdate>(
        cb: (ptr) => _onLobbyChatUpdate(
          client,
          ptr.ref.steamIdLobby,
          ptr.ref.steamIdUserChanged,
          ptr.ref.chatMemberStateChange,
        ),
      ),
      client.registerCallback<sw.LobbyDataUpdate>(
        cb: (ptr) => _onLobbyDataUpdate(client, ptr.ref.steamIdLobby),
      ),
      client.registerCallback<sw.LobbyInvite>(
        cb: (ptr) => _emit(
          InvitationReceivedEvent(
            senderId: ptr.ref.steamIdUser.toString(),
            joinToken: ptr.ref.steamIdLobby.toString(),
            providerId: providerId,
            timestamp: DateTime.now(),
          ),
        ),
      ),
      client.registerCallback<sw.GameLobbyJoinRequested>(
        cb: (ptr) => _emit(
          JoinRequestedEvent(
            joinToken: ptr.ref.steamIdLobby.toString(),
            providerId: providerId,
            timestamp: DateTime.now(),
          ),
        ),
      ),
    ]);
  }

  static sw.ELobbyType _lobbyType(LobbyVisibility v) => switch (v) {
    LobbyVisibility.private => sw.ELobbyType.private,
    LobbyVisibility.friendsOnly => sw.ELobbyType.friendsOnly,
    LobbyVisibility.public => sw.ELobbyType.public,
  };

  int _parseLobbyId(String token) =>
      int.tryParse(token) ??
      (throw ArgumentError.value(token, 'joinToken', 'not a Steam lobby id'));

  void _setLobbyData(sw.SteamClient client, int lobby, String key, String? v) {
    final ok = v == null
        ? _withUtf8(
            key,
            (k) => client.steamMatchmaking.deleteLobbyData(lobby, k),
          )
        : _withUtf8(
            key,
            (k) => _withUtf8(
              v,
              (val) => client.steamMatchmaking.setLobbyData(lobby, k, val),
            ),
          );
    if (!ok) {
      throw PlatformOperationException(
        'Steam refused lobby data "$key" (only the owner can set it; keys '
        'are limited to 255 bytes and values to 8192).',
      );
    }
  }

  Map<String, String> _memberDataOf(
    sw.SteamClient client,
    int lobby,
    int user,
  ) {
    final raw = _withUtf8(
      _memberDataKey,
      (k) => client.steamMatchmaking
          .getLobbyMemberData(lobby, user, k)
          .toDartString(),
    );
    if (raw.isEmpty) return const {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', '$v'));
    } on FormatException {
      return const {};
    }
  }

  /// Applies [changes] (a `null` value removes the key) to the signed-in
  /// player's member data in [lobby].
  void _writeMemberData(
    sw.SteamClient client,
    int lobby,
    Map<String, String?> changes,
  ) {
    final me = client.steamUser.getSteamId();
    final merged = {..._memberDataOf(client, lobby, me)};
    changes.forEach((k, v) => v == null ? merged.remove(k) : merged[k] = v);
    _withUtf8(
      _memberDataKey,
      (k) => _withUtf8(
        jsonEncode(merged),
        (v) => client.steamMatchmaking.setLobbyMemberData(lobby, k, v),
      ),
    );
  }

  /// Reads the lobby [id] as this client currently sees it. With [summary]
  /// (search results) members are not listed.
  Lobby _lobbySnapshot(sw.SteamClient client, int id, {bool summary = false}) {
    final mm = client.steamMatchmaking;
    final data = <String, String>{};
    final keyBuf = calloc<Uint8>(256).cast<Utf8>();
    final valueBuf = calloc<Uint8>(8192).cast<Utf8>();
    try {
      for (var i = 0; i < mm.getLobbyDataCount(id); i++) {
        if (mm.getLobbyDataByIndex(id, i, keyBuf, 256, valueBuf, 8192)) {
          data[keyBuf.toDartString()] = valueBuf.toDartString();
        }
      }
    } finally {
      calloc.free(keyBuf);
      calloc.free(valueBuf);
    }
    final visibilityName = data.remove(_visibilityKey);
    final kindName = data.remove(lobbyKindDataKey);
    final count = mm.getNumLobbyMembers(id);
    return Lobby(
      id: id.toString(),
      providerId: providerId,
      joinToken: id.toString(),
      ownerId: mm.getLobbyOwner(id).toString(),
      members: summary
          ? const []
          : [
              for (var i = 0; i < count; i++)
                () {
                  final user = mm.getLobbyMemberByIndex(id, i);
                  return LobbyMember(
                    player: _profileForId(client, user),
                    data: _memberDataOf(client, id, user),
                  );
                }(),
            ],
      memberCount: summary ? count : null,
      maxMembers: mm.getLobbyMemberLimit(id),
      visibility:
          LobbyVisibility.values.asNameMap()[visibilityName] ??
          (summary ? LobbyVisibility.public : LobbyVisibility.friendsOnly),
      kind: LobbyKind.values.asNameMap()[kindName] ?? LobbyKind.lobby,
      data: data,
    );
  }

  /// Reads a `LobbyCreated_t` by hand.
  ///
  /// The generated struct is `@Packed(8)` (the Windows layout), but Steam packs
  /// callback structs to 4 bytes on Linux and macOS, which moves the 64-bit lobby
  /// id from offset 8 to offset 4. Reading the generated field there returns
  /// garbage, so read the bytes at the right offset for the platform.
  ({int result, int lobbyId}) _readLobbyCreated(Pointer<sw.LobbyCreated> ptr) {
    final idOffset = Platform.isWindows ? 8 : 4;
    final bytes = ptr.cast<Uint8>().asTypedList(idOffset + 8);
    final view = ByteData.sublistView(bytes);
    return (
      result: view.getInt32(0, Endian.little),
      lobbyId: view.getUint64(idOffset, Endian.little),
    );
  }

  Lobby _watch(sw.SteamClient client, int id) {
    final lobby = _lobbySnapshot(client, id);
    _watched[id] = lobby;
    return lobby;
  }

  @override
  Future<Lobby> createLobby({
    int maxMembers = 4,
    LobbyVisibility visibility = LobbyVisibility.friendsOnly,
    LobbyKind kind = LobbyKind.lobby,
    Map<String, String> data = const {},
    Map<String, String> memberData = const {},
  }) async {
    final client = _ensureInit();
    final callId = client.steamMatchmaking.createLobby(
      _lobbyType(visibility),
      maxMembers,
    );
    final id = await _awaitCall<sw.LobbyCreated, int>(callId, (ptr) {
      final created = _readLobbyCreated(ptr);
      if (created.result != sw.EResult.eResultOK.value) {
        throw PlatformOperationException(
          'Steam could not create the lobby: EResult ${created.result}.',
        );
      }
      return created.lobbyId;
    });
    _setLobbyData(client, id, _visibilityKey, visibility.name);
    if (kind != LobbyKind.lobby) {
      _setLobbyData(client, id, lobbyKindDataKey, kind.name);
    }
    data.forEach((k, v) => _setLobbyData(client, id, k, v));
    if (memberData.isNotEmpty) _writeMemberData(client, id, memberData);
    return _watch(client, id);
  }

  @override
  Future<Lobby> joinLobby(
    String joinToken, {
    Map<String, String> memberData = const {},
  }) async {
    final client = _ensureInit();
    final id = _parseLobbyId(joinToken);
    await _awaitCall<sw.LobbyEnter, void>(
      client.steamMatchmaking.joinLobby(id),
      (ptr) {
        final response = ptr.ref.eChatRoomEnterResponse;
        if (response != 1 /* k_EChatRoomEnterResponseSuccess */ ) {
          throw PlatformOperationException(switch (response) {
            2 => 'The lobby does not exist.',
            3 => 'Not allowed to join this lobby.',
            4 => 'The lobby is full.',
            6 || 9 => 'Banned from this lobby.',
            _ => 'Steam could not join the lobby (response $response).',
          }, code: '$response');
        }
      },
    );
    if (memberData.isNotEmpty) _writeMemberData(client, id, memberData);
    return _watch(client, id);
  }

  @override
  Future<void> leaveLobby(String lobbyId) async {
    final client = _ensureInit();
    final id = _parseLobbyId(lobbyId);
    _watched.remove(id);
    client.steamMatchmaking.leaveLobby(id);
  }

  @override
  Future<Lobby?> getLobby(String lobbyId) async {
    final client = _ensureInit();
    final id = _parseLobbyId(lobbyId);
    // Steam only knows lobbies this client is in or just searched; an unknown
    // lobby has no owner.
    if (client.steamMatchmaking.getLobbyOwner(id) == 0) return null;
    return _lobbySnapshot(client, id);
  }

  @override
  Future<List<Lobby>> findLobbies({
    List<LobbyFilter> filters = const [],
    int maxResults = 25,
  }) async {
    final client = _ensureInit();
    final mm = client.steamMatchmaking;
    for (final f in filters) {
      switch (f.op) {
        case LobbyFilterOp.equals || LobbyFilterOp.notEquals:
          _withUtf8(
            f.key,
            (k) => _withUtf8(
              f.value,
              (v) => mm.addRequestLobbyListStringFilter(
                k,
                v,
                f.op == LobbyFilterOp.equals
                    ? sw.ELobbyComparison.equal
                    : sw.ELobbyComparison.notEqual,
              ),
            ),
          );
        case LobbyFilterOp.lessThan || LobbyFilterOp.greaterThan:
          final n =
              int.tryParse(f.value) ??
              (throw ArgumentError.value(
                f.value,
                f.key,
                'numeric comparison needs an integer',
              ));
          _withUtf8(
            f.key,
            (k) => mm.addRequestLobbyListNumericalFilter(
              k,
              n,
              f.op == LobbyFilterOp.lessThan
                  ? sw.ELobbyComparison.lessThan
                  : sw.ELobbyComparison.greaterThan,
            ),
          );
      }
    }
    mm.addRequestLobbyListDistanceFilter(sw.ELobbyDistanceFilter.worldwide);
    mm.addRequestLobbyListResultCountFilter(maxResults);
    final matching = await _awaitCall<sw.LobbyMatchList, int>(
      mm.requestLobbyList(),
      (ptr) => ptr.ref.lobbiesMatching,
    );
    return [
      for (var i = 0; i < matching; i++)
        _lobbySnapshot(client, mm.getLobbyByIndex(i), summary: true),
    ];
  }

  @override
  Future<Lobby> updateLobby(
    String lobbyId, {
    Map<String, String?>? data,
    LobbyVisibility? visibility,
    int? maxMembers,
  }) async {
    final client = _ensureInit();
    final id = _parseLobbyId(lobbyId);
    final mm = client.steamMatchmaking;
    if (mm.getLobbyOwner(id) != client.steamUser.getSteamId()) {
      throw const PlatformOperationException(
        'Only the lobby owner can update it.',
      );
    }
    data?.forEach((k, v) => _setLobbyData(client, id, k, v));
    if (visibility != null) {
      if (!mm.setLobbyType(id, _lobbyType(visibility))) {
        throw const PlatformOperationException('Steam refused the lobby type.');
      }
      _setLobbyData(client, id, _visibilityKey, visibility.name);
    }
    if (maxMembers != null && !mm.setLobbyMemberLimit(id, maxMembers)) {
      throw const PlatformOperationException(
        'Steam refused the member limit (it cannot be below the member count).',
      );
    }
    return _watch(client, id);
  }

  @override
  Future<Lobby> setMemberData(String lobbyId, Map<String, String?> data) async {
    final client = _ensureInit();
    final id = _parseLobbyId(lobbyId);
    _writeMemberData(client, id, data);
    return _watch(client, id);
  }

  @override
  Future<void> sendInvitation(String lobbyId, String userId) async {
    final client = _ensureInit();
    final invitee = int.tryParse(userId);
    if (invitee == null ||
        !client.steamMatchmaking.inviteUserToLobby(
          _parseLobbyId(lobbyId),
          invitee,
        )) {
      throw PlatformOperationException('Steam could not invite "$userId".');
    }
  }

  void _onLobbyChatUpdate(
    sw.SteamClient client,
    int lobbyId,
    int userChanged,
    int stateChange,
  ) {
    final old = _watched[lobbyId];
    if (old == null) return;
    final current = _watch(client, lobbyId);
    final now = DateTime.now();
    final user = userChanged.toString();
    if (stateChange & sw.EChatMemberStateChange.entered.value != 0) {
      final member = current.members.where((m) => m.player.id == user);
      if (member.isNotEmpty) {
        _emit(
          LobbyMemberJoinedEvent(
            lobby: current,
            member: member.first,
            timestamp: now,
          ),
        );
      }
    } else {
      final member = old.members.where((m) => m.player.id == user);
      _emit(
        LobbyMemberLeftEvent(
          lobby: current,
          member: member.isNotEmpty
              ? member.first
              : LobbyMember(player: _profileForId(client, userChanged)),
          timestamp: now,
        ),
      );
    }
    _emitOwnerChange(old, current, now);
  }

  void _onLobbyDataUpdate(sw.SteamClient client, int lobbyId) {
    final old = _watched[lobbyId];
    if (old == null) return;
    final current = _watch(client, lobbyId);
    if (current == old) return;
    final now = DateTime.now();
    _emitOwnerChange(old, current, now);
    if (current.data.toString() != old.data.toString() ||
        current.visibility != old.visibility ||
        current.maxMembers != old.maxMembers ||
        current.members.map((m) => m.data.toString()).join('|') !=
            old.members.map((m) => m.data.toString()).join('|')) {
      _emit(LobbyDataChangedEvent(lobby: current, timestamp: now));
    }
  }

  void _emitOwnerChange(Lobby old, Lobby current, DateTime now) {
    if (old.ownerId != current.ownerId) {
      _emit(
        LobbyOwnerChangedEvent(
          lobby: current,
          previousOwnerId: old.ownerId,
          timestamp: now,
        ),
      );
    }
  }

  // ─── Steam-specific extras (NOT part of the unified interface) ─────────────
  //
  // These members exist only on [SteamProvider] and are absent from
  // [UnifiedGameServicesPlatform]. Reach them via
  // `GameServices.provider<SteamProvider>()`.

  /// Returns the signed-in user's 64-bit Steam ID.
  ///
  /// This is the raw [int] form of the `PlayerProfile.id` returned by [signIn]
  /// and [getCurrentPlayer]. Steam-specific, not part of the unified interface.
  ///
  /// The ID is reported by the client, so it can be spoofed before it reaches a
  /// server. To link an account with server-side trust, use
  /// [getWebApiAuthTicket] and verify the ticket on the backend.
  int getSteamId64() => _ensureInit().steamUser.getSteamId();

  /// Requests a Steam Web API auth ticket for server-side account linking.
  ///
  /// Steam-specific, not part of the unified interface. Completes when Steam
  /// delivers the ticket. Send [SteamAuthTicket.hex] to the backend, which
  /// calls `ISteamUserAuth/AuthenticateUserTicket` to obtain the verified
  /// steamID64; see [SteamAuthTicket] for the flow.
  ///
  /// [identity] is the optional remote-service identity string that Steam
  /// embeds in the ticket. Pass the value the backend expects, or omit it.
  /// Throws [PlatformOperationException] when Steam refuses the request, the
  /// request fails, or no ticket arrives within 10 seconds.
  Future<SteamAuthTicket> getWebApiAuthTicket({String? identity}) {
    final client = _ensureInit();
    final completer = Completer<SteamAuthTicket>();

    int request(Pointer<Utf8> id) =>
        client.steamUser.getAuthTicketForWebApi(id);
    final handle = identity == null
        ? request(nullptr)
        : _withUtf8(identity, request);

    if (handle == 0 /* k_HAuthTicketInvalid */ ) {
      return Future.error(
        const PlatformOperationException(
          'Steam refused the Web API auth ticket request.',
        ),
      );
    }

    late final sw.Callback<sw.GetTicketForWebApiResponse> cb;
    cb = client.registerCallback<sw.GetTicketForWebApiResponse>(
      cb: (ptr) {
        // The callback fires for every outstanding request; match our handle.
        if (ptr.authTicket != handle || completer.isCompleted) return;
        unregisterAfterDispatch(() => client.unregisterCallback(callback: cb));
        if (ptr.result != sw.EResult.eResultOK) {
          completer.completeError(
            PlatformOperationException(
              'Steam Web API auth ticket failed: ${ptr.result}.',
            ),
          );
          return;
        }
        final len = ptr.ticket;
        final arr = ptr.ticketAsArray;
        final bytes = Uint8List(len);
        for (var i = 0; i < len; i++) {
          bytes[i] = arr[i];
        }
        completer.complete(SteamAuthTicket(handle: handle, bytes: bytes));
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        if (!completer.isCompleted) client.unregisterCallback(callback: cb);
        throw const PlatformOperationException(
          'Steam Web API auth ticket timed out.',
        );
      },
    );
  }

  /// Returns a Steam Web API auth ticket as lowercase hex, ready to send to
  /// your backend for `ISteamUserAuth/AuthenticateUserTicket`.
  ///
  /// **Validity window: 2 minutes.** The ticket handle is cancelled
  /// automatically 2 minutes after this call returns so it does not leak, and
  /// Steam rejects a cancelled ticket. Your backend must call
  /// `AuthenticateUserTicket` within that window, so send the token right away
  /// and do not cache it. Use [getWebApiAuthTicket] directly for control over
  /// the handle lifetime or the `identity` string.
  @override
  Future<String?> getIdentityToken() async {
    final ticket = await getWebApiAuthTicket();
    Timer(_identityTicketLifetime, () {
      if (_client != null) cancelAuthTicket(ticket.handle);
    });
    return ticket.hex;
  }

  static const Duration _identityTicketLifetime = Duration(minutes: 2);

  /// Releases the auth ticket with [handle] using `CancelAuthTicket`.
  ///
  /// [handle] is [SteamAuthTicket.handle] from [getWebApiAuthTicket]. Call it
  /// once the backend has consumed the ticket. Steam-specific, not part of the
  /// unified interface.
  void cancelAuthTicket(int handle) =>
      _ensureInit().steamUser.cancelAuthTicket(handle);

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
    final client = _ensureInit();
    final completer = Completer<R>();
    late final sw.CallResult<T> callResult;
    callResult = client.registerCallResult<T>(
      asyncCallId: callId,
      cb: (Pointer<T> data, bool hasFailed) {
        if (completer.isCompleted) return;
        unregisterAfterDispatch(
          () => client.unregisterCallResult(callResult: callResult),
        );
        if (hasFailed) {
          completer.completeError(
            const PlatformOperationException('Steam async call failed.'),
          );
          return;
        }
        try {
          completer.complete(onOk(data));
        } catch (e) {
          completer.completeError(e);
        }
      },
    );
    // Steam may never deliver the result (offline, invalid handle, client
    // gone); without a timeout every caller would hang forever.
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        client.unregisterCallResult(callResult: callResult);
        throw const NetworkException('Steam async call timed out.');
      },
    );
  }

  void _emit(GameServiceEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
