# F02 supported saved-track JSON contract

## Scope and evidence

Roadmap§5 names YourLibrary.json but did not previously prescribe JSON field
mapping. This adapter deliberately supports one observed compatibility variant:
Spotify describes Your Library as saved songs plus albums, creators and other
entity types in [its data guide](https://support.spotify.com/us/article/understanding-your-data/).
The concrete four-field track object and section names are represented by a
[pinned public synthetic compatibility fixture](https://github.com/winters27/octo/blob/1de1d3aeaa01263ede314a278d8eea56a1b8989a/parity/fixtures/make-import-fixtures.py).
No personal fixture values or third-party code were copied. This is explicit
current recognition, not a claim that the earlier roadmap specified these keys
or that every Spotify JSON variant is supported.

The separately inspected [caseychu/spotify-backup producer](https://github.com/caseychu/spotify-backup/blob/8507cceefa155f47a54199db50a2d513c8b95549/spotify-backup.py)
exports named playlists/nested Web API track records and albums. That format is
rejected here. Preserving its membership, multiple sources and albums requires a
separate source model/design. ZIP extraction additionally needs bounded
inflation/entry/path qualification and an explicit runtime dependency decision;
archive is currently only transitive. Neither is implemented merely to stay busy.

## Exact recognized input

- Select a .json file, case-insensitive. It must contain UTF-8 JSON; BOM allowed.
- Root is an object with a tracks array. Other allowed sections are albums,
  shows, episodes, bannedTracks, artists, bannedArtists and other; each is an array.
  Unknown root fields, playlists and other formats reject before Save.
- Track entries contain only artist, track, album and uri. Artist/track must be
  nonempty strings. Album/URI may be absent or null, otherwise must be strings.
  A nonempty URI must pass the existing Spotify-track identity validator.
- Valid songs retain array order and one-based logical track positions, including
  gaps for rejected entries. Unsupported/missing/wrong-type entries are shown as
  rejected source positions. No duration, ISRC or original added-date is invented.
- Non-track sections are counted and visibly disclosed in preview. This imports
  saved songs only; album/follow/podcast and blocked-item preferences stay in the
  original export and are not migrated or mapped to Musify exclusions.
- Limits:8MiB actual JSON bytes,10,000 track entries,24 structural levels.
  Duplicate keys, including escaped aliases, malformed UTF-8/JSON and excessive
  limits reject. Brackets inside quoted strings do not count as nesting.

## Read, save and cancellation behavior

The picker uses its existing native cached-file stream facility, not withData.
The application checks declared size before subscribing and actual accumulated
bytes while reading. A monotonic20-second read deadline gives retryable feedback;
closing the page cancels the owned reader. Native picker caching is the existing
plugin's behavior; these are application-reader limits, not a proven pre-copy
native storage quota. JSON text never supplies filesystem paths. There is no
archive extraction, account service, OAuth, lookup or provider request.

Preview does not write. Picker cancellation, unsupported input or closing the
page leaves the previous staged session/completed decisions untouched. Explicit
Save uses the existing four-key controlled replacement, overlap guard and exact
rollback. It stores the ordinary recording metadata/file name and format string,
not new Hive/backup/journal fields. Disclosure notes are transient preview UI.
CSV/TSV behavior and metadata validation remain covered; no matching score or
routing algorithm changes. Old/partial state and retry/reopen remain supported.

## Separate optional acceptance

| Row | Host qualification | Remaining native gate |
|---|---|---|
| F02-A | Exact contract, Unicode/BOM, URI/order/rejection, size/depth/duplicate/malformed cases | Android select/read supported .json/.JSON input and inspect compact disclosure |
| F02-B | Declared/actual streamed limits, real reader cancellation and deadline; widget cancellation signal/no write | Back/picker cancellation and cache/stream/deadline behavior on disposable5558 |
| F02-C | Explicit preview/save, prior completed source unchanged after rejection, partial-write rollback and independent Hive reopen | Actual save/process/full cold restart, selected routing and backup/reopen/re-export semantics |
| F02-D | No persistent schema/dependency/platform/workflow migration; separate additive commit after F01 | Pin any feature APK/source separately; sealed24a contains neither F01 nor F02 |

All current baseline and F01 gates remain independent in
[RELEASE_VERIFICATION_QUEUE.md](RELEASE_VERIFICATION_QUEUE.md). Source and CI
verification do not prove Android data safety or qualify a phone deployment.
No phone, merge, signing or publication is authorized by this adapter.
## Host validation before commit

76 focused parser/reader/widget/session/legacy/rollback/backup identity checks PASS; clean analysis and522 aggregate tests PASS. Both Windows strict suites remain FAIL16+24 with all40 actual images byte-exact to the existing control; no golden/comparator change. Standalone real-reader cancellation/deadline and widget cancellation-signal/no-write checks are distinct; the attempted combined stream/widget fake-clock fixture stalled and was replaced with those bounded checks. No Android cancellation pass is claimed. Exact-source Linux CI follows the additive push.
