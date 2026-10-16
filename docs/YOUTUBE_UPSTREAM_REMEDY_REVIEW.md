# Upstream 403 remedy review

Recorded 2026-10-11. Preserve the successful 0bcb90f1 checkpoint and its owned
native PASS / fresh-provider primary 403 as source-pinned evidence. This review
made no provider playback request and installed no APK.

Attribution corrected 2026-10-12 after the owner's explicit clarification; see
[decision D-015](DECISIONS.md#d-015---listening-outcome-and-execution-boundary-attribution).
The mission is recovery of the listening experience, not preservation of a broken
extractor or a particular engine. No Premium/subscription dependency is approved
by a proposal, and no account, cookie or credential experiment is authorized.

## Actual PR 390 mechanism

[PR 390](https://github.com/Hexer10/youtube_explode_dart/pull/390/files) remains
open/unmerged at edad2760cc7998bcc18013dc9880c052ad32598f, without reviews or added
tests. Its default changes from androidSdkless to VISIONOS, claiming Apple hardware,
visionOS and a Safari User-Agent. The stated purpose is avoiding token enforcement.
That identity switch was not applied under the assistant execution boundary
against evading verification or access restrictions. This is not an owner-imposed
implementation preference; the owner is implementation-flexible while requiring
avoidance of approaches that risk a YouTube account ban. No unofficial approach
is certified as having zero account risk.

| Other hunk | Applicability |
|---|---|
| HEAD failure filters formats to muxed | Availability-stage fallback; does not repair the fifth finite byte request. Our one-byte GET/original-header correction is already present. |
| WEB version/visitor context | Browse/search/continuation path, separate from media GET. Our WEB version is newer; no demonstrated missing visitor context explains this denial. |
| HLS return before playability check | Different source path; the failed source was non-live finite Opus/WebM. |

The [linked Musily commit](https://github.com/MusilyApp/musily/commit/31ac4abd971bdf55f6dd3c1903d1bb13e7d9c04b)
reports full 4,366,825-byte Opus delivery after switching to that fork/default
identity. Its two changed files include no independent trace/test artifact. This
is relevant author-side reproduction evidence, not our successful reproduction
or permission to change identity.

## Other primary fixes checked

- [PR 389](https://github.com/Hexer10/youtube_explode_dart/pull/389) is open;
  its Apple profile is the same mechanism. The claimed 10/10 range-GET sample and
  added manifest/HEAD test do not establish full delivery beyond 1 MiB. PR 388 is
  also open and substitutes that profile; PR 391 is closed/unmerged at the same
  head as 389.
- Official library master/tag remains 44a39a65d8e274806247d52af8f0bacd77691d38;
  [published latest remains 3.1.0](https://pub.dev/packages/youtube_explode_dart/changelog).
  The merged SDKless change in PR 371 is already included. There is no newer
  reviewed official release containing an ordinary late-range fix.
- [PR 382](https://github.com/Hexer10/youtube_explode_dart/pull/382) is an ordinary
  WEB-pagination version correction already present here (Chrome 125,
  2.20260618.05.00). It does not execute in the byte-fetch loop.
- [Musify PR 955](https://github.com/gokadzev/Musify/pull/955) added matching
  headers, unthrottled preference and a growing-file buffer; it merged September
  26 and was reverted October 1 in bddc68d307f82a2f359d7394fded4c20318c904b.
  Header provenance and finite read-ahead already exist in our tested path. Its
  buffering approach cannot repair a server's explicit refusal; no retained
  manifest establishes an eligible unthrottled alternate. The original patch
  also starts from a VISIONOS client.
- Current official Musify 10.5.3 explicitly tries VISIONOS then Android. Its
  header helper adds the selected profile's User-Agent/headers; this is not a
  same-client repair of our captured ANDROID source. Latest master
  [9ddeeb1](https://github.com/gokadzev/Musify/commit/9ddeeb113a5c022660a698c4ced9e4683a1b72a9)
  broadly enables Android cleartext for its localhost proxy. Our scoped GitHub
  loopback policy already passes native playback; no security expansion is adopted.

## Isolated ordinary correction

The [linked issue-386 branch](https://github.com/justacalico/youtube_explode_dart/compare/44a39a65d8e274806247d52af8f0bacd77691d38...292778ec44971789ac6a2f3a7facd3cb47b7a270)
also contains a date-parser repair matching the retained Search FormatException.
Only that small metadata correction is adopted: remove known relative-date
prefixes, preserve the old four-part fallback, and treat a nonnumeric quantity as
unknown. Compact Streamed 3mo ago no longer aborts the full Search result. The
original raw date and recording ID/title/artist/duration remain intact. This
repairs Search metadata handling, not the 1 MiB media denial. No client, header,
URL, access check, codec choice, resolver fallback or user-data schema changed.

Three new fixtures fail before the correction; all four pass afterward, including
real SearchClient parsing of two owned mocked records. The 58 existing focused
compatibility/transport tests, all 281 aggregate tests and analysis pass. Both
strict Windows suites retain their failures; all 35 actual images are byte-exact
to retained prior renders. Representative expected/current/diff images were
inspected. No golden or comparator changed. Exact new-source Linux CI remains
required and is recorded in the private checkpoint/PR after completion.

## Remaining bound

No reviewed ordinary correction has been shown to restore the captured Android
fifth-range request. The public mechanism that reports restoring this signature
changes platform identity to avoid verification, so it was excluded by the
assistant execution boundary, not by an owner instruction banning unofficial
implementations. Full provider acceptance stays held. A legitimate supported
same-client media/session contract or a provider/maintainer correction implementing
its genuine requirements remains a technical prerequisite; no paid integration
is inferred. Private upstream snapshots, diffs, test logs and preserved runtime
hashes stay outside Git under native-owned-transport/upstream-remedy-review.
