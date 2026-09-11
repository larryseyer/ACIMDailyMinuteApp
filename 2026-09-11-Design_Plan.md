# ACIM Daily Minute — the iOS presentation redesign

**Date:** 2026-09-11 · **Status:** complete, not started · **Scope:** iPhone,
iPad, Mac standalone, Apple TV, Apple Watch, widgets.

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans. Enter plan
> mode at the top of each numbered step in §5, present that step's approach, and
> wait for approval before editing. Do not dispatch a subagent per step — later
> steps depend on earlier HEAD. Stay on `ralph/acim-3.9-to-5-finish-2026-04-14`.
> Do not merge to `main`. Do not create a feature branch.

---

## 0 · Before you start

You are picking this up with no prior context. Read this section, then the whole
document, before editing anything.

### Authority

**This file is the specification.** It is self-contained: every value, symbol and
file path needed to build the redesign is in here.

**Sources, in precedence order.** Where they disagree, the higher one wins.

1. **This file.**
2. The visual mockup at `docs/design/2026-09-11-ios-presentation.html` — open it
   (`open docs/design/2026-09-11-ios-presentation.html`); it has an Ink / Paper
   toggle at the top right. Drawn at 393 × 852, iPhone logical points, so its
   pixel values are SwiftUI points. **Use it to see the intent, not to resolve a
   question.** It is untracked (`docs/` is gitignored) and may drift. The places
   it is known to be wrong are listed in §E9.
3. Nothing else. `docs/superpowers/plans/2026-09-11-ios-presentation-redesign.md`
   was the earlier implementation draft; this file supersedes it. The browser
   save at `untracked/ACIM Daily Minute — iOS presentation proposal.html` is an
   earlier draft of the same mockup (it still has the `W·r2·84` citation error);
   do not build from it.

`continue.md` and `todo.md` point here. They do not add requirements.

### Repo and branch

`/Users/larryseyer/ACIMDailyMinuteApp`, branch
`ralph/acim-3.9-to-5-finish-2026-04-14`. That branch is several hundred commits
ahead of `main` and is the real trunk. Stay on it. Do not merge to `main`, do not
create a feature branch.

### Commands

| Command | What it does |
|---|---|
| `./build.sh` | compile-verifies iOS, macOS, watchOS, tvOS. Compile only — proves nothing about layout. |
| `./both.sh` | installs and launches on the iPad 10th-gen simulator (iOS 18.1) **and** the physical iPhone 11 Pro Max. |
| `./clean.sh` | removes `build/` and DerivedData. Run after every `project.pbxproj` edit. |
| `./bu.sh "message"` | `git add .`, commit, push to the current branch, write a dated Dropbox backup. This is how you commit. |
| `./tools/verify_*.sh` | the gates. §V says which must stay green, which you rewrite, and which are new. |

`docs/` is gitignored (`.gitignore:57`, "Internal planning docs (kept local, not
in public repo)"). Everything under it — including the mockup and the older specs
— is on disk but never committed. That is deliberate; the repo is public. Do not
`git add -f` and do not change the ignore rule. **This file lives at the repo
root and is tracked.**

### House rules

From the user's CLAUDE.md. These outrank convenience.

- Never leave a `TODO`, `FIXME`, `XXX` or a stub. Choose a sensible default and
  implement it fully.
- No dead code. If something stops being called, delete it in the same commit.
- Anything you cannot finish goes into `todo.md` as one sentence. Never defer
  silently.
- `continue.md` and `todo.md` are **forward-only**: no history, no "used to", no
  "now fixed". Git is the history. A finished item leaves without being asked.
- No emoji in docs.
- Stop and ask before any destructive act you were not explicitly told to do —
  `rm -rf`, force push, `git reset --hard`, branch delete. This outranks any
  keep-going instruction.
- Surface conflicts rather than averaging them. If this document and the code
  disagree, say so; do not split the difference.
- Commit finished work directly to the branch; pushes are pre-authorised. End
  every commit message with:

```
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01ANvEpsb2gAwPH1QZALxr9A
```

### Working style

**Plan mode per step.** Enter plan mode at the top of each numbered step, present
that step's approach, and wait for approval before editing — even though this
parent document is approved.

**Testing is batched.** Do not ask the user to confirm anything until a step is
fully implemented. Per step you run `./build.sh` and the gates; the simulator and
device passes happen once, at the very end, in the order in §V.

**Definition of done for a numbered step.** All five, or it is not done:

1. `./build.sh` green for all four platforms.
2. Every gate in §V green, or deliberately rewritten with the reason in the
   commit message.
3. No `TODO`/`FIXME`/stub introduced, no dead code left behind.
4. Anything deferred written into `todo.md`.
5. Committed with `./bu.sh`.

**When blocked.** Say so plainly, write it into `todo.md`, and finish everything
the blockage does not touch. Do not invent a decision this document did not make
— the genuinely open questions are listed in §O and they are the only ones.

---

## 1 · Why

The app holds everything it needs: 1,983 corpus passages, 365 lessons plus 22
introductions, 272 Text sections, 31 Manual sections, years of daily minutes,
audio and video where the publisher has made them, and the reader's own
highlights, notes and bookmarks. **Nothing in this plan adds a feature.**

Two problems in how that material is presented.

**Three tabs are one table of contents.** Since the 2026-09-10 four-shelf change,
Read, Listen and Video each open with the same Minute / Lesson / Text / Manual
picker, and each rebuilds its own calendar, lesson spine, chapter list and Manual
list. `LessonsView.swift` is 568 lines, `ListenView.swift` 585,
`ArchiveView.swift` 749 — about 1,900 lines presenting one book's contents three
times. The reader must decide whether they intend to read, hear or watch a
passage *before* they can go looking for it.

**The typography is Xcode's, not the book's.** `.headline`, `.caption2`,
uppercase eyebrows, and a single 12pt corner radius written as a literal fifteen
times. The serif is used for body text only. For an app whose entire product is a
passage of prose, the type is doing almost no work.

Two decisions were taken before planning: **1.0 slips** so the redesign is the
launch, and **the information architecture is fully open** — the "do not rename
tabs" constraint is lifted.

The outcome: one contents page instead of three; the passage presented as a page
rather than a card; the citation apparatus promoted from grey footnote to the
app's one recurring ornament; the practice schedule brought up out of Settings;
and all five platforms sharing one token and component layer.

The 2026-09-10 spec at `docs/superpowers/specs/2026-09-10-tab-ia-design.md` is
marked SUPERSEDED. Read it only for its content × experience model. Do not build
from its shape or its implementation order.

---

## 2 · What the design is

**Palette.** Both golds are unchanged. What changes is the ground: dark moves off
neutral black onto the ink blue of the book's cover, light becomes cool paper
rather than warm cream. Exact values in §S1.

**Type.** Two faces, both already on every Apple device. **New York**
(`.system(design: .serif)` — what `SelectableReadingText` already resolves)
carries everything editorial: passages, titles, book names, lesson numbers,
citations. **SF** is chrome only: tab labels, buttons, counts. No third face, no
monospace — the Manual stem currently set in `.acimCaption2.monospaced()` moves
to the citation treatment.

**The citation as furniture.** `T·1·3·2` in New York, gold, tabular figures,
separators dropped to 45% opacity. It appears in four places — under a passage,
in a running head, on the right of a search hit, under a saved mark — and
replaces the uppercase eyebrow that `CardHeaderRow` draws today. Arabic numbering
stays exactly as shipped.

