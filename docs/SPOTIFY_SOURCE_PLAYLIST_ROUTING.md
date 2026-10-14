# F04-D source-specific resolved-song routing,2026-10-14

Status: host candidate implementation; full source recreation/synchronization
and signed/native qualification remain separate.

A saved source-review page offers Route resolved songs. This opens the existing
Choose Destination flow and its explicit Review/Transfer confirmation. All,
first-N, individual and newly-resolved selections are constrained to that source's
resolved recordings, in first membership-occurrence order. Chosen recording
alternatives remain unchanged. Pending and unsupported memberships stay retained
and are disclosed separately. Repeated resolved memberships stay in source data;
ordinary destination routing transfers each recording once. This does not claim
exact recreation of intentional destination repetitions or empty/unsupported-only
playlists.

Source scope uses a validated Spotify playlist URI when available, otherwise
importSessionId plus source position. It never guesses identity from the name. Supplied playlist ID/URI conflicts reject before saving or assigning a scope.
New destination reuse requires both the explicit scope key and chosen title;
same-name sources and unrelated existing playlists are not silently merged.
Existing destinations still require explicit selection and only append new songs.
Old whole-file imports keep their behavior and do not adopt scoped targets.

Every source preview records a SHA256 membership fingerprint. Session, recording
choices and membership are revalidated before destination writes. A membership
change after a destination write retains actual destination/source data and marks
tracking unverified rather than certifying a newer source snapshot. Last-successful
resolved-recording snapshots continue covering the full import independently of
which source subset was selected.

Destination write failures restore only the writer's exact staged value, including
original key absence. A newer independent destination edit is never overwritten.
Pending/unverified audit markers preserve uncertainty; explicit retry remains
idempotent. No source membership, unresolved work or existing library is removed.
Optional target scope/audit fields use existing maps; no adapter, dependency,
backup format or permission change. Missing fields retain legacy behavior.

Acceptance includes chosen-alternative/source order, same-name separation,
existing library preservation, repeat/restart idempotence, stale rejection,
metadata admission failure, partial-write rollback, newer-edit preservation,
saved-file backup restore/reopen and explicit widget confirmation/Cancel.
Strict visual references/comparators remain unchanged; exact-source CI and native
picker/transfer/backup/cold-restart proof are required separately. The immutable
signed c249 baseline is unchanged and contains none of F03/F04.
