# Musify local compatibility changes

Based on upstream youtube_explode_dart 3.1.0; original BSD license retained.
Upstream comparison: 44a39a65d8e274806247d52af8f0bacd77691d38.

2026-10-11 follow-up: retain only the User-Agent already sent by the request
that resolves a stream, without changing a client profile or copying cookies,
visitor identifiers or authorization. Weak stream-object associations preserve
provenance across extractor instances; unknown/serialized objects return no
context. Availability and length probes, finite download requests and fragments
receive that existing header. A permitted non-403 refresh carries its current
stream object and header into subsequent transient retries instead of pairing
the new header with an older URL. Actual 403 remains terminal. Tests use owned
MockClient media, never repeated denied endpoints. App-level native playback and
exact-URL derived-cache provenance are implemented outside this vendored package.

2026-10-11: manifest availability uses GET with Range bytes=0-0 instead of HEAD.
Retained paired evidence showed HEAD 403 and ranged GET 206 for the same URL.
The signed URI, default client configuration and authentication are preserved.
The response body is cancelled, including ignored-Range responses. Only 200/206
counts as availability; this is never complete-playback proof. A real HTTP 403
is terminal for retries, manifest client fallback and download URL refresh.
No denied URL is retried
to validate this change; tests use local MockClient responses.

Download requests use the standard case-sensitive GET method instead of the
upstream lowercase get token. This was exposed by the download fixture; it does
not explain the prior native failures, whose bounded source already used GET.
Throttled download ranges are clamped to the actual remaining stream length;
the 16-byte fixture previously requested bytes 0-10379934 instead of 0-15.
The native bounded source already performed this clamping.
