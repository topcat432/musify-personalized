# Owned native finite-source rehearsal

Use only an explicitly approved disposable Android AVD. This target is a test
entrypoint, not the normal app. It keeps normal Hive files closed and uses a
separate app-document subdirectory. Preserve installed data/signature and verify
an in-place debug update; never uninstall, clear data or alter network policies.

Generate two owned 48 kHz stereo sine tones with an existing FFmpeg/libopus:

```text
ffmpeg -f lavfi -i sine=frequency=440:sample_rate=48000:duration=70 -ac 2 -c:a libopus -b:a 128k -vbr off -f webm owned-long-opus.webm
ffmpeg -f lavfi -i sine=frequency=660:sample_rate=48000:duration=8 -ac 2 -c:a libopus -b:a 128k -vbr off -f webm owned-next-opus.webm
```

Record encoder/version, file sizes and SHA-256. Preserve generated originals;
container metadata can vary between encodes. The long input must exceed 1 MiB.
Place both files in the approved package's app-scoped external
`files/native-owned-transport` directory, and independently verify device hashes.
Do not use provider audio or modify the normal app's library.

Build `tool/native_owned_transport_rehearsal.dart` explicitly with the GitHub
debug flavor, the current GIT_SHA and a unique OWNED_RUN_ID; keep its APK separate
from a later normal-entrypoint candidate. All SDK components must already exist.
Install in place on the named serial, verify certificate/package/APK and compare
all four normal Hive hashes before launching.

The target uses the production GoogleVideoByteSource/IPv4 loopback proxy,
just_audio/native Opus decoding and MusifyAudioHandler completion/advancement.
Only upstream byte delivery is replaced with owned exact-range file responses.
It performs a mid seek, tail seek/completion, then uninterrupted full 70-second
playback and natural next-source advancement/completion. It records native request
bounds, finite-range counts, decoded positions, source errors and input hashes in
`app_flutter/native-owned-transport-<OWNED_RUN_ID>/report.json`. Player volume is
zero; this tests transport/decode/session progress, not audibility.

Stop at a source failure, preserve the report/log and compare normal Hive hashes
again. A pass requires real progress, completion/next decode, a completed finite
tail beyond 1 MiB, no source failure and no provider request. An owned pass does
not prove public-provider access. Only afterward may a separately authorized
normal fresh never-denied provider source be selected, with original resolver
identity/headers and first-error capture. Restore the normal app entrypoint by an
in-place matching-signer update; keep all data and fixtures.
