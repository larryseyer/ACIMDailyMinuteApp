# continue.md

LIVE: first item under REVIEW in `todo.md` — iPad portrait video
stretches 1920×1080 PlayerArt; there is no portrait art.
Then the rest of REVIEW, newest first. Fix that list in this chat.
HEAD is on `main`. Work on `main` only. No feature branch.
No subagent. No worktree.

REMEMBER THIS: ALWAYS WORK ON MAIN — NO BRANCHES EVER UNLESS THE USER
ASKS FOR THEM.

The design file is the spec. Visual intent:
`docs/design/2026-09-11-ios-presentation.html`. The Design Plan wins
wherever they differ. Do not build from
`untracked/ACIM Daily Minute — iOS presentation proposal.html` (it still
renders Lesson 84 as `W·r2·84`). Plan mode at the top of each fix,
present the approach, wait for approval, then edit.

## REVIEW — this chat

Newest first. Do not start screenshots. Do not pick up step 10.

- iPad portrait video: landscape `PlayerArt` / `PlayerArtLesson` /
  `PlayerArtText` (all 1920×1080) are stretched to fill
  `TVPlayerView.playerCanvas`. No portrait asset exists.
- Apple TV: Today text size looks small.
- Mac: sidebar is ink blue, reading pane is black; one global ground,
  or a setting for black vs blue.
- Mac: playing a video has no way to exit.

Do not invent a second TV player. Fix the stretched art in the existing
canvas. Do not invent TTS. Do not host MP4s. Do not pull YouTube on
tvOS. Do not touch the models, the feeds, the backup format, the
annotation keys, the pipeline, or `prd.json`. Do not raise the iOS 17
floor. The design file's "stay on `ralph/…`" line is void — `main` only.

## NEXT — after REVIEW is gone

Step 10 copy is already rewritten and uncommitted:
`APP_STORE_LISTING.md`, `store-support-page.md`, `tools/verify_copy.sh`.
Gate: `tools/verify_copy.sh`. Stage those three only — `README.md`,
`prd.json`, and `progress.txt` are dirty and are not that commit. Do
not `git add .` / `./bu.sh`.

Screenshots still wait on Larry seeing the REVIEW fixes and approving
every app. Then `tools/capture_store_screenshots.sh`. Keep every
screenshot-tab string accepted.

## Done when

1. Every REVIEW item deleted from `todo.md` because it is fixed in the
   tree, not because it was checked off
2. `./build.sh` green for all four platforms
3. No `TODO`/`FIXME`/stub, no dead code
4. Commit on `main` and push. Single-line `fix:` / `feat:` message,
   then `git push origin main`
