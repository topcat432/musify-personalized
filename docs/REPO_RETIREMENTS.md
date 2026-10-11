# Retired Musify work — 2026-10-11

Only protected master and agent/local-stable-consolidation remain. Only draft PR #23 is open. Cleanup changed refs/review state, not integration or releases.

Before retirement, every original branch/tag and 22 PR heads were preserved in musify-pre-cleanup.bundle, cloned back with identical refs and passed git fsck --full. Bundle SHA-256: 10eb04fe3319d31ac5bc6af08862f8c923ae0eb3524cdd10d9bdf75c325e325a (40,945,016 bytes). The task-local/Library bundle and accompanying inventory remain outside this checkout. Keep that recoverable artifact; GitHub old refs alone are not the recovery plan.

PR dispositions: #4 already contained in master; #7 divergent older stack preserved, selected-alternative P2 still roadmap work; #19 older audit superseded; #20 exact foundation retained by #23; #21 intent carried with both P1 defects corrected; #22 useful Home/shell/accessibility delta deferred at f14a73fb7b9b56682d72fa9868a9dec3ffb1a2ac. All six closed unmerged with factual recovery comments. #22 is not integrated/shipped.

Every deletion used fresh head/protection/activity checks and an exact-SHA lease. No protected/default/active branch, tag, release or artifact was deleted. No existing personal checkout was reset.

| Retired branch | Exact preserved head | Related PRs |
|---|---|---|
| agent/agent-workflow-bootstrap | 67119362cab99fc07c05f817747243c79fa5faa0 | #18 |
| agent/baseline-apk-ci | b47c8aa22fdda571e0a5e63f73dd01828e67da92 | #1 |
| agent/data-recovery-hardening | 61295c8df4cde5596a3d9076883e5b5d7903d81a | #4 |
| agent/dialog-count-review-fix | e3382795cc9c962270780b31fb1e7115640784d8 | #12 |
| agent/exclude-track-motion-polish | ee62c84075429a0ca7b715fafb65ca6446250806 | #17, #15 |
| agent/fix-shuffle-queue-state | 76201eeb409594117c873716a41f7ebc6dd3224d | #21 |
| agent/full-visual-overhaul | 90babeb5e0f833d99f1d33aa6429ba6bc1a96384 | #19 |
| agent/full-visual-overhaul-master | 395ecace3da567ef1437c7a2229252ef84ee94de | #20 |
| agent/import-destination-roadmap | 023f3cb153a0ecdff74b906d97bfbd71c0d85649 | #9 |
| agent/import-destination-routing | fa41c3e4675b21cba2e5d78c0942f12e7a713ff8 | #10 |
| agent/import-destination-visual-qa | 22e672e4b78fc1d6e8255b673e410275fd9e3aa5 | #11 |
| agent/monotonic-production-version-fix | 8725406e54d1118fe3eb0241d045ca1182f3b58a | #14 |
| agent/personalized-updater | 5bb4add49556629a143c5dd927edf642fa69fe44 | #16 |
| agent/phase-4a-shell-home | f14a73fb7b9b56682d72fa9868a9dec3ffb1a2ac | #22 |
| agent/quick-review-visual-overhaul | 9a643e7efa0be8a5e1ffaba87a2ab9b3c818ff1b | #8 |
| agent/review-sprint-overhaul | b6fee783a1a91389ddffd0f78d89dbcc70dab329 | #7 |
| agent/signed-candidate-20260713 | 8d138166973620714ee3bd9073679da9d815932c |  |
| agent/signed-release-gate | e74e3e5d9a6cea9cce68fe569294fe7335b84e0d | #5 |
| agent/signed-release-hardening | 739a4681feec1b50ca801f80d6990bd351da7dbd | #6 |
| agent/spotify-import-foundation | f4d6ac6af452423fbe9669b70b3f3104b1e3de6a | #2 |
| agent/spotify-track-matching | 9c2027323d4f59461b379c4f491d91ba6e9c2e84 | #3 |
| agent/stream-backup-memory-fix | b3ff8bb8dcc6014c628095bacd315f2afc641b24 | #13 |
| preview/latest-debug | 0ea1b44dad777efd03c819becd31acffa996427f |  |
| release/production-candidate-20260713 | 449535440e2829b1c8caed3c9fa75a7d9ce296cd |  |

Recover into a fresh local review checkout from the bundle, select the exact preserved ref/SHA above, then compare with current master and #23 before proposing work. Do not blindly republish an old branch/workflow or merge deferred UI to simplify history. Follow CONTRIBUTING.md and obtain authorization for any remote restoration.
