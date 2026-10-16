# Pinned stream completion patch

Based on the existing pub.dev just_audio 0.10.6 package, with its Apache-2.0
license and native sources retained. No native media, range, authentication,
network policy, headers, client identity or decoder behavior changes.

Only the StreamAudioSource HTTP writer changes: observe both response.done and
close errors, cancel a failed/disconnected source subscription, and retain a
truncated response as failure. Previously stream errors were discarded and two
HTTP completion futures could escape as unhandled content-length exceptions.
App-owned source failure/cancellation and user-visible errors live in Musify.
Synthetic real-loopback tests cover valid, truncated and cancelled responses.
Retire this local patch when a pinned upstream version supplies the same fix.

The writer also reports an optional structured failure to its StreamAudioSource:
source/request/write/responseDone/close phase, declared/written bytes, original
cause and stack, and the preceding source failure when a later HTTP close fails.
Diagnostics never interpolate raw cause messages, URLs, headers or audio tags.
The app owns the allowlisted originating HTTP/range summary and the same-error
terminal guard. The default callback is silent; an observer cannot replace a
stream failure. No padding, successful short response, native decoder change,
provider retry or new proxy is introduced by this observability patch.