**The passage has no card.** On Today and on every reading screen the prose sits
on the ground. Cards return only for things that genuinely are list items.

**The medium moves into the reading.** A Read / Listen / Watch band at the foot
of a reading is what lets three tabs become one. Unavailable mediums dim rather
than vanish, so the control never changes shape between passages.

---

## 3 · Information architecture

**iPhone — three tabs:** Today · Course · Saved, with a Now Playing bar docked
above the tab bar.

**iPad and Mac — `NavigationSplitView`.** The app has no split view anywhere
today; iPad runs the phone layout verbatim and Mac hand-builds a fake iOS tab bar
(`MacBottomTabBar`, a private struct inside `App/ContentView.swift:338`). The
sidebar carries Today, the four books, and Saved; the detail column is the
reading. Built in step 8. Until then, iPad and Mac follow the phone's three tabs.

**Apple TV — two tabs:** Today · Course. Saved stays absent. `TVPlayerView` keeps
the composed player and is **not rebuilt**. No medium band. No floating tab bar
— system `TabView` with two items.

**Watch — Today only,** restyled: dateline, passage, citation.

**Widgets** take the same masthead / passage / citation treatment at three sizes.

---

## 4 · How one look reaches five platforms

Shared tokens and shared components; per-platform **values**, never per-platform
designs. New files carry the system.

| File | Holds | Targets |
|---|---|---|
| `Utilities/Metric.swift` | spacing and radii, one platform multiplier | all five |
| `Utilities/ACIMType.swift` | the type scale, as `extension Font` | all five |
| `Views/CitationLabel.swift` | the gold citation apparatus | all five |
| `Views/ACIMColors.swift` *(exists; app + tvOS only today)* | the whole palette as Swift literals | **extend to all five** |
| `Views/ACIMTabBar.swift` | the floating tab bar | app only |
| `Views/Course/CourseView.swift` + spines | the one contents page | app + tvOS |
| `Views/Reading/MediumBand.swift` | Read / Listen / Watch | app only |
| `Views/Listen/NowPlayingView.swift` | the full player | app only |
| `Views/Practice/PracticeSheet.swift` | the practice schedule | app only |

"app" means the `ACIMDailyMinute` target, which builds both iOS and macOS.

### Reuse — do not reimplement any of these

- `Views/ReadingScaffold.swift` owns the band order for every reading in the app
  (header → title block → body → footer). It keeps owning it; only band
  *styling* changes, plus one new band. See §E5 for exactly what it reaches.
- `Utilities/MediaOverlay.swift` (`Hit.showsListen`, `Hit.showsWatch`) and
  `Utilities/VideoLibrary.swift` (`play(videoIDs:youtubeAvailable:)`) already
  decide what a row can do. They drive the medium band and the row pips.
- `Services/AudioManager.swift` drives playback, the lock screen and remote
  commands. It drives the full player.
- `Utilities/PracticePlanner.swift`, `Services/WorkbookPracticeCatalog.swift`,
  `Services/PracticeReminderService.swift` compute every practice slot. The
  practice sheet is a surface for them; **write no scheduling logic.**
- `Services/CorpusSearchService.swift` indexes ~690 records and returns headings
  separately from passage hits.
- `Utilities/ArchiveCalendar.swift` (`ArchiveCalendarState`),
  `Views/Archive/ArchiveCalendarView.swift`, `Utilities/MinuteSchedule.swift`
  (which also contains `enum FallOpen` at `:109` — "Let it fall open"),
  `Utilities/ListenLibrary.swift`, `Services/AudioDownloadStore.swift`,
  `Utilities/PlaybackHistory.swift` (which also contains `enum
  WorkbookCompletion` — `entries`, `isDone`, `markDone`, `toggle`),
  `Services/ReadingPositionStore.swift` (`position(for:)` keyed by
  `ReadingPosition.Book`), `Utilities/LessonSchedule.swift` (the
  "Available <date>" rule), `Services/AnchorResolver.swift` (returns `.exact`,
  moved, or `.orphaned`), `Utilities/ReadableContentWidth.swift`,
  `Utilities/Appearance.swift` (`Appearance.apply(_:)` at `:35`, the window-level
  light/dark override).
- `Views/TVPlayerView.swift` — the composed player, with factories for minute,
  lesson, segment, archived, workbookLesson, textSection and manualSection.

---

## 5 · Build order

Each step is shippable alone and must be in HEAD before the next starts. "In
HEAD" means the Definition of Done in §0 — build green, gates handled, committed.
It does **not** mean tested on a device; that is batched to the end (§V).

**1 · The token layer.** `Metric`, `ACIMType`, `CitationLabel`, the palette
moved into Swift, and `acimInk` applied at every screen root per §E3.

**Scope of step 1, exactly:** create the four token files, wire them into the
right targets, and apply the *ground colour* everywhere. **Do not retype existing
screens in this step.** Retyping happens where each screen is rebuilt — Today in
step 2, the spines in step 4, the readings in step 5. Step 1 ends with the app
looking identical except that it is sitting on ink instead of on system grey, and
with every token available and unused.

**2 · Today.** Dateline masthead, passage as a page, citation band, action row,
lesson card, practice card. `Views/Today/CorpusReadingCard.swift` takes the
identical treatment — it is Today's offline twin and the two must never disagree.

**3 · The practice sheet.** The practice card on Today opens it. Surface only.

**4 · The Course tab.** The structural step, and the only one that can go badly.
`Views/Lessons/LessonsView.swift`, `Views/Listen/ListenView.swift` and
`Views/Archive/ArchiveView.swift` are **deleted** and replaced by
`Views/Course/CourseView.swift` plus one spine per book. Their three separate
`@State CourseShelf` properties become one. Tabs drop from five to three.
`ACIMTabBar` replaces the system tab bar and `MacBottomTabBar`, which retires
`TabBarHeightReader`. Delete `Views/Listen/LiteYouTubeCard.swift` (no remaining
call sites). Rewrite onboarding here, not in step 10.

**Read §E6 before writing a line of this step.** It lists every deep link,
notification observer, debug hook, onboarding page and mini-player predicate that
breaks, all of which are fixed here rather than deferred. §E7 lists the gates that
will correctly turn red.

**5 · The reading and the medium band.** `ReadingScaffold` gains the band;
`CardHeaderRow` swaps the uppercase eyebrow for `CitationLabel`. All nine reading
surfaces change at once. The two Manual screens reconcile here (§E8).

**6 · Now Playing.** The full player. Absorbs controls currently spread across
`MiniPlayerView`, `ListenButton` and the Listen swipe actions.

**7 · Saved.** Three segmented lists become one filtered stream.

**8 · iPad and Mac.** `NavigationSplitView`. Revisit `ReadableContentWidth` —
672pt is macOS-only today and the iPad needs its own answer once a sidebar takes
width. The two remaining decisions are in §O; decide them against a running
build, not on paper.

**9 · Apple TV, Watch, widgets.** tvOS to two tabs; Watch and the three widget
sizes take the masthead treatment.

**10 · Copy and store assets.** `APP_STORE_LISTING.md`, the root
`store-support-page.md`, and every screenshot remade against the finished design.
**Onboarding is not step 10 work** — it is rewritten in step 4, because a gate
depends on it (§E6, §E7).

**Cleanup, folded in where it falls.** `LiteYouTubeCard` in step 4. The two
Manual screens in step 5. Both annotation key prefixes keep resolving.

