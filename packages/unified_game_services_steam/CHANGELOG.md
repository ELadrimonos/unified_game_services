# Changelog

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
- All Steam async call-results carry a 10s timeout so operations fail with
  `NetworkException` instead of hanging when Steam never replies.
- `dart run unified_game_services_steam:setup` copies the Steamworks
  redistributable and writes `steam_appid.txt` for local development.
