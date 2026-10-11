# Musify local compatibility changes

Based on upstream youtube_explode_dart 3.1.0; original BSD license retained.
Upstream comparison: 44a39a65d8e274806247d52af8f0bacd77691d38.

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