---

## 6 · Constraints

- **Every new file needs hand-edited `project.pbxproj` entries**, and a file in a
  new directory needs a new `PBXGroup` as well. §E1 has the exact recipe with
  real UUIDs. Getting this wrong is the most common way this repo breaks.
- **iOS floor is 17.0** (`IPHONEOS_DEPLOYMENT_TARGET = 17.0`; macOS 14, tvOS 17,
  watchOS 10). The floating tab bar is therefore **hand-built**, not inherited
  from iOS 26. Do not raise the deployment target — the audience runs old
  devices. The mockup's closing note speculates about an iOS 26 floor; ignore it.
- **`./build.sh` is compile-only.** Green there proves nothing about layout.
- **A device build is not covered by a simulator build.** The arm64 slice fails
  Swift 6 checks the simulator passes.
- **Do not touch** the SwiftData models, the feeds, the Python pipeline,
  annotation keys, the backup format, or `prd.json`. No model migration is
  required by any step here.
- **Do not invent TTS, host MP4s, or pull YouTube on tvOS.**
- **Do not rebuild `TVPlayerView`.**

---

# S · The specification

Measurements are in SwiftUI points. The mockup is drawn at 393 × 852, iPhone
logical points, so its pixel values are these values.

## S1 · Colour

**Define the palette as Swift literals in `Views/ACIMColors.swift`. Do not add
colorsets.** §E2 has the reason — there are three asset catalogues and the Watch
and widget targets can see none of the app's. Compile `ACIMColors.swift` into all
five targets and have the existing names resolve to literals. Leave the existing
colorsets in `ACIMDailyMinute/Assets.xcassets` in place and unread; deleting them
is risk without payoff, and `AccentColor` is still read by the system.

| Token | Light (sRGB) | Dark (sRGB) | Role |
|---|---|---|---|
| `acimGold` | 0.541, 0.427, 0.102, α1 | 0.831, 0.686, 0.216, α1 | the stamping |
| `acimOnGold` | white | black | anything drawn on gold |
| `acimInk` | 0.914, 0.925, 0.945, α1 | 0.051, 0.075, 0.125, α1 | the ground |
| `acimSurface` | 1.0, 1.0, 1.0, α1 | 0.078, 0.110, 0.169, α1 | cards, bars, sheets |
| `acimRaised` | 0.875, 0.894, 0.925, α1 | 0.118, 0.157, 0.224, α1 | chips, pills, tracks |
| `acimRule` | `acimGold` α0.24 | `acimGold` α0.20 | the gold hairline |
| `acimHairline` | black α0.10 | white α0.09 | the neutral hairline |
| `acimCard` *(existing)* | 0.955, 0.955, 0.955, α1 | 0.110, 0.110, 0.110, α0.50 | retiring; keep until step 5 |
| `acimChip` *(existing)* | black α0.06 | white α0.08 | retiring; keep until step 5 |
| `acimMark` | `systemYellow` α0.28 | `systemYellow` α0.28 | the highlight wash |
| `acimFind` | `systemBlue` α0.22 | `systemBlue` α0.22 | the search spotlight |

**`acimHairline` is a real token and is not `.separator`.** SwiftUI's
`.separator` is roughly `#3C3C43` at 36% light and `#545458` at 65% dark —
visibly heavier and greyer than this design wants. Every neutral hairline in this
design uses `acimHairline`. The mockup's CSS variable of the same name carries
these exact values.

**Which hairline goes where.** Gold (`acimRule`) marks the three places that
carry an *address or a date*: the rule under Today's masthead, the rule under a
reading's running head, and the border of the Now Playing artwork. It is also the
border of a media pip that **has** that medium. The "Let it fall open" card uses
`acimRule` as drawn. Everything else — card borders, list row dividers, the tab
bar border, the Now Playing bar border, the medium band border, the search field,
the footer rule under a passage, and the border of a pip that is only a count —
is `acimHairline`.

**`acimMark` and `acimFind` are one value each, in both appearances.** These are
the shipped values, currently hard-coded at
`Views/SelectableReadingText.swift:335` (yellow) and `:345` (blue). Move them;
do not re-pick them, and do not give them a light/dark split. The mockup shows
different light-mode alphas for both — the mockup is wrong there.

**Text colour is semantic.** `.primary`, `.secondary`, `.tertiary`. The mockup's
`type` / `mute` / `faint` are exactly those three. Never hard-code a text colour.

**Resolving light and dark.** Use a platform-fenced dynamic provider —
`UIColor { $0.userInterfaceStyle == .dark ? … : … }` under `canImport(UIKit)`,
`NSColor(name:dynamicProvider:)` under `canImport(AppKit)`. Not
`@Environment(\.colorScheme)`, which cannot be read inside a `Color` constant and
would not survive `Appearance.apply`'s window-level override. Watch and widgets
use the UIKit provider.

## S2 · Type

**`ACIMType.swift` is an `extension Font`, and every token is `Font.acimX`.**

Note that **`PlatformTypography` is a filename, not a symbol** — `grep` returns
zero occurrences. `Utilities/PlatformTypography.swift` contains only
`extension Font { static var acimBody: Font … }` and six siblings. The new tokens
join that same pattern in a new file. Keep the seven existing tokens
(`acimBody`, `acimCallout`, `acimSubheadline`, `acimCaption`, `acimCaption2`,
`acimHeadline`, `acimTitle`) — they exist to match iOS sizes on macOS and are
still used by chrome that this redesign does not touch.

Serif means `.system(size:, design: .serif)` — New York. Sans means
`.system(size:)` — SF.

| Token | Size | Face | Weight | Line spacing | Used by |
|---|---|---|---|---|---|
| `acimMasthead` | 26 | serif | regular | 1.15 | Today's date; "Course"; "Saved" |
| `acimMastheadSub` | 12.5 | sans | regular | — | "Day 84 of the Workbook" |
| `acimDisplayTitle` | 29 | serif | regular | 1.20 | "Lesson 84" on a reading |
| `acimSubject` | 21 | serif | regular | — | a book name on the contents page |
| `acimSubjectSub` | 14 | serif italic | regular | — | "Review II — Love created me like itself" |
| `acimReading` | 19 | serif | regular | **1.62** | the passage on Today |
| `acimReadingPushed` | 18 | serif | regular | 1.62 | the passage on a pushed reading |
| `acimRowTitle` | 16 | serif | regular | 1.35 | a spine row |
| `acimRowSub` | 11.5 | sans | regular | — | "Available Friday" |
| `acimRowNumber` | 13 | serif | regular | — | the lesson number, gold, tabular |
| `acimAddress` | 14 | serif | regular | — | the citation under a passage |
| `acimAddressSmall` | 12.5 | serif | regular | — | citation on a card or search hit |
| `acimCardTitle` | 17 | serif | medium | — | "Lesson 84"; "Next practice" |
| `acimCardBody` | 15.5 | serif | regular | 1.55 | card prose |
| `acimChrome` | 13 | sans | medium | — | buttons; "Search the Course" |
| `acimChipText` | 11 | sans | medium | — | "about 1 min" |
| `acimGroupHeader` | 11 | sans | semibold | — | search group headers, +0.05em tracking |
| `acimTabLabel` | 10.5 | sans | medium | — | the tab bar |

