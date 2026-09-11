# continue.md

LIVE: `2026-09-11-Design_Plan.md` step 8 — iPad and Mac `NavigationSplitView`;
the two questions in §O.
Work on `main` only. No feature branch. No subagent. No worktree.

REMEMBER THIS: ALWAYS WORK ON MAIN — NO BRANCHES EVER UNLESS THE USER
ASKS FOR THEM.

NEXT after that: step 9, Apple TV, Watch, widgets.

The design file is the spec. Visual intent:
`docs/design/2026-09-11-ios-presentation.html`. The Design Plan wins
wherever they differ. Do not build from
`untracked/ACIM Daily Minute — iOS presentation proposal.html` (it still
renders Lesson 84 as `W·r2·84`). Plan mode at the top of the numbered
step, present the approach, wait for approval, then edit.

## Step 8

iPad and Mac leave the phone's three tabs. `NavigationSplitView`: sidebar
holds Today, the four books, and Saved; the detail column is the reading.
No tab bar, no `ACIMTabBar` on these two. Mac keeps its 420pt minimum
width. Revisit `ReadableContentWidth` — 672pt is macOS-only today and
the iPad needs its own answer once a sidebar takes width.

The two remaining decisions are in §O. Decide them against a running
build, not on paper. They are the only two. Do not invent a third.

Spec: §5 step 8, §S7 iPad and Mac, §O.
Mockup: intent only; sidebar chrome is specified here, not in the drawing.

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
