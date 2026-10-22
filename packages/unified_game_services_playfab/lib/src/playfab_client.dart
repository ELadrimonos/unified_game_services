import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// A thin client for the PlayFab Client API.
///
/// PlayFab is keyed by a public `titleId`; every request goes to
/// `https://{titleId}.playfabapi.com` as a JSON POST. Authenticated calls carry
/// the player's session ticket in the `X-Authorization` header. The ticket
/// comes from a `LoginWith*` call and is stored with [setSessionTicket].
///
/// Responses are wrapped in a `{"code": 200, "status": "OK", "data": {...}}`
/// envelope; the client unwraps `data` and throws a [GameServiceException] when
/// the HTTP status or envelope reports an error.
///
/// An [http.Client] can be injected for testing.
class PlayFabClient {
  /// Creates a client for the title identified by [titleId].
  ///
  /// [httpClient] defaults to a new [http.Client]; the client owns it and
  /// closes it in [close]. [baseUrl] defaults to
  /// `https://{titleId}.playfabapi.com`.
  PlayFabClient({
    required this.titleId,
    http.Client? httpClient,
    String? baseUrl,
  }) : _http = httpClient ?? http.Client(),
       baseUrl = baseUrl ?? 'https://$titleId.playfabapi.com';

  /// The game's public Title ID, from the PlayFab Game Manager.
  final String titleId;

  /// The API root, without a trailing slash.
  final String baseUrl;

  final http.Client _http;

  String? _sessionTicket;
  String? _entityToken;
  DateTime? _entityTokenExpiry;
  String? _entityId;
  String? _entityType;

  /// Whether a session ticket has been stored, meaning the player is logged
  /// in.
  bool get hasSession => _sessionTicket != null;

  /// Stores [ticket], or clears it when `null`.
  ///
  /// The ticket is sent as `X-Authorization` on authenticated requests.
  /// Clearing it also clears the entity token (see [setEntity]).
  void setSessionTicket(String? ticket) {
    _sessionTicket = ticket;
    if (ticket == null) setEntity(null);
  }

  /// The entity token sent as `X-EntityToken` on entity APIs such as Lobby.
  String? get entityToken => _entityToken;

  /// When [entityToken] expires, if known.
  DateTime? get entityTokenExpiry => _entityTokenExpiry;

  /// Id of the signed-in `title_player_account` entity.
  String? get entityId => _entityId;

  /// Type of the signed-in entity (`title_player_account`).
  String? get entityType => _entityType;

  /// Stores the entity token and key from a login or `GetEntityToken` response
  /// (`{EntityToken, TokenExpiration, Entity: {Id, Type}}`).
  void setEntity(Map<String, dynamic>? entity) {
    if (entity == null) {
      _entityToken = _entityTokenExpiry = _entityId = _entityType = null;
      return;
    }
    _entityToken = entity['EntityToken'] as String? ?? _entityToken;
    final exp = entity['TokenExpiration'] as String?;
    _entityTokenExpiry = exp == null
        ? _entityTokenExpiry
        : DateTime.tryParse(exp);
    final key = (entity['Entity'] as Map?)?.cast<String, dynamic>();
    _entityId = key?['Id'] as String? ?? _entityId;
    _entityType = key?['Type'] as String? ?? _entityType;
  }

  /// Whether the entity token is missing or within a minute of expiring.
  bool get entityTokenStale {
    final exp = _entityTokenExpiry;
    return _entityToken == null ||
        (exp != null &&
            DateTime.now().toUtc().isAfter(
              exp.toUtc().subtract(const Duration(minutes: 1)),
            ));
  }

  /// POSTs [body] as JSON to [endpoint], for example
  /// `/Client/GetPlayerStatistics`.
  ///
  /// When [authenticated] is `true` the stored session ticket is attached;
  /// calling without a ticket throws [NotSignedInException]. With
  /// [useEntityToken] the entity token is sent as `X-EntityToken` instead
  /// (Lobby and other entity APIs). Returns the unwrapped `data` object.
  /// Throws [NetworkException] when the request fails, and
  /// [PlatformOperationException] when the HTTP status is not 200 (using
  /// PlayFab's `errorMessage` when present) or the body has no `data` object.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool authenticated = true,
    bool useEntityToken = false,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (useEntityToken) {
      final token = _entityToken;
      if (token == null) {
        throw const NotSignedInException(
          'PlayFab entity token missing; call signIn() first.',
        );
      }
      headers['X-EntityToken'] = token;
    } else if (authenticated) {
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
      final errorCode = map?['errorCode'];
      throw PlatformOperationException(
        message,
        code: errorCode == null ? null : '$errorCode',
      );
    }
    if (map == null || map['data'] is! Map) {
      throw PlatformOperationException(
        'Unexpected PlayFab response for $endpoint.',
      );
    }
    return (map['data'] as Map).cast<String, dynamic>();
  }

  /// Closes the underlying HTTP client, including one that was injected.
  void close() => _http.close();
}
