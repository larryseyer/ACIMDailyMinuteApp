# continue.md

LIVE: `2026-09-11-Design_Plan.md` step 7 — Saved as one filtered stream.
Work on `main` only. No feature branch. No subagent. No worktree.

REMEMBER THIS: ALWAYS WORK ON MAIN — NO BRANCHES EVER UNLESS THE USER
ASKS FOR THEM.

NEXT after that: step 8, iPad and Mac `NavigationSplitView`; the two
questions in §O.

The design file is the spec. Visual intent:
`docs/design/2026-09-11-ios-presentation.html`. The Design Plan wins
wherever they differ. Do not build from
`untracked/ACIM Daily Minute — iOS presentation proposal.html` (it still
renders Lesson 84 as `W·r2·84`). Plan mode at the top of the numbered
step, present the approach, wait for approval, then edit.

## Step 7

Three segmented lists become one filtered stream. Filter chips at the
top — All / Highlights / Notes / Bookmarks. A highlight is shown as a
highlight; a note sits under its passage in italic. Orphaned highlights
render at 50% opacity. Export stays in the toolbar. Order is when the
reader marked them, newest first.

Spec: §5 step 7, §S5 Saved.
Mockup: the Saved figure in `docs/design/`.

Confirm unused serials with `python3` against `project.pbxproj` before
taking one. App build-file `AA000001NNN` serials 980–999, 806–809,
824–827 are taken. New directories need a new `PBXGroup`. Then
`./clean.sh`.

## Done when

1. `./build.sh` green for all four platforms
2. Stay-green gates in §V still green
3. No `TODO`/`FIXME`/stub, no dead code
4. Anything deferred in `todo.md` as one sentence
5. Commit on `main` and push. Stage explicitly — do not `git add .` /
   `./bu.sh`: `APP_STORE_LISTING.md`, `README.md`, `prd.json`, and
   `progress.txt` are dirty and are not this step. Machine-wide
   commit-discipline: single-line `feat:` / `docs:` message, then
   `git push origin main`. Dropbox zip is optional after the push.

Do not pick up any other item in `todo.md` until step 10 is on the
devices. Do not rebuild `TVPlayerView`. Do not invent TTS. Do not host
MP4s. Do not pull YouTube on tvOS. Do not touch the models, the feeds,
the backup format, the annotation keys, the pipeline, or `prd.json`.
Do not raise the iOS 17 deployment floor. The design file's "stay on
`ralph/…`" line is void — `main` only.