**Line spacing above is a CSS multiple.** SwiftUI's `.lineSpacing()` takes the
gap between lines, so `lineSpacing = size × (multiple − 1)`. 19pt at 1.62 is
`.lineSpacing(11.8)`. Put the gap constants on `Metric` (`readingGap`,
`readingPushedGap`, `cardBodyGap`, `rowTitleGap`, `mastheadGap`,
`displayTitleGap`) so views do not re-derive them.

**Dynamic Type.** Build every token with `UIFontMetrics`-backed sizing — **not
`@ScaledMetric`**, which is a property wrapper usable only inside a `View` and
cannot appear in a static token table. Every token scales. There is no exception
list. Do not use `Font.custom("New York", …)` — New York is the system serif,
reached through `UIFontDescriptor` with `.serif` design, then wrapped as
`Font(uiFont)`. Map each token to a reasonable `UIFont.TextStyle` for metrics
(masthead → `.title`, reading → `.body`, chrome → `.footnote`, tab label →
`.caption2`). On macOS, use `NSFont` with the same point sizes; macOS has no
Dynamic Type, so the point size is the size.

**`ReaderTextSize` (`Utilities/ReaderTextSize.swift`, ×1.0 / ×1.25 / ×1.5)
multiplies `acimReading` and `acimReadingPushed` and nothing else.** That rule is
already enforced inside `SelectableReadingText` and must not spread — a masthead
that grows with the reader's body-text choice breaks every header. This is a
separate mechanism from Dynamic Type and the two compose. Apply the reader
multiplier at the view that sets the reading font, not inside the `Font` token.

Watch sizes are in §S7, not a second table here.

## S3 · Metric

`Utilities/Metric.swift`. **Bake the platform multiplier in at compile time** with
`#if os(tvOS)` / `#if os(watchOS)` so it is a constant, not a call-time
computation — that is the only form `verify_metric.sh` can assert. tvOS ×1.6,
watchOS ×0.7, everything else ×1.0. **The multiplier applies to spacing and radii
only, never to type** — fonts scale through Dynamic Type and through `ACIMType`'s
own per-platform sizes. Multiplying both compounds and gives tvOS 2.5× padding
around 1.6× text.

**Spacing:** `gutter 24` (screen edge) · `block 22` (between bands) ·
`card 16` (inside a card) · `row 13` (list row vertical) · `tight 6`.

**Radii:** `chip` capsule · `pill 19` · `card 16` · `sheet 26` · `art 20` ·
`bar 31` · `field 11`.

**Fixed, unmultiplied:** tap target 44 · progress hairline 2 · quote rule 2.

Expose as `enum Metric` with `static let` constants. Capsule is not a number —
views use `Capsule()` / `.clipShape(Capsule())` for `chip`.

## S4 · Components

**Toolbars, once, for all screens.** There is no large navigation title anywhere
in this design. The masthead is drawn in the content, so every screen sets
`.navigationBarTitleDisplayMode(.inline)` with an empty title. The mockup drawing
"Course" and "Saved" inside the nav chrome is a drawing convenience — implement
them as content mastheads, the same way Today already does. Trailing toolbar
items, in this order where present: search (`magnifyingglass`) then settings
(`gearshape`) on Today; search on Course; export (`square.and.arrow.up`) on
Saved. Settings stays a sheet reached only from Today, exactly as
`.openSettingsRequested` already works. On a pushed reading the toolbar carries
save, share, and an overflow `ellipsis` holding Add note, Export, and Text size.

**`ACIMTabBar`** — floating, not the system bar. Inset 16 left/right, 14 from
the bottom safe area, height 62, corner radius `Metric.bar` (31),
`.regularMaterial` over `acimSurface`, 1pt `acimHairline` border. Each item:
glyph 19 over `acimTabLabel`, 3pt apart, `acimGold` when selected, `.tertiary`
when not. Symbols: Today `sun.max.fill`, Course `book.closed.fill`, Saved
`bookmark.fill`. App target only. Replaces both the system `TabView` bar and
`MacBottomTabBar`, so `TabBarHeightReader` is deleted in step 4.

**Now Playing bar** — same insets, height 56, radius 18, sits 84 from the
bottom (that is 14 + 62 + 8). Artwork 36 square at radius 9, title 13 medium,
subtitle 11 `.secondary`, one 18pt play/pause on the trailing edge. Fill is
`.regularMaterial` over `acimSurface`, 1pt `acimHairline`. Replaces
`MiniPlayerView`'s 120pt reservation. **Keep the symbol `MiniPlayerView.height`
and change its value to 64** (56 + 8) rather than editing call sites: exactly
three files read it — `Views/Today/TodayView.swift:82`,
`Views/Archive/ArchiveView.swift:68`, `Views/Saved/SavedView.swift:49` — and
four more use `safeAreaInset(edge: .bottom)` with their own values
(`ArchiveDateDetailView`, `MinuteReadingView`, `ListenView`, plus the tab
container). After step 4 the Archive and Listen files are gone; leave the symbol
in place for whatever replaces them.

**Medium band** — the control that lets three tabs become one. Same insets,
height 58, radius 29, 5pt inner padding, three equal segments at radius 24 and
12pt vertical padding. Selected segment is `acimGold` with `acimOnGold` text;
available segments are `.secondary`; **unavailable segments stay in place at
32% opacity** so the control never changes shape between passages. Availability
comes from `MediaOverlay.Hit.showsListen` / `.showsWatch`; Watch with no YouTube
id falls to the composed player, which is
`VideoLibrary.play(videoIDs:youtubeAvailable:)` returning `.compose`. App target
only. tvOS has no medium band — Select opens `TVPlayerView`.

**The citation** — `Views/CitationLabel.swift`. Serif, `acimGold`, tabular
figures, +0.02em tracking, never wraps. Separators are rendered as `·` at **45%
opacity** while the numerals stay full strength: `T·1·3·2`, `W·84`, `W·w1`,
`M·4·1`, `Pref·4`. Source is `Utilities/Citation.swift` and
`Services/CitationResolver.swift` unchanged — this view only renders what they
already produce. **The rendering rule is total and is one line:** replace every
`-` and every `.` with the separator glyph. Set the separators at 45% opacity
and leave the alphanumeric runs at full strength. Nothing else. **Do not split
left-to-right on `.`.** See §E4. Tappable only where
`CitationResolver.destination` resolves somewhere other than the current screen,
which is the rule `Views/CitationButton.swift` already implements.

**Cards** — `acimSurface` fill, 1pt `acimHairline` border, radius
`Metric.card` (16), padding `Metric.card` (16), 14 between stacked cards.
Header row is title (`acimCardTitle`) leading, citation or chip trailing,
baseline aligned, 9 below. Progress hairline is 2pt on `acimRaised` with an
`acimGold` fill, 11 above.

**Action pills** — height 38, radius `Metric.pill` (19), 14 horizontal padding,
9 apart. The leading action is `acimGold` on `acimOnGold`; the rest are
`acimRaised` with `.primary`. Icon-only pills are 38 square. All keep a 44pt hit
area.

**Search field** — height 38, radius `Metric.field` (11), `acimRaised` fill,
`acimChrome` placeholder.

**Filter chips (Saved)** — 12pt sans medium, capsule, 13/8 padding, 7 apart,
`acimGold` / `acimOnGold` when on, `acimRaised` / `.secondary` when off.

## S5 · Screen builds

