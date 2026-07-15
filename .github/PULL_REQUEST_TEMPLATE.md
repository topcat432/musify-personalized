## Outcome

<!-- What user or repository outcome does this PR produce? -->

## Scope

<!-- Describe the coherent task and explicitly name anything intentionally out of scope. -->

- Base branch and SHA:
- Head branch and SHA:
- Active writer/owner:
- Exact files changed:

## Change type

- [ ] Documentation or agent workflow only
- [ ] Product behavior
- [ ] UI or motion
- [ ] Import, matching, review, or routing
- [ ] User data, Hive schema, migration, backup, or restore
- [ ] Android identity, build, signing, updater, or release workflow

## Safety and data impact

<!-- State the impact on existing libraries, Liked Songs, playlists, import state,
exclusions, settings, backups, and installed package identities. Use “none” only
after checking. -->

- Data/schema implications:
- Migration and rollback behavior:
- Cancellation, partial-failure, and restart behavior:
- Personal data or secrets added: none / explain blocker
- Destructive action required: no / stop and request approval

## Verification

<!-- List exact commands and exact results. Do not write only “tests pass.” -->

| Check | Exact command or manual procedure | Result |
|---|---|---|
| Formatting/diff hygiene |  |  |
| Targeted tests |  |  |
| Analyzer |  |  |
| Full tests |  |  |
| Build/workflow checks |  |  |

Verification level for each relevant claim:

- [ ] Merged (only after merge)
- [ ] CI-verified on the exact head
- [ ] Phone-verified on the exact build
- [ ] Unverified gaps are listed below

## Visual review

<!-- For UI work, cover standard/compact sizes, themes, long or missing content,
all states, keyboard/safe-area/mini-player overlap, motion interruption, and
reduced motion. Attach or link relevant golden evidence. Use “not applicable”
with a reason for non-UI changes. -->

- Visual review performed:
- Golden/widget coverage:
- Remaining device-specific gaps:

## Release impact

<!-- The only approved user-facing production path is
.github/workflows/signed-release.yml. Opening this PR does not authorize a
release. -->

- Package/signing/version impact:
- Updater or manifest impact:
- Release action requested by this PR: none / separately approved by Daniel

## Contradictions, risks, and unknowns

<!-- Make stale docs, assumptions, unavailable external state, and real-device
gaps explicit. -->

## Reviewer checklist

- [ ] The exact final head is under review.
- [ ] Product and data invariants are preserved.
- [ ] No personal fixtures, backups, signing material, or secret values entered Git.
- [ ] Unresolved and permanently excluded states remain distinct where relevant.
- [ ] Routing/import behavior is resumable and idempotent where relevant.
- [ ] UI follows `docs/VISUAL_SYSTEM.md` where relevant.
- [ ] Required checks pass and actionable review threads are resolved.
- [ ] PR approval is not treated as authorization to merge, enable auto-merge,
      sign, release, change settings, or touch production; Daniel must direct
      those actions separately.

## Handoff

- Behavior changed:
- Tests run and exact results:
- Known risks/unverified behavior:
- Review status:
- Single next action:
