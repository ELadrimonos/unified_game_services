# Changelog

## 0.2.0

- **Breaking:** removed `SteamProvider.registerWith(...)`; construct the provider (`SteamProvider(...)`) and pass it to `GameServices.initialize(providers: [...])`.
- **Lobbies and invitations** via `ISteamMatchmaking`: create, join, leave, get, find (public lobbies, worldwide), update, member data, invite, lobby events, plus `InvitationReceivedEvent` and `JoinRequestedEvent` from Steam invites and "Join game". `Lobby.joinToken` is the lobby's Steam id. Not yet verified against a live Steam client; try it with `example/interactive_login.dart` (options 13-20).
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

## 0.1.0

Initial release.

- Steam provider backed by the pure-Dart Steamworks FFI bindings
  (`package:steamworks`). Desktop only; web builds get a conditional-export
  stub that throws `UnsupportedError`.
- Achievements, leaderboards, stats, cloud save (Remote Storage), friends and
  rich presence.
- Steam-specific account-linking API: `getSteamId64()`,
  `getWebApiAuthTicket()` (returns `SteamAuthTicket`) and `cancelAuthTicket()`
  for backend verification via the Steam Web API `AuthenticateUserTicket`.
- Init errors from `steamworks` are mapped: `SteamInitializationError` keeps its
  native message in `SignInFailedException`; `SteamRestartAppIfNecessaryError`
  becomes `SteamRestartRequiredException` (Steam-specific, extends
  `SignInFailedException`). Requires `steamworks ^0.4.10`.
- All Steam async call-results carry a 10s timeout so operations fail with
  `NetworkException` instead of hanging when Steam never replies.
- `dart run unified_game_services_steam:setup` copies the Steamworks
  redistributable and writes `steam_appid.txt` for local development.
