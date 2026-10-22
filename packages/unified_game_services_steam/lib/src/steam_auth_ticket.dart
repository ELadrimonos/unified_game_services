import 'dart:typed_data';

/// A Steam Web API auth ticket returned by `SteamProvider.getWebApiAuthTicket`.
///
/// This is a Steam-specific extra and is **not** part of the unified
/// `UnifiedGameServicesPlatform` contract.
///
/// To link a Steam account to an account on your own backend:
///
/// 1. The client calls `getWebApiAuthTicket` and receives a [SteamAuthTicket].
/// 2. The client sends [hex] to the server.
/// 3. The server calls the Steam Web API
///    `ISteamUserAuth/AuthenticateUserTicket` with the publisher Web API key
///    and the app id. Steam returns the verified steamID64.
/// 4. The server stores that steamID64 on the user. The link can be trusted
///    because the client cannot forge it.
class SteamAuthTicket {
  /// Creates a ticket from its Steam [handle] and raw [bytes].
  const SteamAuthTicket({required this.handle, required this.bytes});

  /// The Steam ticket handle (`HAuthTicket`).
  ///
  /// Pass it to `SteamProvider.cancelAuthTicket` to release the ticket once
  /// the backend has consumed it.
  final int handle;

  /// The raw ticket bytes.
  final Uint8List bytes;

  /// The lowercase hex encoding of [bytes].
  ///
  /// This is the value to send to the backend as the `ticket` parameter of
  /// `AuthenticateUserTicket`.
  String get hex {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  @override
  String toString() =>
      'SteamAuthTicket(handle: $handle, ${bytes.length} bytes)';
}
