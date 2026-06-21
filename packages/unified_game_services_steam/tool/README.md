# Steam dev tooling

## `generate_steamworks.dart`

Regenerates the pure-Dart `steamworks` FFI bindings for a target platform and
copies the matching native redistributable next to the example.

Needed because the published `steamworks` ships **Windows** bindings only.
Linux/macOS/arm require regenerated bindings (steamworks issue #17).

### Get the SDK

The Steamworks SDK is login-gated at
<https://partner.steamgames.com/downloads/list> — it cannot be fetched
anonymously. Provide it (first match wins):

| Flag | Env | Meaning |
|------|-----|---------|
| `--sdk <dir>` | `STEAMWORKS_SDK` | extracted SDK root |
| `--zip <file>` | `STEAMWORKS_SDK_ZIP` | SDK zip on disk |
| `--url <url>` | `STEAMWORKS_SDK_URL` | your own/CI mirror of the SDK zip |

### Run

```sh
# from the package dir
dart run tool/generate_steamworks.dart --sdk /path/to/sdk            # host target
dart run tool/generate_steamworks.dart --zip sdk_162.zip -t linux

# or via melos from the repo root (forward args after `--`)
melos run steam:gen -- --sdk /path/to/sdk -t linux
```

Options: `-o/--output` (default `.steamworks/<target>`), `-t/--target`
(`win|linux|mac|arm`, default = host), `--app-id` (example `steam_appid.txt`,
default `480`), `--[no-]copy-natives`, `--[no-]analyze`.

### Wire the generated bindings

The tool prints this; add to the **workspace root** `pubspec.yaml` on non-Windows:

```yaml
dependency_overrides:
  steamworks:
    path: packages/unified_game_services_steam/.steamworks/<target>
```

Then `dart pub get`.

### Caveats

- `steamworks_gen` rewrites this package's `pubspec.yaml` ffi dependency
  (`pub remove ffi` + `pub add ffi`). Expected — re-pin `ffi` afterward if the
  constraint matters.
- `.steamworks/` is generated output; keep it out of git.
