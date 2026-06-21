# unified_game_services_google_play

Google Play Games provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services).

> **Status: research (not yet implemented).** Google Play Games exposes a REST
> Games API v1 (`games.googleapis.com/games/v1`) reachable from pure Dart over
> `package:http` — it covers achievements, scores/leaderboards, snapshots
> (cloud save), players and stats for the signed-in player. That is the planned
> path here. The *native* Android SDK (and `games_services`, which depends on
> Flutter + platform channels) stays out — it violates the no-Flutter
> constraint. Open work: the player OAuth 2.0 flow (scope
> `.../auth/games`); an authorization-code + loopback flow works in pure Dart on
> desktop/CLI/server. This package is a placeholder pending that implementation.

For the available providers today, see
[`unified_game_services`](https://pub.dev/packages/unified_game_services),
`unified_game_services_steam` and `unified_game_services_gamejolt`.

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
any platform vendor. Third-party credits, trademark notices, and the Steamworks
SDK redistribution terms are in the repository's `NOTICE.md`.