**Today.** Gutter `Metric.gutter` (24). Masthead: date at `acimMasthead`, 5pt
gap, sub at `acimMastheadSub`; 14 below it a 1pt `acimRule` line; 22 below that
the passage. The passage is `AnnotatableReadingText` at `acimReading` with **no
card background and no corner radius** — delete the `Color.acimCard` fill and
`cornerRadius: 12` from `Views/Today/DailyMinuteCard.swift`. 16 below the
passage a 1pt `acimHairline`, then 13 to the footer band: citation leading at
`acimAddress`, read time chip trailing. 16 below that the action row: Listen
(leading, gold, or omitted when there is no audio), then Watch, Save, Share as
icon pills. 26 before the lesson card. First-open-of-the-day motion is §S6.
`Views/Today/CorpusReadingCard.swift` takes the identical treatment — it is
Today's offline twin and the two must never disagree.

**Lesson card on Today.** "Lesson 84" at `acimCardTitle` leading, `W·84` at
`acimAddressSmall` trailing. Body: review grouping and the lesson's own line at
`acimCardBody`. Progress hairline when there is progress. The citation is the
lesson address `W·84`, never `W·r2·84` — that shape cannot exist (§E4, §E9).

**Practice card and sheet.** Card: "Next practice" with the next slot time as a
trailing chip, body giving the cadence. It opens a `.sheet` at radius
`Metric.sheet` (26) with a grab handle (38 × 5, `acim` faint at 50%), title
"Practice for Lesson N" at 23 serif, the lesson's cadence sentence at 13
`.secondary`, then one row per slot — time in gold serif in a 66pt column, label
14 with an 11.5 `.tertiary` sub, and an 8pt dot trailing. Past slots at 40%
opacity; the next slot's dot is gold with a 4pt gold-22% ring. Leading action
"Begin the evening period" (or whichever slot is next) in gold; trailing
settings icon pill opens the existing practice settings. All of it comes from
`PracticePlanner.plan(_:)`, `.slots(for:in:)` and `.cadenceSummary(_:)` plus
`WorkbookPracticeCatalog.record(for:)` — **write no scheduling logic.**

**Course contents.** Title "Course" at `acimMasthead` in the content. One row
per book, 18pt vertical, separated by 1pt `acimHairline`: book name at
`acimSubject` leading with a 12.5 sans count trailing, 6 below an
`acimSubjectSub` italic line giving where the reader is, then the progress
hairline where there is progress, then 11 below a row of media pips. A pip is
`acimChipText` in a 1pt-bordered capsule with 4/8 padding — gold text and
`acimRule` border when the medium exists, `.secondary` and `acimHairline` when
it is only a count. Progress comes from `Services/ReadingPositionStore.swift`
and `WorkbookCompletion`. "Let it fall open" is the last card, 22 below the
Manual row, `acimRule` border, using `FallOpen`.

Book rows, as drawn:

| Book | Trailing count | Sub | Pips |
|---|---|---|---|
| Daily Minute | day count | "One passage a day, drawn from the Text" | recorded / filmed |
| Workbook | "N of 365" | current review or lesson line | audio / video / "22 introductions" |
| Text | "31 chapters" | current chapter | "272 sections" / composed |
| Manual | "31 sections" | "Not started" or current section | questions / composed |

**A spine.** Book name at `acimMasthead`, 3 below a 12.5 sub, 14 below a search
field. Rows are `Metric.row` (13) vertical, 13 apart horizontally: number column
34pt at `acimRowNumber` in `acimGold` tabular, title at `acimRowTitle`, sub at
`acimRowSub`, and trailing media glyphs at 12pt `acimGold` 85% — audio
`waveform`, video `play.rectangle`. A row with neither shows nothing. A
completed row's title goes `.secondary`; an unpublished row drops to 42% opacity
and is inert — that is `LessonSchedule` unchanged. **The current lesson is the
one highlighted row:** gold at 9% behind it, bled 12pt into both gutters at
radius 10, its sub in gold carrying today's practice instead of a publication
date. The existing scroll-to-current in `FilteredLessonsList` stays.

Minute spine is the existing calendar, restyled onto ink, not reinvented.
Text spine is chapters; Manual spine is sections. Each book keeps the
navigation that book wants.

**A reading.** Running head: parent name in `acimSubjectSub` italic leading,
citation trailing, 12 below, then a 1pt `acimRule`, then 20 to the title. Title
at `acimDisplayTitle`, 6 below the lesson's own line at 17 serif italic
`.secondary`, 24 below that the passage at `acimReadingPushed`. The medium band
is pinned at the bottom. `ReadingScaffold` keeps owning the band order —
header, title block, body, footer — and gains the medium as a fifth band; only
the styling of each band changes, which is what makes all nine reading surfaces
move together.

**Now Playing.** Artwork is a 232pt box at radius `Metric.art` (20) with an
`acimRule` border and a gold radial wash from the top, holding **the passage
itself** at 23pt serif italic, centred, max 26 characters a line — no stock
image, no app icon. Below: title 21 serif, 4 below a 13 `.secondary` sub, 22 to
the scrubber. Scrubber track 3pt on `acimRaised` with a gold fill and an 11pt
gold knob; times 11pt tabular `.secondary` 9 below, elapsed leading and
remaining trailing. Transport 26 below: −15, back, a 68pt gold circle, forward,
+15, 34 apart. Download, mark listened, share and save as icon pills 30 below,
centred.

**Saved.** One stream, not three segmented lists. Filter chips at the top —
All / Highlights / Notes / Bookmarks. Each mark is 15 vertical: the quote at 16
serif behind a 2pt `acimGold` left rule with 13pt padding, the **highlighted
span painted in `acimMark`** so the list shows a highlight as a highlight; a
note follows at 14.5 serif italic `.secondary`, 10 below, indented 15; then the
meta row — citation `acimAddressSmall` and an 11.5 `.tertiary` date. An orphaned
highlight (`AnchorResolver` returning `.orphaned`) renders at 50% opacity rather
than with an apology. Export stays in the toolbar. Order is when the reader
marked them, newest first.

**Search.** Field as above. Results grouped, each group led by
`acimGroupHeader` with the count written out ("41 IN THE WORKBOOK"), 16 above
and 8 below. A hit is 14 vertical: name at 15 serif leading, citation trailing,
6 below the snippet at 14.5 serif `.secondary` with the match painted in
`acimFind`. Headings come from `CorpusSearchService.headings(matching:)` and
are their own first group, snippet-less — behaviour that already exists in
`ReadSearchResultsList`.

## S6 · Motion

One orchestrated moment and nothing else. On the **first open of the day only**,
Today's `acimRule` draws across from the leading edge over 0.4s, then the
passage fades up over 0.3s a beat behind it. Not on every return to the tab —
key it off the date, alongside the existing `hasLoadedOnce`.

Everything else is a response to touch: the medium band slides its selection,
the practice sheet rises, a highlight washes in under the finger, the Now
Playing bar's existing 0.2s `easeInOut` on `hasActiveAudio` stays. Reduced
Motion removes the opening sequence and leaves every other state change instant.

## S7 · Per-platform translation

The tokens and every component above are shared. Only these differ:

- **iPhone** — as drawn. Three tabs. `ACIMTabBar` and the Now Playing bar.
- **iPad and Mac** — `NavigationSplitView` in step 8, no tab bar, no
  `ACIMTabBar`. Sidebar holds Today, the four books, Saved. The reading is the
  detail column. Mac keeps its 420pt minimum width and its 672pt readable
  column; the iPad's column is §O. Until step 8, both follow the phone tabs.
