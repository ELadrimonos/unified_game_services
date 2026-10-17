import '../internal/equality.dart';
import 'player_profile.dart';

/// Who can find and join a lobby.
///
/// Providers map this onto their own levels (Steam private/friends/public, EOS
/// invite-only/presence/public, PlayFab private/friends/public).
enum LobbyVisibility {
  /// Joinable only by invitation or by its [Lobby.joinToken].
  private,

  /// Visible to, and joinable by, the owner's friends.
  friendsOnly,

  /// Visible in lobby searches.
  public,
}

/// How a [LobbyFilter] compares a lobby data value with [LobbyFilter.value].
enum LobbyFilterOp {
  /// Equal (string comparison).
  equals,

  /// Not equal (string comparison).
  notEquals,

  /// Numerically less than; both sides must parse as numbers.
  lessThan,

  /// Numerically greater than; both sides must parse as numbers.
  greaterThan,
}

/// A condition on a lobby's [Lobby.data] used by `findLobbies`.
class LobbyFilter {
  /// The [Lobby.data] key the condition applies to.
  final String key;

  /// The comparison to apply.
  final LobbyFilterOp op;

  /// The value to compare against; numeric operators parse it as a number.
  final String value;

  const LobbyFilter(this.key, this.op, this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LobbyFilter &&
          other.key == key &&
          other.op == op &&
          other.value == value;

  @override
  int get hashCode => Object.hash(key, op, value);

  @override
  String toString() => 'LobbyFilter($key ${op.name} $value)';
}

/// A player in a [Lobby] and the data they published there.
class LobbyMember {
  /// The player.
  final PlayerProfile player;

  /// Per-member data (e.g. a ready flag or loadout), string to string.
  final Map<String, String> data;

  const LobbyMember({required this.player, this.data = const {}});

  /// Returns a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the current value, so a field cannot be reset to
  /// `null` through this method; build a new instance for that.
  LobbyMember copyWith({PlayerProfile? player, Map<String, String>? data}) =>
      LobbyMember(player: player ?? this.player, data: data ?? this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LobbyMember &&
          other.player == player &&
          mapEquals(other.data, data);

  @override
  int get hashCode => Object.hash(player, mapHash(data));

  @override
  String toString() => 'LobbyMember(player: $player, data: $data)';
}

/// A snapshot of a lobby owned by one provider.
///
/// A lobby never spans providers: a Steam lobby holds Steam players, a PlayFab
/// lobby holds PlayFab players. Operations on an existing lobby are routed by
/// [providerId]. The object is immutable; events and operation results carry
/// fresh snapshots.
class Lobby {
  /// Provider-scoped lobby id.
  final String id;

  /// `providerId` of the provider that owns the lobby.
  final String providerId;

  /// Opaque string that `joinLobby` accepts, safe to put in presence or
  /// invitations: the lobby id on Steam and EOS, the connection string on
  /// PlayFab, the secret on Discord.
  final String joinToken;

  /// [PlayerProfile.id] of the owner.
  final String ownerId;

  /// Current members, owner included.
  final List<LobbyMember> members;

  /// Maximum number of members.
  final int maxMembers;

  /// Who can find and join the lobby.
  final LobbyVisibility visibility;

  /// Lobby data, string to string (the lowest common denominator of providers).
  final Map<String, String> data;

  const Lobby({
    required this.id,
    required this.providerId,
    required this.joinToken,
    required this.ownerId,
    this.members = const [],
    this.maxMembers = 4,
    this.visibility = LobbyVisibility.friendsOnly,
    this.data = const {},
  });

  /// Whether another member can still fit.
  bool get hasRoom => members.length < maxMembers;

  /// Returns a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the current value, so a field cannot be reset to
  /// `null` through this method; build a new instance for that.
  Lobby copyWith({
    String? id,
    String? providerId,
    String? joinToken,
    String? ownerId,
    List<LobbyMember>? members,
    int? maxMembers,
    LobbyVisibility? visibility,
    Map<String, String>? data,
  }) => Lobby(
    id: id ?? this.id,
    providerId: providerId ?? this.providerId,
    joinToken: joinToken ?? this.joinToken,
    ownerId: ownerId ?? this.ownerId,
    members: members ?? this.members,
    maxMembers: maxMembers ?? this.maxMembers,
    visibility: visibility ?? this.visibility,
    data: data ?? this.data,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Lobby &&
          other.id == id &&
          other.providerId == providerId &&
          other.joinToken == joinToken &&
          other.ownerId == ownerId &&
          listEquals(other.members, members) &&
          other.maxMembers == maxMembers &&
          other.visibility == visibility &&
          mapEquals(other.data, data);

  @override
  int get hashCode => Object.hash(
    id,
    providerId,
    joinToken,
    ownerId,
    listHash(members),
    maxMembers,
    visibility,
    mapHash(data),
  );

  @override
  String toString() =>
      'Lobby(id: $id, providerId: $providerId, ownerId: $ownerId, '
      'members: ${members.length}/$maxMembers, visibility: ${visibility.name}, '
      'data: $data)';
}
