# Changelog

## 0.2.0

- **Breaking:** removed `SteamProvider.registerWith(...)`; construct the provider (`SteamProvider(...)`) and pass it to `GameServices.initialize(providers: [...])`.
- **Lobbies and invitations** via `ISteamMatchmaking` (`lobbies`, `invitations`):
  create (lobby or party), join, leave, get, find, update, member data, invite,
  lobby events, and `InvitationReceivedEvent` / `JoinRequestedEvent` from Steam
  invites and "Join game". `Lobby.joinToken` is the lobby's Steam id.
  - `findLobbies` returns public lobbies worldwide (Steam does not search
    friends-only or private lobbies).
  - Steam cannot read a lobby's type or list a member's data keys, so the
    provider stores two reserved entries (`ugs_vis` in lobby data, `ugs_md` in
    member data) and hides them from `Lobby.data` / `LobbyMember.data`.
  - Linux and macOS: `LobbyCreated_t` is read by hand, because Steam packs
    callback structs to 4 bytes there and the generated struct assumes 8.
  - `dispose()` leaves the lobbies it joined so other members see the player go
    right away.
- **Identity token:** `getIdentityToken()` (`identityTokens`) returns a Steam Web
  API auth ticket as hex for `ISteamUserAuth/AuthenticateUserTicket`. The ticket
  handle is cancelled 2 minutes after the call, so verify it right away. Use
  `getWebApiAuthTicket()` for control over the handle.
- `example/interactive_login.dart`: options 12 to 20 (identity token and
  lobbies, including inviting a friend from a numbered list).
- Verified on Linux against a live Steam client (lobbies, invitations to
  friends, identity ticket).
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
