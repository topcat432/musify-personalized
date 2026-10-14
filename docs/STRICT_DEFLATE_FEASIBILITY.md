# Bounded strict DEFLATE feasibility,2026-10-14

F03 remains PARTIAL. Safe checkpoint87704dd6 is preserved. No dependencies were
added/upgraded, remote source was not executed, no device work/signing occurred.

## Requirements

Reject incomplete streams, unused/concatenated compressed input, contradictory
ZIP lengths/CRC, declared or actual output overruns and stale cancellation. Keep
8 MiB input/output and10,000-row bounds, zero extraction and unchanged durable
session on failure. Header sizes, cursor exhaustion and CRC alone are insufficient.

## Installed / maintained routes

| Route | Evidence | Result |
|---|---|---|
| Dart3.12.2 ZLibDecoder/RawZLibFilter | Actual failing-before fixtures and [pinned SDK interface](https://github.com/dart-lang/sdk/blob/3.12.2/sdk/lib/io/data_transformer.dart) | No consumed-byte/end status; processed(null) reports no output, not verified completion. Not selected. |
| Installed archive4.0.9 IO ZLib/ZIP | [Pinned source](https://github.com/brendan-duncan/archive/tree/v4.0.9/lib/src/codecs); IO wrapper delegates to Dart, feeds the whole input and returns true; its callback can buffer output before forwarding | Same raw-completion limitation; input cursor reaches end because wrapper reads it, not because codec consumed it. Not selected. |
| Installed archive4.0.9 pure Inflate | Private block parser returns failure/end through the same false result; public interface exposes output, not a final-block result | Public cursor alone is not completion proof; no built-in output cap. Not selected. |
| Existing Android/JDK Inflater | [Android primary API](https://developer.android.com/reference/java/util/zip/Inflater), [JDK17 primary API](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/zip/Inflater.html) | Supplies finished(), getBytesRead(), getRemaining() and bounded inflate buffer. Selected; thin adapter implemented, host-tested. |
| Installed Python zlib | [Primary API](https://docs.python.org/3/library/zlib.html) exposes eof/unused_data/unconsumed_tail/max_length | Useful independent host fixture/oracle; not an Android app runtime and not a product solution. |

Android minSdk remains24; no manifest/permission or package/signing changes.
StrictDeflate adds only a bounded adapter around the maintained platform codec.
A documented nowrap dummy byte is appended; success requires original payload
consumption exactly, with the dummy still unused/unfed. This prevents the dummy
repairing a truncated stream. CRC is independently checked after the bridge.
Input and output each advance in16 KiB bounds; even many empty blocks allow
cancellation/deadline checks. Native resources close in finally. The channel owns
one worker/request, rejects overlap and cancels it on engine cleanup; no decoder
request touches files or another app/thread pool. Real Android lifecycle proof
remains pending; desktop/absent-channel compressed intake still fails closed.

## Later portable-dependency options (not installed or qualified)

The maintainer's [current source at70f765f0](https://github.com/brendan-duncan/archive/tree/70f765f0df6334da3c9eba7e4a72b9b1b2bc2354)
identifies itself as4.6.0, whereas pub.dev reports4.5.2. Current source adds a
final-block status and stricter block-wise API; it also rewinds whole lookahead
bytes. This is a plausible future portable route with a bounded output sink and
exact remaining-input check, but no downloaded package was executed or promoted.
Do not assume the normal native wrapper's verify/throwOnError flags establish
raw completion: its current source explicitly documents that they do not.

The [v4.5.1 tagged pure inflater](https://github.com/brendan-duncan/archive/blob/v4.5.1/lib/src/codecs/zlib/inflate.dart)
adds a block API but can return false at input exhaustion without a verified
final block. Simply upgrading to a newer high-level codec is not proof.
[Maintainer security guidance](https://github.com/brendan-duncan/archive/blob/70f765f0df6334da3c9eba7e4a72b9b1b2bc2354/doc/security.md)
requires output caps; low-level Inflate/lazy APIs do not provide that parameter.
A later decision would need an exact released/source pin, per-write/history
output bounds, malformed-input/cancellation tests, runtime/library review and
all supported-platform CI. This would extend desktop portability but add a
runtime dependency/qualification burden; it is not needed for the selected
Android standard-library route.

A direct zlib FFI/native binding can expose Z_STREAM_END and total/remaining
input, but ffi2.2.0 alone is only binding machinery, not a codec. It would add
ABI/library packaging and ownership work. The [zlib primary manual](https://zlib.net/manual.html)
describes the required status/counters. Prefer the existing Android API here;
no binding, package installation or codec fork was attempted.

## Evidence and gates

3310 host JDK checks exercise valid fixed/dynamic/stored DEFLATE blocks, every
truncation prefix, trailing/concatenated streams, missing BFINAL, exact output
limit, wrong declared sizes, input limits, long empty-block input, cancellation
and deterministic20-second boundaries.113 focused Dart tests verify response
proofs, stale/cancelled requests, preview CRC/order, explicit Save and rollback/
reopen. Linux CI runs the exact standard-library helper and compiles Android.
These are host/compile gates, not Android execution or actual backup/restore.
Full account ZIP, membership and synchronization remain separately deferred.
