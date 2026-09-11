# continue.md

LIVE: `2026-09-11-Design_Plan.md` step 4 — the Course tab. Work on
`main` only. No feature branch. No subagent. No worktree.

REMEMBER THIS: ALWAYS WORK ON MAIN — NO BRANCHES EVER UNLESS THE USER
ASKS FOR THEM.

NEXT after that: step 5, the reading and the medium band.

The design file is the spec. Visual intent:
`docs/design/2026-09-11-ios-presentation.html`. The Design Plan wins
wherever they differ. Do not build from
`untracked/ACIM Daily Minute — iOS presentation proposal.html` (it still
renders Lesson 84 as `W·r2·84`). Plan mode at the top of the numbered
step, present the approach, wait for approval, then edit.

## Step 4

The structural step. Read §E6 before writing a line — every deep link,
notification observer, debug hook, onboarding page and mini-player
predicate that breaks is fixed here, not deferred. §E7 lists the gates
that will correctly turn red; rewrite them in this step with the reason
in the commit message. Do not contort the new code to satisfy them.

Spec: §5 step 4, §S5 Course contents / a spine, §E6, §E7.
Mockup: the Course figures in `docs/design/`.

- Delete `Views/Lessons/LessonsView.swift`, `Views/Listen/ListenView.swift`,
  `Views/Archive/ArchiveView.swift`. Replace with
  `Views/Course/CourseView.swift` plus one spine per book.
- Three `@State CourseShelf` properties become one. Tabs drop from five
  to three. `ACIMTabBar` replaces the system tab bar and `MacBottomTabBar`,
  which retires `TabBarHeightReader`.
- Delete `Views/Listen/LiteYouTubeCard.swift` (no remaining call sites).
- Rewrite onboarding here, not in step 10.

Confirm unused serials with `python3` against `project.pbxproj` before
taking one. App build-file `AA000001NNN` serials 980–999 are taken;
`AA000002995` is now `PracticeSheet.swift`. New directories need a new
`PBXGroup`. Then `./clean.sh`.

## Done when

1. `./build.sh` green for all four platforms
2. Stay-green gates in §V still green; §E7 gates rewritten, not left red
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
