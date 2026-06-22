# unified_game_services_google_play_rest

Google Play Games provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services),
backed by the **REST Games API v1** (`games.googleapis.com/games/v1`). Pure
Dart, no Flutter — runs in custom game engines / native OS windows, CLIs and
servers, not only Flutter apps.

Because it talks to Google's cloud directly (not the on-device Play Services
client), it works the same on desktop, Android (NDK) and servers. The trade-off:
**no native Play Services achievement/leaderboard toasts** on Android — your
app draws its own UI. (A planned `unified_game_services_google_play_android`
provider will route writes through the Java SDK for native UX; this is the
cross-platform REST tier.)

## Supported capabilities

- **Achievements** — list (definitions joined with the player's progress),
  unlock, increment, reveal.
- **Leaderboards** — submit score, fetch a window (global/`PUBLIC` or
  friends/`SOCIAL`, all-time/weekly/daily), and the player's own score.

Not advertised: **stats** (GPG exposes only fixed read-only analytics), **cloud
save** (lives in Google Drive appdata — a separate API + scope), **friends** and
**presence**.

Provider-specific extras (off the unified interface, reach via
`UnifiedGameServicesPlatform.getInstance<GooglePlayGamesProvider>()`):
`setAchievementStepsAtLeast()`, `recordEvent()`.

## Authentication

The provider never performs OAuth itself — it takes a pluggable `AuthStrategy`:

- `LoopbackOAuthStrategy` — interactive authorization-code + **PKCE** flow with a
  `127.0.0.1` loopback redirect. Opens the system browser. For desktop/CLI.
  Needs a Google Cloud OAuth client of type **Desktop app**.
- `StoredCredentialStrategy` — a refresh token (renewed automatically) or a
  brokered access token. For servers/headless.
- `NativeSilentTokenStrategy` — consumes a token from a host-implemented
  `NativeTokenProvider` (e.g. Android silent sign-in). This package contains no
  native code; the host brokers the token.

Scope: `https://www.googleapis.com/auth/games`. Refresh tokens require
`access_type=offline` + `prompt=consent` (handled by `LoopbackOAuthStrategy`).

## Quick start

```dart
final auth = LoopbackOAuthStrategy(clientId: '<desktop-client-id>');
final games = GooglePlayGamesProvider(
  auth: auth,
  achievementIds: {'first_win': 'CgkI...'},
  leaderboardIds: {'global': 'CgkI...'},
);

await games.signIn();                       // browser consent once
await games.unlockAchievement('first_win');
await games.submitScore(leaderboardId: 'global', score: 1500);
final board = await games.getLeaderboard('global', maxResults: 10);
```

Or run the bundled demo:

```sh
dart run example/login_demo.dart --client-id <id> \
  --achievement first_win --achievement-native CgkI... \
  --leaderboard global --leaderboard-native CgkI... --score 1500
```

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
any platform vendor. Third-party credits and trademark notices are in the
repository's `NOTICE.md`.
