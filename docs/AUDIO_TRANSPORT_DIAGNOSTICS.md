# Bounded audio transport diagnostics

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
is required separately; no local native or provider pass is claimed here.

## Next discriminating validation (not run)

First use owned complete encoded Opus/WebM bytes, longer than multiple finite
ranges, through the candidate's native byte-source/proxy lifecycle on the owned
emulator. Compare complete delivery, seek/tail/cancel and natural next-source
advancement. This separates native decode/proxy/boundary defects from upstream
access; byte fixtures alone do not close that gate.

Only after that passes, a single normal selection of a never-denied fresh source
with the same resolver configuration and its original recorded User-Agent can
capture the first diagnostic. This is an observability test, not a replay of the
failed endpoint. A captured 403 with range/bytes supports a denial at that stage;
206 plus bad range/length or early EOF supports a transport mismatch; a timeout
without status is a connection/header failure. A native decode error after exact
complete delivery needs separate decoder evidence. Stop on the first failure,
retain the redacted cause chain and do not repeat a denied endpoint, rotate
identities or add credentials. No new live validation occurred in this repair.
