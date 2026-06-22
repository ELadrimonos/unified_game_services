## Unreleased

- Add Steam-specific account-linking API: `getSteamId64()`,
  `getWebApiAuthTicket()` (returns `SteamAuthTicket`), and `cancelAuthTicket()`.
  Enables verifying a Steam identity against your own backend via the Steam Web
  API `AuthenticateUserTicket` ("Steam OAuth"-style linking).

## 0.0.1

- Initial release: Steam provider backed by the pure-Dart Steamworks FFI bindings.
