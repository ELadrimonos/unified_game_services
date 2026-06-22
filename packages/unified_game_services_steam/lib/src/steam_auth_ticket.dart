import 'dart:typed_data';

/// A Steam **Web API** auth ticket produced by
/// `SteamProvider.getWebApiAuthTicket`.
///
/// Provider-specific extra — **not** part of the unified
/// `UnifiedGameServicesPlatform` contract.
///
/// Flow for linking a Steam account to your own backend account:
/// 1. Client calls `getWebApiAuthTicket()` and gets a [SteamAuthTicket].
/// 2. Client sends [hex] to your server.
/// 3. Server calls the Steam Web API
///    `ISteamUserAuth/AuthenticateUserTicket` (with your publisher Web API
///    key + app id). Steam returns the verified `steamid` (steamID64).
/// 4. Server stores that verified steamID64 on the user row — the link is
///    now trusted (the client cannot spoof it).
class SteamAuthTicket {
  const SteamAuthTicket({required this.handle, required this.bytes});

  /// Steam ticket handle (`HAuthTicket`). Pass to
  /// `SteamProvider.cancelAuthTicket` to release it when done.
  final int handle;

  /// Raw ticket bytes (`cubTicket` long).
  final Uint8List bytes;

  /// Lowercase hex encoding of [bytes] — the value to send to your backend
  /// as the `ticket` parameter of `AuthenticateUserTicket`.
  String get hex {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  @override
  String toString() => 'SteamAuthTicket(handle: $handle, ${bytes.length} bytes)';
}
