# unified_game_services_epic

Epic Online Services (EOS) provider for
[`unified_game_services`](https://pub.dev/packages/unified_game_services).

> **Status: planned (not yet implemented).** Part of the MVP roadmap. Pure Dart
> via the EOS REST/C SDK. This package is currently a placeholder.

When ready it will implement `UnifiedGameServicesPlatform` with EOS-backed
achievements, leaderboards/stats and friends, and plug into the unified API
alongside the other providers:

```dart
final services = UnifiedGameServices(providers: [EpicProvider(/* … */)]);
```

For the available providers today, see
[`unified_game_services`](https://pub.dev/packages/unified_game_services),
`unified_game_services_steam` and `unified_game_services_gamejolt`.

## License

MIT — see the [LICENSE](LICENSE) file.

This is an independent, unofficial library, not affiliated with or endorsed by
any platform vendor. Third-party credits, trademark notices, and the Steamworks
SDK redistribution terms are in the repository's `NOTICE.md`.

