# continue.md

LIVE: `2026-09-11-Design_Plan.md` step 10 — `APP_STORE_LISTING.md`,
support page, screenshots.
HEAD is on `main`. Work on `main` only. No feature branch.
No subagent. No worktree.

REMEMBER THIS: ALWAYS WORK ON MAIN — NO BRANCHES EVER UNLESS THE USER
ASKS FOR THEM.

The design file is the spec. Visual intent:
`docs/design/2026-09-11-ios-presentation.html`. The Design Plan wins
wherever they differ. Do not build from
`untracked/ACIM Daily Minute — iOS presentation proposal.html` (it still
renders Lesson 84 as `W·r2·84`). Plan mode at the top of the numbered
step, present the approach, wait for approval, then edit.

## Step 10

Copy and store assets. Onboarding is not this step — it was rewritten
in step 4. Do not add a visionOS platform.

- `APP_STORE_LISTING.md` — already dirty (promotional text). That diff
  belongs here. Gate: `tools/verify_copy.sh`.
- Root `store-support-page.md`. Same gate. The support page is already
  on the site; this step is the repo copy matching the finished design.
- Remake every store screenshot against the finished redesign.
  `tools/capture_store_screenshots.sh` plus `applyScreenshotTabIfRequested()`.
  Keep every screenshot-tab string accepted.

`README.md`, `prd.json`, and `progress.txt` are dirty and are not this
step. Stage explicitly — do not `git add .` / `./bu.sh`.

After this step the batched device pass in §V runs once: iPad 18.1,
macOS standalone, Apple TV simulator, Watch simulator and all three
widget sizes, physical iPhone 11 Pro Max. Both appearances. That pass
is part of finishing the redesign, not a later todo.

## Done when

1. `./build.sh` green for all four platforms
2. `tools/verify_copy.sh` green, stay-green gates in §V still green
3. No `TODO`/`FIXME`/stub, no dead code
4. Anything deferred in `todo.md` as one sentence
5. Commit on `main` and push. Machine-wide commit-discipline: single-line
   `feat:` / `docs:` message, then `git push origin main`. Dropbox zip is
   optional after the push.

Do not pick up any other item in `todo.md` until step 10 is on the
devices. Do not rebuild `TVPlayerView`. Do not invent TTS. Do not host
MP4s. Do not pull YouTube on tvOS. Do not touch the models, the feeds,
the backup format, the annotation keys, the pipeline, or `prd.json`.
Do not raise the iOS 17 deployment floor. The design file's "stay on
`ralph/…`" line is void — `main` only.
