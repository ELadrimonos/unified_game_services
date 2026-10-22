# Changelog

## 0.2.0

- Fix: `getStat`, `setStat` and `incrementStat` now map the key through `resolveStatId`, so `UnifiedStatTable` mappings apply.
- **Breaking:** removed `EpicProvider.registerWith(...)`; construct the provider (`EpicProvider(...)`) and pass it to `GameServices.initialize(providers: [...])`.
- **Identity token:** `getIdentityToken()` (`identityTokens`) returns the signed-in
  user's EOS Connect ID token (a JWT, `EOS_Connect_CopyIdToken`). Verify it on
  your backend against Epic's JWKS; the ProductUserId is the `sub` claim. Works
  with every sign-in method. Not yet exercised against a live EOS backend.
- Implements the new `providerId` contract of `unified_game_services_platform_interface` 0.2.0; version aligned with the workspace.

## 0.1.0

Initial release.

- Epic Online Services provider over the EOS C SDK via `dart:ffi` (the host
  ships the EOS runtime library and supplies `EpicCredentials`). Desktop only;
  web builds get a conditional-export stub that throws `UnsupportedError`.
- Sign-in: anonymous Device ID (including first-time `EOS_Connect_CreateUser`),
  Dev Auth Tool (`EOS_LCT_Developer`) and Epic Launcher exchange code
  (`EOS_LCT_ExchangeCode`), with the full Auth → Connect flow for Epic Account
  Services logins.
- Achievements (unlock + read), stats (ingest + read), leaderboards
  (submit via backing stat + read), friends, real profile display name,
  rich presence and cloud save via Player Data Storage.
- Background `EOS_Platform_Tick` pump (`tickInterval`) plus per-operation
  ticking; 30s operation timeout with safe ClientData-token lifetime on the
  timeout path.
- FFI bindings ship without any EOS header documentation text (functional API
  surface only); regenerate against your own SDK copy with
  `tool/regenerate_bindings.sh`.
