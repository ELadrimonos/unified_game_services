# Handoff — Implement Presence + Cloud Save in EpicProvider

Continuation context for a fresh conversation. Goal: implement **rich presence**
(`setPresence`/`clearPresence`) and **cloud save** (`saveData`/`loadData`/
`listSaves`/`deleteSave`) on the EOS provider via `dart:ffi`.

## Where things stand

Package: `packages/unified_game_services_epic`. Provider:
`lib/src/epic_provider.dart`. Bindings: `lib/src/eos_bindings.dart`
(**ffigen-generated, verified** against EOS SDK v1.19.1.2 — offsets trustworthy,
not hand-authored anymore).

**Already implemented & runtime-verified on macOS (Dev Auth Tool):** EAS sign-in
(Device ID / `EOS_LCT_Developer` / `EOS_LCT_ExchangeCode`), real profile
(`getCurrentPlayer`), friends (`getFriends`), achievements unlock + read,
stats write + read, leaderboards read. Capabilities advertised: achievements,
leaderboards, stats, friends.

**Bindings config fixed** (`ffigen_eos.yaml`): `eos_friends.h`, `eos_presence.h`,
`eos_playerdatastorage.h` are now in `entry-points`, so **all** Presence + PDS
function wrappers are generated. Regenerate any time with `melos run epic:gen`
(needs `EOS_SDK_DIR`, already set globally on this machine →
`/Users/adrpriber/dev/EOS-SDK-53289219-Release-v1.19.1.2/SDK`).

**Not done — this handoff's task:** presence + cloud save. The interface methods
in `unified_game_services_platform.dart` currently throw `UnimplementedError`
(EpicProvider does not override them yet).

## Conventions to follow (copy existing patterns in epic_provider.dart)

- **Async bridge:** `_track((token, clientData) => eos.SomeCall(..., clientData,
  Pointer.fromFunction<...>(_onSomeComplete)))` returns `_CbResult` (has `.code`).
  Add a new static completion callback per async op, mirroring
  `_onQueryFriendsComplete` (read token from `info.ref.ClientData.cast<Int32>()`,
  `_pending.remove`, free token, complete `_CbResult(code)`).
- **Logging:** use `_log(...)` (gated by `static bool debugLogging`), never raw
  `print`.
- **Memory:** `calloc<...>()` every options struct + native strings
  (`.toNativeUtf8().cast<Char>()`), free in `finally`. Release SDK-allocated
  copies (e.g. metadata) with the matching `*_Release`.
- **Interfaces:** fetch handles in `_ensureInit()` (add `_presence` and
  `_playerDataStorage` fields + `EOS_Platform_Get{Presence,PlayerDataStorage}
  Interface`), null them in `dispose()`.
- **Result codes:** `checkEosResult(res.code, 'EOS_...')` maps to the exception
  hierarchy; `EosResult.success == 0`.
- Presence/PDS need an **EAS login** (`_epicAccountId` for presence;
  `_localUserId` PUID for PDS). Guard like `getFriends` does and throw
  `CapabilityNotSupportedException(GameCapability.presence/cloudSave, cause: ...)`
  on the anonymous Device ID path.
- Add `GameCapability.presence` / `GameCapability.cloudSave` to the
  `capabilities` getter once implemented.

## Presence (the easy one — do first)

Maps `RichPresence` (`platform_interface/lib/src/models/rich_presence.dart`:
`state`, `details`, `startedAt`, `partySize`, `partyMax`). Only `state`+`details`
map cleanly to EOS rich text; party/startedAt have no clean equivalent — document
as unmapped (or stuff into `SetData` custom records, optional).

EOS flow (all wrappers exist in bindings):
1. `EOS_Presence_CreatePresenceModification(_presence, opts, outHandle)` →
   `EOS_HPresenceModification`. Opts: `{ApiVersion =
   EOS_PRESENCE_CREATEPRESENCEMODIFICATION_API_LATEST, LocalUserId =
   _epicAccountId}`. Returns `EOS_EResult` (sync), handle via out-param
   `calloc<EOS_HPresenceModification>()`.
2. `EOS_PresenceModification_SetStatus(modHandle, opts)` — opts `{ApiVersion =
   EOS_PRESENCEMODIFICATION_SETSTATUS_API_LATEST, Status =
   EOS_Presence_EStatus.EOS_PS_Online}` (enum: Offline0/Online1/Away2/
   ExtendedAway3/DoNotDisturb4). Sync, returns EResult.
3. `EOS_PresenceModification_SetRawRichText(modHandle, opts)` — opts `{ApiVersion =
   EOS_PRESENCEMODIFICATION_SETRAWRICHTEXT_API_LATEST, RichText =
   '<state> — <details>'.toNativeUtf8().cast<Char>()}`. Max 255 chars; truncate.
   Sync.
4. `EOS_Presence_SetPresence(_presence, opts, clientData, callback)` — **async**,
   callback type `EOS_Presence_SetPresenceCompleteCallback`, callback-info struct
   `EOS_Presence_SetPresenceCallbackInfo` (has ResultCode/ClientData/LocalUserId).
   Opts `{ApiVersion = EOS_PRESENCE_SETPRESENCE_API_LATEST, LocalUserId =
   _epicAccountId, PresenceModificationHandle = modHandle}`. Track via `_track`.
5. `EOS_PresenceModification_Release(modHandle)` in `finally`.

`clearPresence()`: same flow but SetRawRichText to '' (and/or SetStatus Offline).

Add static callback `_onSetPresenceComplete(Pointer<EOS_Presence_SetPresence
CallbackInfo>)` mirroring the others.

## Cloud save (the hard one — transfer callbacks)

