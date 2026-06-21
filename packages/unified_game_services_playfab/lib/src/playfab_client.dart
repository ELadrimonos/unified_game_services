import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Thin client for the PlayFab Client API.
///
/// PlayFab is keyed by a public `titleId`; every request goes to
/// `https://{titleId}.playfabapi.com` as a JSON POST. Authenticated calls carry
/// the player's session ticket in the `X-Authorization` header — obtained from a
/// `LoginWith*` call and stored on the client by [setSessionTicket].
///
/// Responses are wrapped in a `{"code": 200, "status": "OK", "data": {...}}`
/// envelope; this client unwraps `data` and throws a [GameServiceException] when
/// the HTTP status or envelope reports an error.
///
/// An [http.Client] can be injected for testing.
class PlayFabClient {
  PlayFabClient({
    required this.titleId,
    http.Client? httpClient,
    String? baseUrl,
  }) : _http = httpClient ?? http.Client(),
       baseUrl = baseUrl ?? 'https://$titleId.playfabapi.com';

  /// The game's public Title ID (from the PlayFab Game Manager).
  final String titleId;

  /// API root, without trailing slash.
  final String baseUrl;

  final http.Client _http;

  String? _sessionTicket;

  /// Whether a session ticket has been stored (i.e. the player is logged in).
  bool get hasSession => _sessionTicket != null;

  /// Stores (or clears, with `null`) the session ticket sent as
  /// `X-Authorization` on authenticated requests.
  void setSessionTicket(String? ticket) => _sessionTicket = ticket;

  /// POSTs [body] to [endpoint] (e.g. `/Client/GetPlayerStatistics`).
  ///
  /// When [authenticated] is `true` the stored session ticket is attached;
  /// calling without a ticket throws [NotSignedInException]. Returns the
  /// unwrapped `data` object.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final ticket = _sessionTicket;
      if (ticket == null) {
        throw const NotSignedInException(
          'PlayFab session ticket missing; call signIn() first.',
        );
      }
      headers['X-Authorization'] = ticket;
    }

    final http.Response res;
    try {
      res = await _http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
    } catch (e) {
      throw NetworkException('PlayFab request failed: $endpoint', e);
    }
    return _unwrap(res, endpoint);
  }

  Map<String, dynamic> _unwrap(http.Response res, String endpoint) {
    final Object? body = res.body.isEmpty ? null : jsonDecode(res.body);
    final map = body is Map ? body.cast<String, dynamic>() : null;

    if (res.statusCode != 200) {
      // PlayFab error envelope: {code, status, error, errorCode, errorMessage}.
      final message =
          map?['errorMessage'] as String? ??
          map?['error'] as String? ??
          'PlayFab $endpoint returned HTTP ${res.statusCode}.';
      throw PlatformOperationException(message);
    }
    if (map == null || map['data'] is! Map) {
      throw PlatformOperationException(
        'Unexpected PlayFab response for $endpoint.',
      );
    }
    return (map['data'] as Map).cast<String, dynamic>();
  }

  /// Closes the underlying HTTP client.
  void close() => _http.close();
}