- **Apple TV** — `Metric` ×1.6. Two system tabs, no Saved, no medium band, no
  floating tab bar. Select opens `TVPlayerView`, which is not rebuilt. The
  citation, the masthead and the spine highlight all carry over.
- **Watch** — `Metric` ×0.7. Today only: date at 17 serif, passage at 15 serif,
  citation at 11 serif gold. No tab bar, no player.
- **Widgets** — the same masthead / passage / citation stack. Small: three lines
  of passage over a citation. Medium: passage with the lesson trailing. Large:
  masthead, passage, citation, next practice slot. All keep
  `widgetURL(acimdailyminute://today)`.

---

# E · Exactness

Verified against the working tree on 2026-09-11. Each is somewhere an
implementer would otherwise have to guess, and guessing wrong is silent.

## E1 · Adding a file to the Xcode project

There is no `.xcodeproj` automation here. Every new file is a hand edit to
`ACIMDailyMinute.xcodeproj/project.pbxproj`, and the number of entries depends on
how many targets the file belongs to. The five Sources build phases are:

| Target | Sources phase UUID |
|---|---|
| `ACIMDailyMinute` (iOS + macOS) | `AA000007001` |
| `ACIMDailyMinuteTV` | `C96F83C9A678E4BAE201AF8B` |
| `ACIMDailyMinuteWidgetExtension` | `AA000007003` |
| `ACIMDailyMinuteWatch Watch App` | `AA000007005` |
| `ACIMDailyMinuteWatchWidgetExtension` | `AA000007007` |

For each new file you add **one** `PBXFileReference`, **one** group-children
entry, and **one `PBXBuildFile` per target it belongs to**, each with its own
UUID, listed in that target's Sources phase. A file in a new directory
(`Views/Course/`, `Views/Practice/`, `Views/Reading/`) also needs a new
`PBXGroup`.

**UUID convention in this repo:** `AA000002NNN` for the file reference,
`AA000001NNN` for the main-app build file, a 24-hex value for the tvOS build
file. `NNN` is a three-digit serial. **Do not increment past 999** — 999 is
already used. Pick unused three-digit serials; 989–998 are free as of this
writing. Confirm with `python3` against `project.pbxproj` before taking one.

Working two-target example — `ReadSearchResultsList.swift`: one `PBXFileReference`,
one group child, one app `PBXBuildFile`, one tvOS `PBXBuildFile`.

Working five-target example — `SharedModelContainer.swift`: one
`PBXFileReference`, one group child, five `PBXBuildFile` entries.

Run `./clean.sh` after editing `project.pbxproj`. A stale DerivedData will build
green against the old file list.

**Which targets each new file needs:** the table in §4. `ACIMColors.swift`
already compiles into the app and tvOS; extend it to the Watch app and both
widget extensions.

## E2 · The palette must live in Swift, not in the asset catalogue

**There are three separate asset catalogues** and they do not share:

- `ACIMDailyMinute/Assets.xcassets` — has `Gold`, `CardBackground`,
  `ChipBackground`, `OnGold`, `AccentColor`.
- `ACIMDailyMinuteWatch/Assets.xcassets` — **AppIcon only.**
- `ACIMDailyMinuteWidget/Assets.xcassets` — `AccentColor`, `BrandMark`,
  `WidgetBackground`. No `Gold`.
- `ACIMDailyMinuteWatchWidget` — **no catalogue at all.**

A named colour resolves against its own target's bundle, so `Color("Gold")` in
the Watch app or either widget resolves to nothing. That is why
`ACIMColors.swift` is currently compiled into only the app and tvOS targets, and
why the Watch and widget code uses **zero** named colours today.

Duplicating four colorsets into three catalogues would repeat a failure this
project has already been bitten by (see the two copies of `ACIMChime.caf`:
nothing syncs them and a stale copy builds green).

So: define the whole palette as literal values in Swift. Put them in
`Views/ACIMColors.swift`, compile that file into all five targets, and have the
existing `acimGold` / `acimCard` / `acimChip` / `acimOnGold` names forward to the
literals. Leave the existing colorsets in the catalogue untouched.

## E3 · Where the Ink ground actually gets applied

**No view in the app sets an app-level background today.** Every screen inherits
the system background, which `Utilities/Appearance.swift` drives through a window
override. So `acimInk` is a genuinely new concept and needs an explicit
application point, or it will appear to do nothing.

Apply it at each tab root, **behind** the content, and hide the scroll
background that would otherwise cover it:

- `ScrollView`-based screens: `.background(Color.acimInk.ignoresSafeArea())`.
- `List`- and `Form`-based screens: **also** `.scrollContentBackground(.hidden)`,
  or the system grouped background paints over it. Rows inside those lists need
  `.listRowBackground(Color.clear)`, which several already use for other reasons.

Files that contain a `List` or `Form` root and every one needs this in step 1:

- `Views/Saved/SavedView.swift`
- `Views/Settings/SettingsView.swift`
- `Views/Settings/BackupRestoreView.swift`
- `Views/Archive/ArchiveView.swift`
- `Views/Archive/VideoTextChapterView.swift`
- `Views/Listen/ListenTextChapterView.swift`
- `Views/Listen/ListenView.swift`
- `Views/Lessons/ReadSearchResultsList.swift`
- `Views/Lessons/LessonsView.swift`
- `Views/Lessons/JumpToLessonSheet.swift`
- `Views/Text/TextChaptersView.swift`
- `Views/Text/TextChapterView.swift`

Also apply at the tab roots that are `ScrollView`-based (`TodayView`, and later
`CourseView`). Do this in step 1 for every screen as it stands. Steps 2 onward
then inherit it.

The three `.background(Color(white: 0.11))` occurrences in `ListenButton.swift`,
`SaveButton.swift` and `ShareButton.swift` are inside `#Preview` blocks only.
They are not a light-mode bug and need no fix.

## E4 · The citation rule

This is the highest-risk detail in the plan, because a wrong rule produces
plausible-looking output on the common case and corrupts the rest.

`Citation.swift` emits **exactly nine shapes**. Verified counts over the 1,983
bundled segments (3 have a null citation and must render nothing at all):

| Shape | Count | Example | Renders as |
|---|---|---|---|
| `T-N.N.N` | 1242 | `T-1.3.2` | `T·1·3·2` |
| `W-N.N` | 570 | `W-84.1` | `W·84·1` |
| `M-N.N` | 104 | `M-4.1` | `M·4·1` |
| `Pref.N` | 21 | `Pref.40` | `Pref·40` |
| `W-wN.in.N` | 20 | `W-w1.in.1` | `W·w1·in·1` |
| `W-rN.in.N` | 16 | `W-r2.in.3` | `W·r2·in·3` |
| `W-pII.in.N` | 4 | `W-pII.in.1` | `W·pII·in·1` |
| `W-pI.in.N` | 2 | `W-pI.in.1` | `W·pI·in·1` |
| `M-in.N` | 1 | `M-in.5` | `M·in·5` |

**The rendering rule is total and is one line:** replace every `-` and every `.`
with the separator glyph. Set the separators at 45% opacity and leave the
alphanumeric runs at full strength. Nothing else.

**Do not split left-to-right on `.`** — the field count is 2 or 3 and is not
predictable from the leading letter. `W-` is two fields for a lesson and three
for an introduction; `M-in` and `M-30` differ in type, not shape; the middle
field of a three-field citation is a number for `T-` and the literal string `in`
for every `W-*.in.*`; and `Pref.N` has no hyphen at all.

