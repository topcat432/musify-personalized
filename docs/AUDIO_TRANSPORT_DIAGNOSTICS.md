# Bounded audio transport diagnostics

## Owned native pass and fresh provider denial, 2026-10-11

Runtime-tested source is 4e9325d07c0bd0fae4295e6c9226c1a6d904292c.
Production transport is unchanged from 54c3ed85; the additional tool entrypoint
isolates its Hive directory and supplies generated owned bytes through the actual
GoogleVideoByteSource, IPv4 just_audio proxy, native Opus decoder and production
MusifyAudioHandler. [Exact Linux CI 38179065225](https://github.com/topcat432/musify-personalized/actions/runs/38179065225)
passed analysis, 277 tests, both strict visual suites (35 images), debug/F-Droid
boundaries and unsigned assembly. The harness itself analyzes cleanly.

On owned emulator-5556 / musify_rehearsal_api35, the 1,145,788-byte 70-second
Opus/WebM file completed uninterrupted, including finite reads beyond 1 MiB.
The 35-second seek, 68-second tail seek/completion and natural advancement to the
complete 8-second second file passed. Independent report inspection confirms
complete first-file byte coverage, exact delivered range lengths, a 256 KiB
maximum finite range and no source failure. There were zero provider requests.
Volume was zero: this proves native decode/session progress, not audibility.
The first harness bootstrap had no source request because ADB-created external
fixture storage was unreadable. Existing debug run-as access copied owned inputs
into private documents and independent readback verified both hashes; no security
or permission changes were used. See tool/NATIVE_OWNED_TRANSPORT.md.

The normal-entrypoint APK was then installed in place with the same development
signer. All four normal Hive files were byte-exact through harness execution and
both installs. Only after the owned pass, one never-denied fresh recording was
selected through its normal single-song menu action, with automatic next-song
selection already false. Existing resolver configuration and original User-Agent
were unchanged. Native Opus initialized and playback advanced, then the first
origin diagnostic recorded HTTP 403 in the headers phase for range
1048576-1310719 of a 5,108,604-byte source. Exactly 1,048,576 bytes had been
delivered; the rejected 262,144-byte range returned no body or Content-Range.
The loopback source and responseDone failures retained that same origin, and the
bounded runtime signal correctly reported nativeCode null. The owned package was
stopped immediately; no manual replay or denied-source retry was performed.
This is a directly observed provider denial, not the older status-unknown failure.
It does not identify an account/IP/token cause or prove a global provider outage.

Complete provider listening/download/preview remains FAIL/BLOCKED. The owned
pass does not turn those gates green. Existing normal data is retained: semantic
comparison found only expected searchHistory/recentlyPlayedSongs/listening-stat
changes and eight derived cache additions, with no removed keys and every other
user value plus all settings and usernobackup values exact. Original cache values
were unchanged. Search also independently exposed a streamed-date parsing error
before playback; the fresh source was reached through normal Home playlist UI.
No search parser or client identity was changed for this test.

Private reports, APKs, fixture originals, raw Hive copies, redacted logs and
inventories stay outside Git under
musify-source-comparison/upstream-comparison-20261011/native-owned-transport.
The normal app entrypoint remains installed and stopped on the owned AVD.
No phone operation, merge, signing/publication, deployment or data migration ran.

## Evidence and limits, 2026-10-11

The prior source 77f339a697e0a752db505d93cdf64f695c7fc023 passed exact
[Linux CI 38173114591](https://github.com/topcat432/musify-personalized/actions/runs/38173114591),
including 261 tests and 35 strict visual images. Its development-signed APK was
updated only on the owned disposable emulator; all four Hive files were exact
before launch. One normal fresh selection initialized the Opus decoder, then
failed. Full-song completion and next-song did not pass. No source was replayed.

The retained later stack enters GoogleVideoByteSource.request's terminal guard.
That guard is set by _fetchRanges when a GET/header/body/timeout fails, not by
request-range rejection, a concurrency limit or a decoder error alone. The
original HTTP status was lost: _fetchRanges replaced it with a generic StateError,
and the local response writer consumed the earlier stream exception. The printed
player code 0 can be synthesized by Musify's bounded-source callback; it is not
an HTTP status. Codec cleanup followed the stop and does not prove decoder failure.
These facts do not establish another provider 403 or retrospectively identify
which response failed. The official upstream 10.5.3 localhost cleartext failure
is separate from this upstream-byte-fetch failure.

## Contract comparison and ordinary repair

| Path | Native contract / behavior |
|---|---|
| just_audio 0.10.6 StreamAudioSource | start inclusive, end exclusive; a failed request future becomes local HTTP 500; a body failure remains an incomplete response |
| Musify finite source | exact signed HTTPS URI and recorded original User-Agent; GET ranges at most 256 KiB; four active reads; 206 offsets and byte counts validated; no provider retry/identity change |
| Official upstream 10.5.3 downloader | much larger ranges or query ranges, broad status validation, body-stream errors suppressed; therefore not a correctness reference to copy |
| Official upstream native URI | its default header proxy has a separately reproduced Android localhost cleartext failure |

The old exact-string Content-Range comparison rejected valid case variants of
bytes and an unknown total (*). [RFC 9110 sections 14.1 and 14.4](https://www.rfc-editor.org/rfc/rfc9110.html#section-14.4)
allow these. Parsing now accepts those variants while requiring the exact requested
start/end, any known total to equal source length, and an exact body count.
Incorrect offsets, changed known totals, ignored ranges/200 responses, redirects,
short/oversized bodies and true 403 still fail. This demonstrated parser defect
is not a proven explanation of the retained native failure.

An already active read also rechecks the retained first failure after headers
and before yielding bytes. It cannot continue delivery after another read failed.
Cancellation remains cancellation, with no invented provider denial.

## Safe retained evidence

AudioTransportFailure keeps the originating cause object and stack in memory.
Its allowlisted diagnostic contains request ID, native and upstream byte bounds,
source length, response status, parsed numeric Content-Range (or absent/invalid),
declared/received/delivered bytes, header/body phase, failure kind and cause types.
No signed URI, token, arbitrary header/body text, media title, ID or private tag
is serialized. Diagnostic consumers cannot replace the actual error.

The same failure and originating stack survive subsequent local requests without
another provider GET. The response writer reports request/source/write/close/done
phase and written/expected bytes; secondary completion failures retain the first
source failure in their chain. Native-player errors and synthesized transport
signals are labelled separately, and a transport signal has no invented native
code. These are transient observations, not a user-data schema or cache migration.

Owned fixtures exercise later-range denial and terminal/no-retry behavior,
pre-created/concurrent reads, valid range variants, bad offsets/lengths, truncated
and oversized bodies, original network exceptions, header/body timeouts,
cancellation/backpressure, redaction and real localhost incomplete responses.
They compare raw source delivery with the proxy writer and preserve both causes.
They do not establish Android decoding or public-provider availability.

## Offline validation

Clean analysis and all 277 aggregate tests pass. The 60 focused tests cover the
transport, provenance, proxy writer and handler. Seventeen new committed tests
replace one old invalid expectation that treated unknown-total Content-Range as
incorrect. Four private tests using the exact preserved 77f339a6 byte-source file
reproduce the two valid-header rejections, overwritten status and concurrent
post-failure delivery. These control tests assert the old defects; they are not
new candidate acceptance tests and are not added to the aggregate count.

Both strict Windows visual suites fail all 35 images; 33 current test images match
the retained unchanged-source control exactly. The two About differences are prior
identity/version fixture labels. Representative master/current/diff images were
inspected. Neither goldens nor comparator was modified. Linux source-pinned CI
is recorded above. Offline checks alone establish neither Android decoding nor
provider access; the executed native gates are separate evidence.

## Resulting limits

The executed owned gate establishes real native finite-source/proxy progress,
seek/tail handling and natural advancement with controlled complete Opus bytes.
The single fresh normal-provider gate directly establishes a headers-phase 403
at the fifth 256 KiB range. Its retained proxy completion error is secondary;
the upstream origin remains the same. Neither outcome identifies the provider's
access-policy cause or certifies audible output, complete provider listening,
downloads, preview or a physical-device update. Denied media was not replayed.