Model: `CloudSave` holds `List<int> data` + `metadata` (CloudSaveMetadata:
`slot`, `sizeBytes`, `modifiedAt`, `deviceName`); `CloudSave.fromBytes(...)` and
`.bytes` getter exist. Interface:
- `saveData(String slot, Uint8List data)` → write
- `loadData(String slot)` → `CloudSave?`
- `listSaves()` → `List<CloudSaveMetadata>`
- `deleteSave(String slot)` → delete

PDS is chunked — **the data flows through native transfer callbacks**, not a
single buffer. This is the tricky part: the SDK calls your data callback
repeatedly with chunks. Because `Pointer.fromFunction` callbacks are static, the
in-flight buffer must live in a static map keyed by the transfer (e.g. by
filename or a token), like `_pending`.

Wrappers available (verified):
- `EOS_PlayerDataStorage_WriteFile(_pds, opts, clientData, completeCb)` returns
  `EOS_HPlayerDataStorageFileTransferRequest`. Opts
  (`EOS_PlayerDataStorage_WriteFileOptions`): `{ApiVersion, LocalUserId (PUID),
  Filename (Char*), ChunkLengthBytes (e.g. 4096), WriteFileDataCallback
  (EOS_PlayerDataStorage_OnWriteFileDataCallback), FileTransferProgressCallback
  (nullable)}`. The **WriteFileDataCallback** is called repeatedly: it receives a
  `Pointer<EOS_PlayerDataStorage_WriteFileDataCallbackInfo>` (has
  DataBufferLengthBytes + OutDataBuffer + OutDataWritten) and must copy up to
  `DataBufferLengthBytes` of your payload into `OutDataBuffer`, set
  `*OutDataWritten`, and return an `EOS_PlayerDataStorage_EWriteResult`
  (ContinueWriting / CompleteRequest / FailRequest).
- `EOS_PlayerDataStorage_ReadFile(_pds, opts, clientData, completeCb)` → transfer
  request handle. Opts (`EOS_PlayerDataStorage_ReadFileOptions`): `{ApiVersion,
  LocalUserId, Filename, ReadChunkLengthBytes, ReadFileDataCallback
  (EOS_PlayerDataStorage_OnReadFileDataCallback), FileTransferProgressCallback}`.
  The **ReadFileDataCallback** receives chunks (DataChunk + DataChunkLengthBytes +
  TotalFileSizeBytes) to accumulate; returns EReadResult (ContinueReading/...).
- `EOS_PlayerDataStorage_QueryFileList(_pds, opts, clientData, completeCb)` —
  async; caches the file list. Then `EOS_PlayerDataStorage_GetFileMetadataCount`
  + `EOS_PlayerDataStorage_CopyFileMetadataAtIndex` /
  `CopyFileMetadataByFilename` → `EOS_PlayerDataStorage_FileMetadata`
  (`FileSizeBytes`, `MD5Hash`, `Filename`, `LastModifiedTime`,
  `UnencryptedDataSizeBytes`) → release with the matching `*_Release`.
- `EOS_PlayerDataStorage_DeleteFile(_pds, opts, clientData, completeCb)` — async.
- `EOS_PlayerDataStorageFileTransferRequest_Release(handle)` — free the transfer
  request when its completion callback fires.

Notes:
- **EncryptionKey required:** PDS encrypts at rest. `EpicCredentials.encryptionKey`
  must be set (passed to `EOS_Platform_Options.EncryptionKey` in `_ensureInit` —
  already wired). Without it, writes/reads fail. Surface a clear error if null.
- Data callbacks are static → keep per-transfer state (payload to write / bytes
  read so far) in a static `Map` keyed by filename, set it before calling
  Write/ReadFile, clean up in the completion callback.
- `slot` (unified) maps to EOS `Filename`. Decide whether to namespace
  (e.g. `'$slot.sav'`) — keep it simple, document.

## Verification

Cannot fully unit-test (needs live EOS + configured product). Plan:
1. `cd packages/unified_game_services_epic && dart analyze` — must stay clean
   (it is now).
2. Manual via `example/` (Flutter macOS) with the Dev Auth Tool login
   (`debugLogging: true` already on in `example/lib/main.dart`). Add buttons to
   call setPresence / saveData / loadData / listSaves. Cloud save needs an
   `encryptionKey` in the EpicCredentials form (add a field) and the EAS
   Application configured.
3. Watch the `_log` traces (`🪪`/`👥`-style) for result codes.

## Gotchas already learned (don't rediscover)

- `print` → use `_log` (static, gated by `debugLogging` ctor flag).
- Native completion callbacks must be **static** (`Pointer.fromFunction`); correlate
  to Futures via the `ClientData` Int32 token + the static `_pending` map.
- ffigen only emits **functions** for headers in `entry-points`; types are pulled
  in transitively (that's why structs existed but functions didn't until the 3
  headers were added). If you need another interface, add its header there and
  `melos run epic:gen`.
- EAS gotchas: needs an Epic Account Services **Application** in the Dev Portal
  with the client associated + scopes (else `EOS_InvalidRequest` 1012). Friends
  returning 0 is **by design** — friends must have played the product + consented.
- No avatar from the C SDK (`PlayerProfile.avatarUrl` always null).
- pub.dev posture: commit the generated `eos_bindings.dart`; never commit
  `.eos-sdk/` (SDK is EULA-gated). ffigen is a CLI (not build_runner) — the script
  is correct.

## Files

- `lib/src/epic_provider.dart` — add presence + cloud save here.
- `lib/src/eos_bindings.dart` — generated; do not hand-edit.
- `ffigen_eos.yaml` / `tool/regenerate_bindings.sh` — bindings generation.
- `example/lib/main.dart` — manual test harness (form-driven, debugLogging on).
- `README.md` (package) + root `README.md` + `CLAUDE.md` — update capability
  tables + gap lists when done.