If you ever need to separate the address from the paragraph, the only safe
decomposition is **split on the LAST `.`**: `rawValue == stem + "." + paragraph`
holds for all seven enum cases, with no zero-padding and no sentence suffix.

Other invariants that will bite:

- **`.lesson(n)` is not bounded by 1...365.** Twenty-two pseudo-ids carry the
  Workbook introductions — `0`, `401`–`406`, `500`, `601`–`614` — each with its
  own `citationStem` in `WorkbookIntroductions.json`. Code that assumes a lesson
  number is a lesson is wrong.
- `CitationResolver.destination` finds introductions by **exact string equality**
  against that `citationStem`. Never feed a rendered or normalised citation back
  into a lookup — render at the last moment, for display only.
- Roman numerals appear in exactly one place, `pI` / `pII`. Review (`r1`–`r6`)
  and What Is (`w1`–`w14`) numbers are deliberately Arabic so they cannot be
  mistaken for the widely-cited edition. Text sections are Arabic for the same
  reason. Do not "fix" any of this.
- `ReadingKey.minuteDate` always resolves to no citation. A Daily Minute shows
  its date, not an address, until the feed names its segment.

**A trap the mockup already caught.** An earlier draft rendered Lesson 84's
address as `W·r2·84`, which cannot exist: `W·84` is the lesson, and `W·r2·in` is
the Review II *introduction*, a different reading with its own body. The
corrected mockup at `docs/design/` reads `W·84`. The untracked browser save
still shows `W·r2·84`. The review grouping is metadata about a lesson, not part
of its address, and the same confusion is available for the What Is essays and
both Part introductions.

## E5 · What `ReadingScaffold` actually reaches

Nine files, twelve call sites. Restyling the scaffold changes all of them at
once, and nothing else:

`Views/Today/DailyMinuteCard.swift` (1) · `Views/Today/DailyLessonCard.swift` (1)
· `Views/Today/CorpusReadingCard.swift` (1) ·
`Views/Lessons/LessonDetailView.swift` (3) ·
`Views/Lessons/WorkbookIntroductionView.swift` (1) ·
`Views/Text/TextSectionView.swift` (1) · `Views/Manual/ManualSegmentView.swift`
(2) · `Views/Segment/SegmentReadingView.swift` (1) ·
`Views/Archive/ArchivedReadingCard.swift` (1).

`MinuteReadingView` and `ArchiveDateDetailView` compose the cards above rather
than calling the scaffold directly, so they change for free.

## E6 · Collapsing the tabs — the complete breakage list

Step 4 changes `selectedTab` from five values to three (0 Today, 1 Course,
2 Saved; tvOS 0 Today, 1 Course only). Every item below breaks and must be fixed
**inside step 4**, not deferred to step 10.

**`App/ContentView.swift`** holds every index, in six places: the `@State`
default (`:9`), the five `.tag()` calls (`:255–283`), the macOS `switch`
(`:310–316`), `MacBottomTabBar.items` (`:349–355`), and the two mini-player
predicates (`:294`, `:320`).

**Routing.** `DeepLinkRoute` has six cases; `.lessons`, `.lesson(n)`, `.listen`
and `.archive(d)` currently land on three different tabs that become one. Each
needs a destination *within* Course, not just an index — otherwise
`acimdailyminute://listen` lands on whichever book Course was last showing.
Keep the scheme and all six hosts: they are a shipped public contract, they are
in the widgets, and `verify_deep_links.sh` compiles and exercises every one.

**The tvOS Saved fence stays.** `ContentView.swift:223–232` redirects `.saved` to
tab 0 on tvOS because selecting a tag no tab carries leaves the `TabView` blank.
Saved is still absent on tvOS after the collapse, so this fence is still load
bearing at the new index. Do not delete it because the number changed.

**Notification observers.** `.deepLinkLesson` is observed in
`LessonsView.swift:148` and `.deepLinkArchive` in `ArchiveView.swift:104`. Both
views disappear into `CourseView`. Each currently forces its own shelf
(`shelf = .lesson`, `shelf = .minute`) on three **separate** `@State CourseShelf`
properties (`LessonsView.swift:54`, `ListenView.swift:53`,
`ArchiveView.swift:30`) which become one. Both observers will also be appending
to the same `NavigationPath` — make that one code path, not two racing ones.

**A timing trap.** `.deepLinkArchive` is posted one runloop after the tab
changes (`ContentView:218`) and relies on `ArchiveView` already being mounted. If
`CourseView` builds its book lazily, the post fires before the observer exists
and the deep link is dropped in silence. Route through state you own rather than
a notification, or mount before posting.

**The mini player predicate cannot survive.** `selectedTab != 1 && selectedTab != 2`
means "not Read and not Listen"; after the collapse those are the same tab. The
design resolves this: the Now Playing bar shows whenever audio is active and is
hidden only inside the full player. That also removes `ListenView.swift:139–146`,
which self-draws a mini player precisely because `ContentView` suppresses it
there, and reconciles the contradiction that `ArchiveView:68` reserves height for
a bar while `ListenView` draws its own. `.onTapGesture { selectedTab = 2 }` (go
to Listen) becomes "open the full player".

**The debug screenshot hook.** `applyScreenshotTabIfRequested()`
(`ContentView:164–203`, `#if DEBUG`) accepts `read`, `listen`, `video`,
`archive`, `saved`, `lesson`, `settings`. `tools/capture_store_screenshots.sh`
passes `today read lesson video saved settings` (iOS), `today read listen video`
(tvOS) and `today read video saved settings` (Mac). Keep every string accepted
and map it to the new tab + book, or the capture script silently shoots Today
six times — the `default:` case is a no-op.

**Onboarding.** Five pages, one per old tab
(`Views/Onboarding/OnboardingView.swift:34–50`). Pages 3 and 4 name Listen and
Video, which stop being tabs. Page count is derived, so the dots and chevrons
adapt on their own. Rewrite the pages in step 4 alongside the tabs — not in
step 10 — because a verify script gates them (§E7).

## E7 · Verify scripts that encode the OLD design

These are green today **because** the app has five tabs. Step 4 will turn them
red, and that is correct. Rewrite them in the same commit, with the reason in the
commit message. Do not contort the new code to keep them passing, and do not
delete them.

| Script | What it hard-requires |
|---|---|
| `tools/verify_deep_links.sh:94–120` | the literals `Label("Video"`, `title: "Video"` in the Mac bar, `navigationTitle("Video")` in `ArchiveView.swift`, and `("play.rectangle", "Video"` in `OnboardingView.swift`; plus absence of `"Archive"` in three places |
| `tools/verify_audio_transport.sh:45,48` | the exact string `selectedTab != 1 && selectedTab != 2`, and the absence of `hasActiveAudio && selectedTab != 2` |
| `tools/verify_listen_play_pause.sh:43` | the literal `selectedTab != 2` |
| `verify_listen_activity.sh:13`, `verify_listen_unplayed.sh:16`, `verify_read_minute_shelf.sh:15`, `verify_iphone_player_chrome.sh:16–20`, `verify_tv_read.sh:17–30` | assert against `ListenView.swift`, `LessonsView.swift` and `ArchiveView.swift` as separate files — merging them breaks the path, not the logic |
| `tools/verify_copy.sh:44` | greps `store-support-page.md` for a Video-tab sentence |

