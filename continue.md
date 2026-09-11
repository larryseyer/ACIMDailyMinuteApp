# continue.md

LIVE: `2026-09-11-Design_Plan.md` step 3 — the practice sheet. Work on
`main` only. No feature branch. No subagent. No worktree.

REMEMBER THIS: ALWAYS WORK ON MAIN — NO BRANCHES EVER UNLESS THE USER
ASKS FOR THEM.

NEXT after that: step 4, the Course tab.

The design file is the spec. Visual intent:
`docs/design/2026-09-11-ios-presentation.html`. The Design Plan wins
wherever they differ. Do not build from
`untracked/ACIM Daily Minute — iOS presentation proposal.html` (it still
renders Lesson 84 as `W·r2·84`). Plan mode at the top of the numbered
step, present the approach, wait for approval, then edit.

## Step 3

The practice card on Today opens a sheet. Surface only. Write no
scheduling logic.

Spec: §5 step 3, and the "Practice card and sheet" paragraph in §S5.
Mockup: the second Today figure in `docs/design/`.

Card already exists: `Views/Today/PracticeCard.swift` (app target only,
`#if !os(tvOS)`). It is not tappable. Make it open the sheet. Do not
redraw the card.

New file: `Views/Practice/PracticeSheet.swift` — app target only, not
tvOS. New directory, so a new `PBXGroup`. Confirm unused serials with
`python3` against `project.pbxproj` before taking one. File-ref
`AA000002995` is free. App build-file `AA000001NNN` serials 980–999 are
taken; use a 24-hex build-file UUID. Then `./clean.sh`.

Sheet, from the spec:

- `.sheet` at radius `Metric.sheet` (26)
- grab handle 38 × 5, `.tertiary` at 50%
- title "Practice for Lesson N" at 23 serif
- cadence sentence at 13 `.secondary` from
  `PracticePlanner.cadenceSummary`
- one row per slot from `PracticePlanner.slots(for:in:)` with
  `PracticeReminderService.window()`: time in gold serif in a 66pt
  column, label 14 with an 11.5 `.tertiary` sub, 8pt dot trailing
- past slots at 40% opacity; the next slot's dot is gold with a 4pt
  gold-22% ring
- leading gold action "Begin the evening period" (or whichever slot is
  next); trailing settings icon pill opens the existing practice
  settings (`SettingsView` practice section via
  `.openSettingsRequested`, or present `SettingsView` — do not rewrite
  Settings)
- slot copy from `PracticePlanner.Slot.sessionName` and `.minutes`.
  `title(lesson:)` and `body(record:title:)` are `fileprivate` reminder
  strings — do not promote them. Do not invent a timer.

The spec does not name what "Begin the … period" does. Present that in
plan mode. Do not invent a timer. A lesson reading
(`LessonRef`, `presentsVideo: false`) is the only destination already
on Today's stack.

Data: `PracticePlanner.plan(_:)`, `.slots(for:in:)`,
`.cadenceSummary(_:)`, `WorkbookPracticeCatalog.record(for:)`,
`PracticeReminderService.currentLesson()` / `.window()`. Same keys
Settings already uses.

## Done when

1. `./build.sh` green for all four platforms
2. Stay-green gates in §V still green, plus `./tools/verify_today.sh`
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
