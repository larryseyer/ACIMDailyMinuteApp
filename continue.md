# continue.md

LIVE: `2026-09-11-Design_Plan.md` step 9 — Apple TV, Watch, widgets.
HEAD is `9c1bbae` on `main`. Work on `main` only. No feature branch.
No subagent. No worktree.

REMEMBER THIS: ALWAYS WORK ON MAIN — NO BRANCHES EVER UNLESS THE USER
ASKS FOR THEM.

NEXT after that: step 10, `APP_STORE_LISTING.md`, support page, screenshots.

The design file is the spec. Visual intent:
`docs/design/2026-09-11-ios-presentation.html`. The Design Plan wins
wherever they differ. Do not build from
`untracked/ACIM Daily Minute — iOS presentation proposal.html` (it still
renders Lesson 84 as `W·r2·84`). Plan mode at the top of the numbered
step, present the approach, wait for approval, then edit.

## Step 9

tvOS, Watch, and the three widget sizes take the redesign tokens. Do not
rebuild `TVPlayerView`. Do not invent a second type table.

tvOS `ContentView` is already two system tabs (Today · Course). Saved is
absent. No medium band, no `ACIMTabBar`. Select still opens `TVPlayerView`.
What is left is the look: citation, masthead, spine highlight. `Metric` is
already ×1.6 on tvOS.

Watch is Today only. `WatchContentView` is still a `List` of story rows.
§S7: date 17 serif, passage 15 serif, citation 11 serif gold. Those sizes
are already `acimMasthead` / `acimReading` / `acimAddress` under
`#if os(watchOS)` in `Utilities/ACIMType.swift`. `Metric` is already ×0.7.
Restyle the surface; do not change how it chooses the minute or the lesson
(`CorpusFallback.isStale`, phone-pushed lesson only).

Widgets: `SmallWidgetView`, `MediumWidgetView`, `LargeWidgetView` still use
`.callout` / `.caption2`. Same masthead / passage / citation stack. Small:
three lines of passage over a citation. Medium: passage with the lesson
trailing. Large: masthead, passage, citation, next practice slot. Keep
`widgetURL(acimdailyminute://today)` on all three. `ACIMColors` already
compiles into both widget extensions.

Spec: §5 step 9, §S7 Apple TV / Watch / widgets, §S2 Watch sizes.
Mockup: iPhone intent only.

Confirm unused serials with `python3` against `project.pbxproj` before
taking one. App build-file `AA000001NNN` serials 980–999, 806–809,
824–828 are taken. New directories need a new `PBXGroup`. Then
`./clean.sh`.

## Do not reopen step 8

§O is closed, against a running iPad and Mac:

1. Sidebar is Today, the four books, Let it fall open, Saved — not three
   destinations.
2. iPad reading column clamps at 672 when the split sets
   `clampsReadableColumn`. Phone stays fill-parent. Gate:
   `tools/verify_ipad_reading_width.sh` (fill-parent battery plus clamp
   battery).

iPhone keeps three tabs via idiom `.phone`, not size class. iPad uses
`NavigationSplitView(columnVisibility: .constant(.all))`. Mac default
window is 960×740; below 720pt it collapses to the reading; minWidth stays
420. A restored `NSWindow Frame …ContentView…-1-AppWindow-1` of 500×900
will still open narrow — collapse handles that; delete that defaults key
only when you need to see the 960 default. `MacWindowWidthReader` is
AppKit and stays inside `#if os(macOS)`. The iOS/macOS split of
`splitView` is compile-time `#if os`, same target.

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