The half of `verify_deep_links.sh` that compiles `DeepLinkRoute.swift` and
exercises every host is testing real behaviour — keep it exactly. It is only the
grep gates after the compile that encode the old tab names.

## E8 · Smaller things, so nobody has to choose

**Tab symbols.** Reuse what is already there: Today `sun.max.fill`, Course
`book.closed.fill`, Saved `bookmark.fill`. `play.circle.fill` and
`play.rectangle.fill` retire with the Listen and Video tabs.

**Media pips on a spine row.** Audio `waveform`, video `play.rectangle`, both at
12pt, `acimGold` at 85% opacity. A row with neither shows nothing — it is still
readable and still watchable in the composed player, so absence is not an error
state and gets no placeholder.

**`Metric`'s platform multiplier applies to spacing and radii only, never to
type.** Fonts scale through Dynamic Type and through `ACIMType`'s own
per-platform sizes. Multiplying both would compound.

**`MiniPlayerView.height`** stays as a symbol and changes value from 120 to 64.
Three files read it; leave them alone.

**`ReaderTextSize`** multiplies the reading tokens only. That rule is already
enforced in `SelectableReadingText` and must not spread to the new tokens.

**The two Manual screens.** `ManualSegmentView` (legacy word-count cuts,
`manual:` keys) and `ManualSectionView` (structured questions, `manual-q:` keys)
reconcile to one in step 5. **Both key prefixes must keep resolving** — exported
backups in the wild contain both, and `AnchorResolver` has to find their
highlights after the merge. Migrate the view, not the keys.

**`CourseShelf` becomes the book enum.** The three `@State CourseShelf`
properties collapse to one in step 4.

## E9 · Where the mockup is wrong

Build from this document. The mockup at `docs/design/` is intent. These are the
places it is known to be wrong or incomplete:

1. **Light-mode highlight and search alphas.** The mockup's paper mode uses
   `rgba(255,206,0,.30)` for mark and `rgba(0,122,255,.16)` for find. The shipped
   values are `systemYellow` 0.28 and `systemBlue` 0.22 in both appearances.
   Keep the shipped values.
2. **Search-hit chip in the palette panel says "blue 24%".** The token is 0.22.
3. **`W·r2·84` as a lesson address.** Cannot exist. Lesson 84 is `W·84`. The
   corrected mockup at `docs/design/` already says `W·84` on Today, on the
   reading, and in the address panel. The untracked browser save still says
   `W·r2·84`. Never render a review grouping as part of a lesson address.
4. **iOS 26 floor.** The mockup's closing note asks whether the floating tab bar
   is worth raising the floor. It is not. Hand-build `ACIMTabBar` over
   `.regularMaterial`. Deployment target stays 17.0.
5. **Palette in the asset catalogue.** The mockup's cost panel says the palette
   is extended in the catalogue. It is not. Swift literals in `ACIMColors.swift`,
   compiled into all five targets (§E2).
6. **Sidebar still "needs deciding".** The mockup's closing note treats iPad/Mac
   chrome as open. It is not. They get `NavigationSplitView` in step 8. What
   remains open is the two questions in §O, not whether there is a sidebar.
7. **Radii "become three — 11 / 16 / 26".** Incomplete. The full set is §S3:
   chip capsule, pill 19, card 16, sheet 26, art 20, bar 31, field 11.
8. **Course and Saved titles drawn in the nav bar.** Drawing convenience.
   Implement as content mastheads with an empty inline navigation title (§S4).
9. **Search group headers.** The untracked save says `WORKBOOK · 41 PASSAGES`.
   The corrected mockup and this document say `41 IN THE WORKBOOK`.

---

# V · Verification

The repo has ~45 `tools/verify_*.sh` gates. They fall into three groups and the
distinction matters — treating group two as a regression is the most likely way
to lose a day.

**Stay green throughout.** These test behaviour the redesign does not change:

`verify_card_header.sh`, `verify_card_header_dynamic_type.sh`,
`verify_spacing_agreement.sh`, `verify_ipad_reading_width.sh`,
`verify_mac_reading_scroll.sh`, `verify_reader_text_size.sh`,
`verify_text_measurement.sh`, `verify_tv_page_scroll.sh`,
`verify_archive_calendar.sh`, `verify_fall_open.sh`, `verify_citations.py`,
`verify_citation_agreement.sh`, `verify_media_overlay.sh`,
`verify_reading_time.sh`, `verify_reading_position.sh`,
`verify_playback_progress.sh`, `verify_backup.sh`, `verify_corpus_search.sh`.

**Must be rewritten in step 4** because they encode the five-tab design: the
scripts listed in §E7. Rewriting them is part of the step, with the reason in
the commit message. Do not contort the new code to satisfy them and do not
delete them.

**New**, matching the existing `swiftc`-in-isolation pattern (copy
`tools/verify_reading_time.sh` — it compiles one source file, greps it for
forbidden imports, and runs assertions against a Python-built fixture). Add
these in step 1:

- `verify_metric.sh` — `Metric.swift` imports nothing but Foundation/SwiftUI;
  the platform multiplier is a compile-time constant (`#if os`); it hits
  spacing and radii but not type; the unmultiplied constants (tap 44, hairline
  2, quote 2) are identical on every platform.
- `verify_acim_type.sh` — every `Font.acimX` token in §S2 resolves; only
  `acimReading` and `acimReadingPushed` are documented as `ReaderTextSize`
  targets (the script greps call sites, it cannot run SwiftUI); the file does
  not import SwiftData or UIKit-only types that would keep it off the Watch.
- `verify_citation_render.sh` — **the important one.** Render every one of the
  1,980 non-null citations in `ACIMSegments.json` plus all 22 introduction
  stems, and assert: nine shapes in, nine shapes out; no citation loses or
  gains a field; the three null-citation segments render empty; a round trip
  through `Citation(rawValue:)` still resolves after rendering is stripped;
  Lesson 84 renders `W·84` and never `W·r2·84`.

Then, in this order, **batched to the end rather than after each step**:

1. **iPad simulator, iOS 18.1** — Today, Course contents, each of the four
   spines, a reading with each medium state, the player, Saved, search.
2. **macOS standalone**, signed Debug build on his own Mac — split view, window
   at the 420pt minimum and at full screen, both appearances.
3. **Apple TV simulator** — Today, Course, composed player, remote paging on
   Text chapter 1.
4. **Watch simulator** and all three widget sizes in both appearances.
5. **Physical iPhone 11 Pro Max** — the real proof, and the only place the
   arm64 Swift 6 strictness shows up.

Every screen checked in **both appearances** and at **Default / Large / Larger**
reader text size, plus one pass at an accessibility Dynamic Type size to confirm
`CardHeaderRow`'s `ViewThatFits` fallback still lands.

`./both.sh` is available throughout; do not treat a green `./both.sh` as the
batched pass. The batched pass is the five-item list above, once, after step 10.

---

# O · Open questions

Two things still to settle, in step 8, against a running build:

- Whether the iPad sidebar shows the four books directly or only the three
  top-level destinations (Today, Course, Saved) with books inside Course.

- What replaces the macOS-only 672pt column on an iPad that now has a sidebar
  taking its own width.

Both are cheap to decide against a running build and expensive to guess at now.
They are the only two. The mockup's other "still needs deciding" items are
closed: there is a sidebar on iPad and Mac; the tab bar is hand-built at iOS 17.

Do not invent a third.
