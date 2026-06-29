# Credits, third-party notices & trademarks

`unified_game_services` is an independent, unofficial library. It is **not**
affiliated with, endorsed by, or sponsored by any of the platform vendors whose
services it talks to. All product names, logos, and brands are property of their
respective owners and are used only to identify the service each provider
integrates with (nominative use).

## No bundled SDKs or native binaries

This repository ships **Dart source only**. It does **not** redistribute any
vendor SDK, native library, header, or binary that it does not have the right to
redistribute. In particular:

- **The Steamworks SDK / native library is not included here.** Valve's
  Steamworks SDK Access Agreement forbids redistributing the SDK. The Steam
  provider depends on the third-party [`steamworks`][steamworks] Dart package,
  which bundles Valve's official redistributable; `dart run
  unified_game_services_steam:setup` copies that file out of *your* local pub
  cache into *your* project at setup time. To ship a product you must obtain and
  distribute the native library under your own Steamworks agreement. See
  `packages/unified_game_services_steam/README.md`.

## Trademarks

- **Steam** and **Steamworks** are trademarks and/or registered trademarks of
  **Valve Corporation**.
- **Game Jolt** is a trademark of **Game Jolt Inc.**
- **Epic Online Services** and **Epic Games** are trademarks of
  **Epic Games, Inc.**
- **Xbox** and **PlayFab** are trademarks of **Microsoft Corporation**.
- **Google Play** and **Google Play Games** are trademarks of **Google LLC**.
- **Game Center** and **Apple** are trademarks of **Apple Inc.**

Use of these names does not imply any affiliation with or endorsement by their
respective owners. Each provider integrates with the vendor's publicly
documented API and is subject to that vendor's own terms of service; you are
responsible for complying with them.

## Third-party dependencies

This software builds on the following open-source packages, under their own
licenses:

| Package | License | Copyright |
| --- | --- | --- |
| [`steamworks`][steamworks] | BSD-3-Clause | © 2022 Ahmet Enes Bayraktar |
| [`dart_mappable`](https://pub.dev/packages/dart_mappable) | MIT | © Kilian Schulte |
| [`ffi`](https://pub.dev/packages/ffi) | BSD-3-Clause | © Dart project authors |
| [`http`](https://pub.dev/packages/http) | BSD-3-Clause | © Dart project authors |
| [`crypto`](https://pub.dev/packages/crypto) | BSD-3-Clause | © Dart project authors |
| [`async`](https://pub.dev/packages/async) | BSD-3-Clause | © Dart project authors |
| [`plugin_platform_interface`](https://pub.dev/packages/plugin_platform_interface) | BSD-3-Clause | © Flutter authors |

The Steam provider is, in essence, a thin wrapper over the pure-Dart Steamworks
FFI bindings in [`steamworks`][steamworks]. Full credit for those bindings goes
to its author.

[steamworks]: https://github.com/aeb-dev/steamworks
