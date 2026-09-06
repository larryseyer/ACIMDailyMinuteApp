# continue.md — what is being worked on RIGHT NOW

⛔ **Current and future only.** No history, no history lessons, no ✅ recital of what a session did —
`git log` is the record. Open items live in [`todo.md`](todo.md), which is the source of truth; this file
says what is true now and what is next. REPLACE the state block below — never stack a new one under it.

---

## ✅ WHAT IS TRUE RIGHT NOW

Working tree clean on branch `ralph/acim-3.9-to-5-finish-2026-04-14`, committed and pushed. Nothing
of mine is running.

⛔⛔ **TWO OF HIS DECISIONS ABOUT THE TELEVISION ARE SETTLED, AND THEY EXIST NOWHERE BUT HERE AND IN
[`todo.md`](todo.md). Do not ask him again.** **The TV is a PLAYER** — listen and watch first,
reading secondary — **and the TV app carries NO ANNOTATION AT ALL.**
⛔ **That second one is now CARRIED OUT and seen on the simulator**: four tabs with no Saved, card
headers carrying Listen alone, and no "Add note" at the foot of a reading. The one question inside it
is settled too — **the television KEEPS its reading position**, because a ribbon is a pointer rather
than a mark; the reasoning is written into `Services/ReadingPositionStore.swift` so it reads as chosen
rather than overlooked. Do not re-open either half.

⛔⛔ **NOTHING ON THE TELEVISION IS FOCUSABLE, AND THAT ONE FACT IS THE WHOLE OF PHASE 3.** tvOS
navigates by moving focus; this app was written for a finger, so almost nothing can hold focus. It
is not three defects, it is one wearing three hats, all measured 2026-09-05 on the simulator and on
his own Apple TV:
- **A pushed reading will not scroll.** One focusable element, `ListenButton`, at the top; nothing
  below for focus to reach. `Preface > The Use of Terms` ("about 22 min") takes five down presses
  with the screenshots **MD5-identical**.
- **The introduction cannot be paged, and it is a HARD GATE.** `TabView(.page)` moves by focus, and
  cards 1-4 hold no focusable element — only the last card has a button. Six arrow presses, three
  right and three down, gave three **MD5-identical** screenshots. The only focusable thing on that
  screen is Skip, so **Select dismisses the introduction rather than advancing it**, and the five
  cards cannot be read on a television at all.
- **A viewer cannot always see what is selected.** `.focusEffectDisabled()` on the Skip button was
  added so the Mac would not draw a ring; on a television the ring is the only thing telling someone
  across the room where they are.

⛔ **THE OBVIOUS FIX WAS TRIED AND IT DID NOT WORK — do not re-spend that day.** A throwaway spike
made the `UITextView` focusable (`canBecomeFocused` overridden in a subclass), set
`isScrollEnabled = true` and set `panGestureRecognizer.allowedTouchTypes = [.indirect]`, and
bounded the viewport. **Focus still never left the tab bar** — `Read` stayed lit and the reading did
not move. So the `UIScrollView` header's promise that indirect pan "automatically supports
directional presses" is **not sufficient inside a SwiftUI `UIViewRepresentable`**: something has to
route focus *into* the representable first, and `canBecomeFocused` alone does not do it. The spike
is reverted. ⛔ **The next hypothesis, untested, is `.focusable()` on the SwiftUI side of the
representable** — but the mechanism is UNPROVEN and the spec says so.

⛔ **The rule that came out of it: ON tvOS TAKE THE MAC'S TREATMENT, NOT THE PHONE'S.** The Mac and
the television both navigate discretely, between things that hold focus; the phone navigates
continuously, by dragging pixels. `OnboardingView` proves it — its **macOS branch already draws one
page at a time with chevron buttons at the sides**, and a button is focusable. That branch is what a
remote wants; its iOS branch is what a remote cannot use. The same question should be asked of every
tvOS fence: which of the other two platforms is this actually like?

⛔⛔ **HIS APPLE TV IS REGISTERED AND THE WHOLE DEVICE LOOP WORKS — build, install, launch, read the
console.** `LIVINGROOM`, `AppleTV6,2` (Apple TV 4K, 1st gen) on **tvOS 26.6**, developer mode already
enabled. Two identifiers, and they are different things: `-destination` takes
`platform=tvOS,id=9709e1041cefbcf9821b5cd219041c9233614727`, and every `devicectl` call takes
`--device B2AAAF1A-7E8F-5DCC-9B0C-735D53C7E759`. ⛔ **`-allowProvisioningUpdates` will NOT register
a new device from the command line** — it only refreshes profiles for devices already known, and
fails with *"Device … isn't registered in your developer account"*. He registered it in Xcode; if a
device is ever replaced that step is his and cannot be done from here. ⛔ **The television is in his
office and is normally a television**, so device time is borrowed and announced, never assumed.

⛔⛔ **A SIMULATOR CANNOT TELL YOU THE APP RUNS. `sim-green` is not `device-green`, and now
`sim-RUNS` is not `device-runs`.** The app had **never once launched** on a real Apple TV while
running perfectly on the simulator for weeks, because the simulator does not enforce the tvOS
sandbox at all. Anything about storage, entitlements or sandboxing that a simulator reports is
worthless. ⛔ **`devicectl device process launch --console` is the tool that finds these** — it
carries the app's own stderr back, which is where the CoreData errors and the `fatalError` were; no
build, no screenshot and no crash log surfaced any of it.

⛔ **A TELEVISION IS DRIVEN BY KEYS, NOT CLICKS, AND THE FRONT WINDOW MUST BE CHECKED EVERY TIME.**
`osascript … key code` reaches the tvOS simulator — 126/125/123/124 for the arrows, 36 for Select,
53 for Menu — and `xcrun simctl io <udid> screenshot` reads the result independently of what is
stacked over the window. ⛔ **Other terminals share this Mac and they shut simulators down**: the TV
sim was shut down mid-session by something else, and a `simctl install` then fails with
`code=405, "Unable to lookup in current state: Shutdown"` — reboot it rather than believing the
build broke. Match the window on the device's own name and confirm it is frontmost before **every**
key, or the presses land in another agent's window and the screenshot innocently shows no change.

⛔⛔ **ON A TELEVISION THE APP GROUP CONTAINER'S ROOT IS NOT WRITEABLE, AND THE ENTITLEMENT BEING
CORRECT HAS NOTHING TO DO WITH IT.** The container holds exactly three writeable directories —
`Library`, `Library/Caches`, `Library/Preferences` — so `SharedModelContainer.groupURL` appends
`Library/Caches` under `#if os(tvOS)` and both stores live there. ⛔ **The nil-fallback beneath it
cannot catch this**: `containerURL` returns a perfectly good URL that happens to be unwriteable, and
absent and unwriteable are different failures. A store at the root fails
`NSCocoaErrorDomain 513` / *"Sandbox access to file-write-create denied"*, and the app's own
`fatalError` then takes the process down — which is correct, and looks exactly like an app that
installs, shows a tile and quits. ⛔ **`Library/Caches` is PURGEABLE**, so on the television the
cache is a cache in fact: tvOS may take it at any moment, nothing is lost when it does, and that is
the durability rule rather than a consolation. **It is also why the ribbon belongs in `UserDefaults`
and not SwiftData** — `Library/Preferences` survives what `Library/Caches` does not.

⛔⛔ **THE TELEVISION IS HANDED THE iPAD'S READING COLUMN: 672pt OF 1920pt, 35% USED AND 65% EMPTY.**
`ReadableContentWidthModifier` clamps at `maxReadableWidth = 672` whenever `sizeClass == .regular`,
and **tvOS reports `.regular`**. A 4K Apple TV is 1920x1080 *points*, and overscan takes about 60pt
per edge, leaving ~1800pt usable. `Utilities/ReadableContentWidth.swift` has the right fence *idiom*
and the wrong *policy*: it treats a television as an iPad because both answer `.regular`, and never
asks the question a television poses. ⛔ **Widening the column alone makes reading WORSE** — 672pt
exists because 45-75 characters is what stays readable, and a wide column at phone type size gives
130-character lines. **Width and type size move together**, roughly 1200-1400pt with body type
scaled for a viewer eight to ten feet away, and the pair is judged with eyes on a television rather
than fixed in a spec.

⛔ **`.searchable` DOES NOT FALL AWAY ON tvOS — IT TAKES OVER.** The Read tab's one `.searchable`
renders on the television as a permanent full-width "Search the Course" keyboard, an a-z strip
across the top third of the screen, with the chapter list ghosted behind it. It is not a field a
viewer opens; it is always there. Anything claiming the television simply lacks search is wrong.

⛔ **The white tile on his home screen is the missing brand assets, not a new defect.**
`Assets.xcassets` carries only `AppIcon.appiconset`, the flat iOS icon. tvOS needs a `.brandassets`
group with **layered** parallax icons and a Top Shelf image, and that is an art job rather than a
build setting.

⛔ **The Apple TV target is built, runs, and `build.sh` is FOUR legs now.**
`ACIMDailyMinuteTV` compiles, installs and launches on the Apple TV simulator, drawing the Daily
Minute from the feed. It compiles the **same source list as the app** — every platform difference is
a fence inside a file, so there is no second membership list to drift — with its own entitlements
(App Group, **no iCloud**) and device family `3`. Its scheme is **shared**. ⛔ **What runs there is
the phone's five-tab layout, not the player he asked for**; the layout is a design pass and it is
his to shape.

⛔ **THE WATCH IS BUILT, ITS COMPLICATION IS PLACED, AND THE tvOS PLAYER IS WHAT IS OPEN.** Phase 2
is done: the watch app is embedded in the iOS app and installs with it, it carries
`ACIMSegments.json` and the corpus layer so it reads with no phone and no network, `WCSession` is
proved end to end, the `@Query` redraws a stale row into today's **without a relaunch** — measured,
not inferred from launch order — and the `.accessoryRectangular` complication is live in the Smart
Stack drawing today's passage. What is left of the watch is three design calls that are his, plus
two complication families a simulator cannot place — all four are in [`todo.md`](todo.md).
⛔ **Neither the watch nor the TV is a compile problem** — both build — so a green build is not
progress on either.

⛔ **A READ-ONLY STORE MUST BE ASKED FOR THE SHAPE ITS WRITER LEFT IT, AND GETTING THAT WRONG IS
SILENT.** `WatchDataService` writes `cache.store` with the six cache models alone
(`includeReader: false`); a reader that asks the same file for the nine-model schema makes Core Data
decide it must **migrate in place** — a write — and a read-only store refuses it with
`CoreData: error: (8) attempt to write a readonly database` / *"Cannot migrate store in-place"*.
`SharedModelContainer.shared` is therefore the **iOS** shape and only the iOS shape; the watch
complication uses **`SharedModelContainer.sharedCacheOnly`**. ⛔ **Nothing about that failure looks
like a failure**: the container is `nil`, `fetchEntry` takes its `guard`, and the face draws its
"Open to read today's passage" placeholder while the app two taps away shows the passage from that
very file. No build, no check and no crash log can see it — only a face can, and the error is in the
simulator's own log rather than anywhere Xcode surfaces. ⛔ **The watch also owes
`WidgetCenter.shared.reloadAllTimelines()` after every `WCSession` write**, as `DataService` does on
iOS: a complication does not observe the store, so without it the face keeps yesterday's passage
until its hourly timeline is up.

⛔ **This Mac has twenty watch simulators across three runtimes (11.2, 26.2, 26.5) and three ACTIVE
paired pairs**, so
nothing about watch testing is blocked on hardware. `xcrun simctl list pairs` names them; the one
already used is `E56C7939-…` — `iPhone 17 Pro Max` (`CE9761A7-…`) ↔ `Apple Watch Series 11 (46mm)`
(`D876968B-…`), both watchOS/iOS 26.5. ⛔ `build.sh`'s own watch leg still resolves an **unpaired**
`Apple Watch Series 10 (46mm)`, which is right for a compile and useless for `WCSession` — a session
cannot activate unpaired, and that is why the transport went unproved for so long.
⛔ **What a watch simulator CANNOT do is wear a complication on a face.** Every one of them ships a
single face, `Numerals Duo`, whose edit pages are STYLE and COLOR and which has no complication slot;
its face gallery's **GET** does nothing under a synthetic tap; and adding a face in the paired phone
simulator's Watch app adds it to the phone's list without ever reaching the watch, because simulator
pairing carries `WCSession` payloads and not faces. **The Smart Stack is the one real placement a
simulator offers**, and it takes `.accessoryRectangular` only.

⛔ **All five targets set `SWIFT_STRICT_CONCURRENCY = complete` and all five set
`SWIFT_VERSION = 6.0`, and the second makes the first a formality.** A clean tvOS build passes
`-swift-version 6` to `swiftc` and no `-strict-concurrency` flag at any of its 160 compile steps —
the Swift 6 language mode *is* complete data-race checking, so the setting only starts mattering
again if a `SWIFT_VERSION` ever drops to 5. Nothing was hiding behind it on the television.

⛔ **The project is FIVE targets now, and three facts about the watch's wiring are load-bearing.**
The iOS target embeds the watch app through `Embed Watch Content` (`dstSubfolderSpec = 16`,
`dstPath = $(CONTENTS_FOLDER_PATH)/Watch`), and **both that build file and the target dependency carry
`platformFilters = (ios, )`** — without them the **macOS** leg of `build.sh` dies with *"This target is
built for macOS but contains embedded content built for watchOS"*, because the one app target builds
for both. The complication lives in its own target, `ACIMDailyMinuteWatchWidgetExtension`, embedded in
the **watch app**'s `PlugIns/`, and ⛔ **its bundle id is `…watchkitapp.widget` because
`…watchkitapp.complication` is NOT AVAILABLE to this team** — automatic signing fails to register it
and then reports three misleading provisioning errors about App Groups. That is a portal fact, not a
build setting to fiddle with.

⛔ **SIGNING, ALL FIVE TARGETS, MEASURED RATHER THAN ASSUMED.** Four App IDs exist under team
`RR5DY39W4Q` and every one of them carries the App Group: `com.larryseyer.acimdailyminute` (plus
iCloud and `aps-environment`), `.widget`, `.watchkitapp` and `.watchkitapp.widget`. All four signed
real device builds today with `Apple Development: Larry Seyer (63S4HUDY4S)`. ⛔ **Xcode names watchOS
profiles "iOS Team Provisioning Profile"** — that is Apple's naming, not a mis-selected profile, and
it is worth knowing before someone chases it. ⛔ **The tvOS target shares the App ID
`com.larryseyer.acimdailyminute` with the phone and the Mac, deliberately** — one App Store record
carries both binaries — so the TV needs no App ID of its own and none should be created. **His
Apple TV is registered and signs a real tvOS profile** — see the device block at the top of this
file; the watch device situation is in [`todo.md`](todo.md).

⛔ **The whole app already compiles for watchOS, and that measurement decides the cost of anything
proposed for the watch.** A whole-module `swiftc -typecheck` of all 126 app + widget sources against
the watchOS SDK gives **45 errors in 16 files, 43 of them in `Views/`**; outside `Views/` there are
exactly two lines, `NotificationManager.swift:227` and `FolderCopyService.swift:144`. Every model,
every utility and every service compiles unchanged. So a watch feature costs a **view**, never a port.
⛔ **`-wmo` is not optional in that measurement**: plain batch `-typecheck` stops after the first
failing file and answers "1 error" where there are forty-five.

⛔ **Platform expansion Phase 1 is built and the nineteen checks are green.** The header keeps every
word at every text size, on a third band where it needs one; the mini player clears a tab bar it now
measures rather than assumes; the Archive and Saved tabs reserve room for it as the other thirteen
surfaces already did; and every `ScrollView` screen edge is 20pt. Two things `todo.md` asserted about
that phase were measured and were wrong — the redundant simulator legs and "visionOS is close to
free" — and both are corrected in place there rather than carried out. **The only thing left in
Phase 1 is the submission-time visionOS toggle**, which is an App Store Connect switch and not a
build.

⛔ **The compact slice is measured and it holds.** On the iPad Pro 11-inch (M5) simulator
`24B47A3C-…` in a 375pt window, the screen edge is **20.0pt leading and 20.0pt trailing** on a Today
card and on a pushed reading, `ReadableContentWidth` correctly stops clamping, and Today, Read,
Listen, Archive, Saved, the Archive calendar, the mini player, the floating tab bar and a reading's
footer all lay out with nothing broken and nothing cut off by width. ⛔ **iPadOS 26 has no Slide
Over — it has windows**, so the compact slice is reached by dragging the app window's own
bottom-right grab handle inward, and Settings > Multitasking & Gestures must be on **Windowed Apps**
for that handle to exist.

⛔ **The Archive stack declares `.readingDestinations(path:)` ahead of need, and that is deliberate.**
`ArchiveView` is the fourth stack to carry it. Nothing beneath it emits a link **yet** —
`ArchivedReadingCard` draws its body as plain `Text`, so no cross-reference is detected, and its
footer carries a book name and a date rather than a citation, so `CitationButton` never appears. The
line costs nothing and is owed the moment that card renders through `AnnotatableReadingText`, which
is an open item: a stack that draws a reading without it asserts in Debug and does nothing in
Release, and that failure is invisible until a reader taps.

⛔ **His five findings from the testing pass are built, and the `⏸ PARKED` block's first item is
what only his eyes can settle about them.** The version reads `1.0`; the five introduction cards carry
his copy, **broken a sentence to a line with literal `\n`** — the breaks are his, so a wrap he did not
set is a defect — with three spellings repaired and "Daily Messages" set as "Daily Minutes", which he
can veto; on the Mac the introduction's chevrons stand at the sides, halfway up and 34pt, with the
dots at the foot; Settings > Appearance offers System / Light / Dark with Dark the default and a palette that
resolves per appearance (`Views/ACIMColors.swift`, four colorsets, AccentColor darker in Light); the
Daily Minute and the Daily Lesson each have a reminder with a switch and a time of their own; the
watched phrases are gone whole, with the fetch-driven "new minute / new lesson" alerts, which would
have doubled the timed reminders; and **practice reminders follow the Workbook lesson the reader is
on** — see the ⛔ facts about them below. Card 4 of the introduction says notes and highlights "are
stored across all devices", which is true only with iCloud sync on; his wording, kept, flagged.

⛔ **The practice reminders keep three promises, and `tools/verify_practice_reminders.sh` holds
all three.** `Resources/WorkbookPractice.json` is 365 records, one per lesson, authored from every
lesson's own instructions (or the review introduction that holds them) with the sentence each rests
on; `Utilities/PracticePlanner.swift` is pure and turns a record, the reader's day window
(`practiceWindowStart/EndInterval`, default 07:00-22:00) and the current lesson into dated requests
over a **three-day horizon under a budget of 56** (iOS keeps 64 pending requests and drops the oldest
silently); `Services/PracticeReminderService.swift` is the thin layer that reads the keys and hands
the plan to `NotificationManager.replacePracticeReminders`, which replaces by **prefix scan of
`acim.practice.`** and nothing else. **No reminder is ever planned more often than every half hour** —
lessons 27, 40, 75 and 122 ask for every ten to twenty minutes and get the half-hour mark with the
text's own cadence in the body. **Every request is `interruptionLevel = .active`, never
`.timeSensitive` or `.critical`** — a Course lesson is not an emergency and Focus is the reader's —
and the harness greps the app tree for it. The current lesson is `PracticeAnchorStore` (device-local
`practiceAnchorLesson/Day`, fed by `DataService.persistLesson`, the background refresh and a fold over
the store whenever a `ModelContext` is at hand), overridden by the reader's own place
(`practiceOwnStartLesson` + `practiceOwnStartDay`, advancing one lesson per calendar day, stopping at
365). The publisher's sequence advances one per weekday and Saturday and Sunday repeat Friday. A
publication day is UTC midnight and is carried into the reader's zone **by its name**, never as an
instant — west of Greenwich that instant is the evening before. Reschedule sites: every return to the
foreground (both platforms; the macOS path), `BackgroundRefreshManager` (its whole job now),
`persistLesson` on a new lesson, every Settings change, and a settings restore. Three interpretive
calls are in the data and are his to veto: 154-170, 171-180 and 181-200 carry the Lesson 153 form
forward (the text names no other and 193 restates it), and Part II sessions are `minutes: 0` — "as
long as you can" — rather than an invented number.

⛔ **The appearance is applied to the WINDOW, never through `preferredColorScheme`.** Passing that
modifier `nil` after an explicit scheme does not take the scheme back — the window keeps the last
one it was given — so Dark → Light → System left the reading card light on his Mac while the
Settings sheet, a new window asking the system, came up dark. `Appearance.apply` sets
`UIWindow.overrideUserInterfaceStyle` on iOS and `NSApp.appearance` on the Mac, and `.unspecified` /
`nil` there really do return to the system; the App calls it on appear, on change and on every
return to the foreground. The introduction forces dark for its own subtree with
`.environment(\.colorScheme, .dark)` for the same reason: a scheme handed to the window would have
outlived the cover. Both machines carry it.

⛔ **A reminder tap lands where a URL would.** `NotificationDelegate.didReceive` posts
`.reminderTapped` with a `DeepLinkRoute`, and `ContentView.follow(_:)` is the one switch both a URL
and a tap go through; `.lessons` (the Read tab, no number) exists for the Daily Lesson reminder,
which is repeating and cannot know its number.

**The pipeline scheduler is his, running on MacLive, armed for 02:00 nightly.** Do not start a second
one. MacLive is an SMB mount of another machine (`//...@Chat._smb._tcp.local/MacLive`), so `pgrep`
from this Mac cannot see its processes — read `logs/acim.log` **on that machine** instead, and run
`./start.sh` there, never through the mount.

⛔ **The reader's place in a book is a `ReadingPosition`, one per book, and it is NOT a
`ReadingSpotlight`.** A spotlight is a pointer that is never stored and it *paints*; a ribbon is
stored, travels in the backup file, and scrolls without marking anything — a reader's place is not a
reader's mark. `Utilities/ReadingPosition.swift` is the pure value, the book rule and the merge;
`Services/ReadingPositionStore.swift` is the only thing that touches `UserDefaults` for it; and
`AnnotatableReadingText` is the only thing that reads or writes one, on the three reading SCREENS
that pass `recordsPosition: true`. **A new reading screen owes that line; a card owes nothing** —
a Today card sits inside another scroll view, so the character at the top of its text view is not
where the reader is. A Daily Minute and a Manual cut derive no book and can never set a ribbon; the
Manual joins when piece E gives it a structure to resume into.

⛔ **Ask a text view for a rectangle through `textLayoutManager` after `ensureLayout(for:)`, never
`firstRect`.** **TextKit 2 lays out what is on screen and nothing else**, so a passage below the fold
answers with a rectangle of zero height — which is the same shape as "not laid out yet", and a retry
loop cannot tell the two apart. It is why a search hit near the top of a section scrolled and the
same hit two screens down silently did not. The retry budget is twelve attempts at 100ms, also
measured: three at 150ms never once caught a freshly pushed reading in time. **This lives on the iOS
side only** (`laidOutRect(of:in:)` there and nowhere else) — see the asymmetry below.

⛔ **A READING IS MEASURED WITH THE ENGINE IT IS DRAWN WITH, AND `lineSpacing` IS WHERE THE TWO PART
COMPANY.** Both text views come up on **TextKit 2** — a `UITextView` and an `NSTextView` from their
plain initialisers — so `ReadingTextMeasurement` is `NSTextLayoutManager` +
`usageBoundsForTextContainer`, and never `NSLayoutManager.usedRect`. The two engines agree to the
point at `lineSpacing: 0`, which is what the Today cards pass, and disagree at every non-zero value:
at the **`lineSpacing: 3` all five reading SCREENS pass** — Text section, lesson detail, Workbook
introduction, Manual segment, Segment reading — TextKit 1 measured about **7% short on iOS and 2.5%
on macOS**, and the text view clipped the tail of the passage into a box too small for it. On T-1.3
that was **290 characters, four sentences, gone off the end with `Add note` and the citation drawn
tidily beneath them and nothing to scroll to.** ⛔ **Nothing about it looked like a failure** — no
crash, no log, no warning, and the cards read whole. ⛔ **Reading `view.layoutManager` anywhere
downgrades an `NSTextView` to TextKit 1**; `textLayoutManager` is the only accessor that keeps the
measurement and the drawing on one engine. TextKit 2 is not the slower choice either: on the largest
body in the bundle, 34,385 characters, it measures in 9.2ms against TextKit 1's 9.9ms at 335pt, so
no cache is owed and none exists.

⛔ **Every reading in this app has ONE shape, and `Views/ReadingScaffold.swift` owns it.** Four
bands, always: header, title block (optional), body, footer. All eleven render sites pass slots and
position nothing themselves — that is the whole point, because a surface that positions nothing
cannot disagree with the others. Container chrome — a card's padding and background, a screen's
`ScrollView` and readable width — stays with the surface. **The scaffold owns the ORDER of the bands
and nothing inside one**, which is what keeps a layout change from becoming a rewrite of what the
readings say.

⛔ **The header is two bands on every surface and every screen size** — the eyebrow centred on its
own line, then **Listen on the leading edge, Share and Save on the trailing edge**. `CardHeaderRow`
owns it inside the scaffold; `ListenButton`, `SaveButton` and `ShareButton` are the shared controls
and nothing hand-rolls its own. **The play control is leftmost on purpose**: most readings have no
audio, so it is usually absent, and anchoring it there is what stops Share and Save moving between
passages. **Save belongs in that header, never in a nav toolbar.** His layout decisions — do not
undo them without asking.

⛔ **The nav bar names the BOOK** (Text, Workbook, Manual for Teachers) **and the eyebrow names the
place** (`LESSON 84`, `CHAPTER 17`), so no screen says the same phrase twice. A Text section stacks
its chapter title above its section title, in the title block: chapter titles reach 35 characters and
the eyebrow band breaks its words rather than wrapping or shrinking. ⛔ A footer address is tappable
ONLY where it names somewhere else — the Today cards; on a pushed screen it names the passage already
on screen and is printed plain. The footer's slots are an **address** and a **measure**, named by
position, which is how the Archive fits with a book name and its date.

⛔ **The header grows a THIRD band at the accessibility text sizes, and that is the design rather
than a fallback.** Three controls cannot share a line once `Listen` is 182pt wide, so `ViewThatFits`
gives the play control a band of its own and leaves Share and Save on the trailing edge of the next —
the block grows downward and nothing reorders, which is the same trade the title band already makes.
Below the accessibility sizes the one-band form is used and nothing moved. ⛔ **`lineLimit(1)` +
`fixedSize(horizontal: true)` does NOT prevent a squeeze** — that was the belief this rested on and it
is false. Under real constraint SwiftUI compresses the label anyway, and for the eyebrow, which cannot
be compressed, it overflows the card instead: `WORKBOOK FOR STUDENTS` drew 569.5pt wide inside a 303pt
card and dragged the whole block's width with it, which is what pushed Save outside the card. So the
eyebrow **wraps** at the accessibility sizes only. Wrapping is not the `DAILY MINU…` that was
rejected — that was truncation, and every word survives here.

⛔ **`tools/verify_card_header.sh`, the tenth check, guards the whole shape**: the layout measurement,
every eyebrow string measured at 303pt, and four greps — nine surfaces draw through the scaffold,
only the scaffold names `CardHeaderRow`, Save is in no nav toolbar, no Listen control is hand-rolled.
Each grep is negative-tested; adding a reading surface means adding it to that list. It runs on macOS
and therefore sees **no** text size at all; `verify_card_header_dynamic_type.sh` is the other half.

⛔ **Every `ScrollView` screen edge is 20pt, and that is now one number rather than three.** Today,
the three lesson-detail states, the Workbook Introduction, the Manual, the Segment reading, the
companion note, the Archive calendar, the Archive date detail and the Read and Saved shelf headers all
use it. ⛔ **The `List`-based surfaces are NOT in that set and must not be dragged into it** — the
Workbook spine, the Read search results, Listen, the Archive search results and all three Saved lists
take system row insets, which are not a literal anyone can match. ⛔ A 16pt `.padding(16)` inside
`DailyMinuteCard`, `DailyLessonCard`, `CorpusReadingCard`, `ArchivedReadingCard`, the Listen YouTube
card and the companion note's closing callout is **inside-card** padding — the card's background hugs
its own content — and so are `ReadingScaffold`'s 8pt chip and `LessonRow`'s 10pt badge. Leave all of
them alone. The padding is applied outside `.readableContentWidth()` at every site.

⛔ **His phone gives the app a 375pt canvas, not 414pt.** The Pro Max runs **Display Zoom** — his
screenshots are 1125x2436 rather than the native 1242x2688, exactly 0.906x — and his Dynamic Type is
about `xxLarge`. **Check every width assumption against 375pt.** When a row wants more width than it
has, SwiftUI drops nothing and warns about nothing: it breaks the words.

⛔ **A control that appears because DATA changed has never been drawn by anyone.** **The Listen tab's
Download action and the Today card's Listen button are LIVE now and still undrawn by any eye** — the
feeds carry archive.org `audio_url` on every recorded episode, so both appeared on the phone with no
app change. The swipe is system-drawn and collapses to icons when narrow, so there is no word for it
to break; it is in the `⏸ PARKED` block to be looked at once at 375pt, not to be built.

**The feeds carry the archive.org URLs.** `daily-minute.json` 157 of 164 archive entries plus today,
`daily-lesson.json` 84 of 84 plus today, `podcast-minute.xml` 158 enclosures of 165, `podcast-lessons.xml`
85 of 85, and all 243 recorded MP3 URLs answer a ranged GET. The seven minutes without one are
2026-03-20 … 03-26, which have no recording. Two catch-up gaps remain, **2026-05-31 and 08-14**; the
nightly run fills one per night. ⛔ SQLite has never been opened read-write across SMB and must not
be; the pre-landing copy of the live database is kept at
`untracked/archive-backfill/acim.db.live-backup-before-landing-20260901-163242` if it is ever needed.

**Build state — the phone and the Mac both carry the current commit, launched.** `./build.sh`, the
arm64 device build and the nineteen checks are green. ⛔ `./build.sh` is FOUR LEGS building FIVE
TARGETS — iOS, macOS, watchOS and tvOS, and the watch leg now builds the complication extension
beside the watch app — and "all 3 targets" anywhere is stale. `/Applications` holds the signed macOS copy,
running, with the widget registered as `com.larryseyer.acimdailyminute.widget` and
`practiceAnchorLesson` holding the newest lesson from the store. On the phone
`ACIMDailyMinuteWidgetExtension` is alive, which is the proof the schema is clean since the extension
is what `fatalError`s on a mismatch, and **he is using the build.** **The plan the app hands the
notification center is one line, `[PracticeReminders] N planned, <first> … <last>`, on stdout of a
Debug build**; `open -a` swallows stdout, so launch the binary inside the bundle from a terminal to
read it, with the practice switch on. For a Review II lesson (two sessions, no clock) in the
afternoon it reads five: the evening, then morning and evening for each of the next two days, a
weekend repeating Friday.

⛔ **A reading is scrolled to on iOS and never on macOS, and the asymmetry is the fix rather than a
gap.** A `UITextView` has its own scrolling switched off, so asking the enclosing scroller to bring a
line into view moves only that scroller. An `NSTextView` is vertically resizable — that is what lets
SwiftUI size it — and the same request moves **its own bounds inside the frame it was given**: the
reading then draws forty points above where it was laid out, over the top of its own title, while the
title stays put. macOS has no `isVerticallyResizable = false` that leaves a reading measurable.
So a spotlight and a ribbon both open a macOS reading at its **top**, which is what macOS has always
done — `firstRect` returned an empty rectangle there for anything below the fold, so that scroll had
never once fired. Doing it properly means scrolling from the SwiftUI side; it is on the ledger.
- 📱 **iPhone 11 Pro Max** (UDID `00008030-0004299C1410802E`) — Debug, install current, launched,
  `ACIMDailyMinuteWidgetExtension` alive, which is the proof the schema is clean since the extension
  is what `fatalError`s on a mismatch. It has run its one-time reader migration.
  **iCloud sync is ON here now** — he switched it on and proved it carries a highlight both ways with
  the Mac. No folder is chosen, its default.
  ⛔ **`devicectl device info processes` showing none of them means nothing is wrong** — the app is
  simply not open. It is a check to run *after* launching, never a way to ask what is installed.
  ⭐ **This is where he tests.** ⛔ A `devicectl install` returning
  `CoreDeviceError 4000, "the device disconnected immediately after connecting"` is the phone, not the
  build — retry once before believing it. A locked phone refuses `process launch` with
  `FBSOpenApplicationErrorDomain error 7` — and, from a `devicectl` on this Mac, with
  `CoreDeviceError 10002` / `FBSOpenApplicationServiceErrorDomain error 1` naming `Locked` in the
  failure reason. That is the lock, not the build; the install still lands while it is locked.
- 💻 **This M4 MacBook Pro** — `/Applications/ACIMDailyMinute.app` is current: arm64, signed team
  `RR5DY39W4Q`, widget extension registered as `com.larryseyer.acimdailyminute.widget`; he adds it
  from **Edit Widgets**. Not running is the ordinary state, not a fault. Confirm with `codesign -dv`
  and `pluginkit -mAv -p com.apple.widgetkit-extension`, which answer without launching anything.
  **iCloud sync is ON here now**, and it is what makes an unentitled copy crash rather than merely
  lack a widget — see `./build.sh` below. No folder is chosen — `defaults read com.larryseyer.acimdailyminute`
  shows no `folderCopy` key.
  ⛔ **A reading position of mine is in this Mac's defaults** (`readingPositions`, the Text ribbon
  pointing at `text:5.3`) — a test fixture, harmless, and replaced the moment he reads anything in
  the Text. `defaults delete com.larryseyer.acimdailyminute readingPositions` clears it if the
  Read tab should start empty. ⛔ **`build/Debug/` is the macOS product.**
  `build/Debug-iphonesimulator/` also contains an `ACIMDailyMinute.app`, and a `find` that is not
  anchored hands you the wrong one — check `codesign -dv` says `TeamIdentifier=RR5DY39W4Q`.
- 📱 **His "Quantiloop iPad" CANNOT run this app, and it is not a signing or cable problem.**
  It is an `iPad6,3` — a 9.7-inch iPad Pro — on **iPadOS 16.7.16**, which is that model's ceiling,
  against an `IPHONEOS_DEPLOYMENT_TARGET` of **17.0**. Lowering the floor is not a setting: the app
  is built on `@Observable` / the Observation framework, which is iOS 17+. ⛔ **His "Lyrics iPad"
  (`iPad7,5`, iPadOS 17.7.11) WILL take the build** and is the device for the Slide Over check.
  ⛔ `system_profiler SPUSBDataType` prints **nothing at all** on this Mac and is worthless for
  finding a connected device — `ioreg -p IOUSB -l` and `ideviceinfo -u <udid>` are what answer.
- 📱 **iPad (10th gen) sim** `58B7D31D-70BB-4286-BBB7-09ADDE1F3EF4` — driven only by `./build.sh`'s
  compile step. ⛔ **He has asked that it not be driven.** Other apps control this computer.

⛔ **A green `./build.sh` proves less than it looks like it does:**
- `./build.sh` = **four legs over five targets** — iOS sim, macOS, watchOS sim, tvOS sim, and the
  watch leg builds the complication extension beside the watch app — **compile-only**, and it passes `CODE_SIGNING_ALLOWED=NO` for macOS, so
  that binary has no entitlements, cannot open the App Group, and its widget is invisible to the system.
  ⛔⛔ **Now that iCloud sync exists, copying that product into `/Applications` CRASHES the app**, and
  the crash names CloudKit rather than the mistake: with sync switched on, `NSCloudKitMirroringDelegate`
  asks for a `CKContainer` the unentitled process may not have, and CloudKit traps on a background
  queue — `EXC_BREAKPOINT` in `PFCloudKitContainerProvider containerWithIdentifier:options:`. The
  tell before the crash is macOS asking for **"access data from other apps"**: a properly signed copy
  owns the App Group and never asks. **Check `codesign -dv` says `TeamIdentifier=RR5DY39W4Q` before
  copying anything into `/Applications`** — `Signature=adhoc` and `TeamIdentifier=not set` is
  `build.sh`'s output, and running `./build.sh` after the signed build overwrites `build/Debug/` with
  it.
- `./both.sh` = the above **plus install/launch on the sim and the phone**. It drives the sim.
- `./bu.sh "msg"` is **not a build**: `git add .` + commit + push + Dropbox zip.
- **Phone only, no sim:** `xcodebuild -scheme ACIMDailyMinute -configuration Debug -destination
  "platform=iOS,id=00008030-0004299C1410802E" -derivedDataPath build ONLY_ACTIVE_ARCH=YES build`, then
  `xcrun devicectl device install app --device <UDID> build/Debug-iphoneos/ACIMDailyMinute.app` and
  `process launch`. ⛔ **A locked phone refuses `process launch` with `FBSOpenApplicationErrorDomain
  error 7` and can drop the install connection entirely** — that is the lock, not the build. Check with
  `xcrun devicectl device info processes`; **the widget extension process being alive is the proof** of
  a clean schema.
- **macOS + widget:** `xcodebuild -scheme ACIMDailyMinute -configuration Debug -destination
  "platform=macOS" -allowProvisioningUpdates DEVELOPMENT_TEAM=RR5DY39W4Q -derivedDataPath build build`,
  copy `build/Debug/ACIMDailyMinute.app` to `/Applications`, launch once. Verify with
  `pluginkit -mAv -p com.apple.widgetkit-extension | grep -i acim`.
  ⛔ Quit the running copy first, or `rm -rf /Applications/ACIMDailyMinute.app` fails mid-flight.
- **Real SwiftData migrations can be proved here without the phone, against real annotations.**
  `~/Library/Group Containers/group.com.larryseyer.acimdailyminute/` holds three files:
  `reader.store` (2 highlights, 2 notes, 0 bookmarks), `cache.store` (the feed caches), and
  `ACIMDailyMinute.sqlite`, the pre-split file kept untouched as the recovery copy. Back the directory
  up first, launch the signed build, then read `.tables`, row counts and `sqlite_master` indexes with
  `sqlite3`. ⛔ Those two highlights and two notes are the only real annotation data reachable from
  here — treat them as precious and back them up before any store work. The most recent copy is
  `untracked/group-container-backup-<stamp>/`, taken before the current build was launched.

⛔ **Nineteen committed checks now guard this repo. Run all nineteen first thing — they take about
three minutes and they are how you find out the tree is what this file says it is.** Seventeen are
`swiftc` harnesses that run anywhere; two boot or target another platform, for reasons they record:
- `python3 tools/text_paragraphs.py` — the Text is display form, no page furniture, no mid-sentence
  paragraph break, no letter-spaced heading left inline. **272 sections, 2,949 paragraphs.**
- `python3 tools/punctuation_spacing.py` — no run-together punctuation survives in any of the five
  bundled files, and the record counts are 272 / 365 / 1,983 / 105 / 2.
- `./tools/verify_spacing_agreement.sh` — compiles `PunctuationSpacing.swift` with `swiftc` and proves
  Swift's rule and Python's are the same rule over 3,046 cases: every left/right character pair the
  rule can distinguish, every shape of the possessive, and every body in the shipped bundle.
- `python3 tools/verify_citations.py` — every citation in the bundle is real and resolves to the
  paragraph it names: 1,983 segments, 1,263 in the Text, 609 in the Workbook, 6 unresolved and
  105 Manual carrying a book name instead. The six that remain are the Workbook's closing
  lessons, where the words recur and the locator refuses an ambiguous probe rather than guess.
- `./tools/verify_citation_agreement.sh` — compiles `Citation.swift` with `swiftc` and proves Swift's
  format and paragraph rule and Python's are one rule over 1,844 cases — including all 1,705
  citations actually in the shipped bundle, each of which must parse and round-trip in Swift.
  Python writes segment citations at export; Swift derives section, lesson and highlight
  citations at render. Drift would make the
  same passage cite differently depending on which tier it came from, and nothing about that failure
  looks like a bug.
- `python3 tools/verify_corpus_coverage.py` — ⛔ **the only check that can see an ABSENCE.** The
  other five ask whether what is in the bundle is well formed; none of them could tell that 12,000
  characters of the Text had never been there at all. The segments are a continuous cut of the same
  PDFs, so anything present there and missing from the readable corpus is missing text. Zero gaps of
  60+ characters in the Text, zero in the Workbook, all 105 Manual rows accounted for.
- `./tools/verify_backup.sh` — ⛔ **the only check that guards a reader's OWN words rather than the
  book's.** 599 assertions: the backup file round trips, refuses a foreign or newer file, and the
  merge is idempotent, commutative, associative and loses no passage of any note. 232 of the
  highlights it drives are cut from the shipped corpus at real offsets, so the em dashes, curly
  apostrophes and restored spaces are the real ones. **It compiles `BackupDocument.swift` and
  `BackupMerge.swift` and nothing else, and that is half the check** — those two files must stay
  free of SwiftData, SwiftUI, `Bundle` and `CorpusService`, or a reader's backup starts depending on
  the app it exists to outlive.
- `./tools/verify_text_measurement.sh` — ⛔ **the only check that guards the BOX rather than the
  words.** 902 measurements over 45 real bodies at five window widths and both line spacings: every
  reading occupies real height, at least one line of it, never shorter as the window narrows, a body
  twenty times longer is more than twice as tall, and — the rule that matters most — **the measured
  height equals what a real text view lays out, to the point.** **It compiles
  `ReadingTextMeasurement.swift` and nothing else**, which is what keeps the measurement free of
  SwiftUI and therefore checkable at all. ⛔ A reading measuring zero does not crash and no other
  check can see it: the card collapses and the text draws over `Add note` and the citation. ⛔ A
  reading measuring a few percent SHORT is worse, because it looks like nothing at all — see the
  TextKit rule below. The agreement rule builds an `NSTextView` set up exactly as
  `SelectableReadingText.makeNSView` sets one up, and ⛔ **it must never read `view.layoutManager`**:
  that property downgrades the view to TextKit 1, and the check would then agree with the defect.
- `./tools/verify_bookmark_identity.sh` — ⛔ **the only check that guards a reader's SAVE.** 381 cases
  over `BookmarkIdentity`, and **it compiles that one file and nothing else**, which is what keeps the
  rule free of SwiftData and therefore checkable. `Bookmark` has no `id` — `itemKey` is its whole
  identity — so it proves that a save is an involution, that ONE un-save removes EVERY row holding a
  key rather than the first, that a re-key onto an occupied address folds rather than collides, that
  the survivor keeps the earlier `createdAt` exactly as `BackupMerge` does, and that no rule depends
  on the order a fetch returned rows in. All three failures it guards are silent: a half-deleted
  duplicate makes un-save do nothing, and a collision throws today's minute out of `persistMinute`.
- `./tools/verify_card_header.sh` — ⛔ **the only check that guards the STRIP ABOVE a reading.**
  371 cases, and **it compiles `CardHeaderRow.swift` and nothing else**. When a title and its controls
  want more width than the card has, SwiftUI drops nothing and warns about nothing — it squeezes the
  only squeezable things, which are the words. It proves the block is two bands at every width from
  90pt to 672pt with no word ever broken, that Share precedes Save on the trailing edge, and that
  **neither moves when the play control appears** — which is what the leading play control buys, since
  most readings have no audio and that button is usually absent. ⛔ Its height check now runs only at
  240pt and above: the control band deliberately becomes TWO bands on a narrow card at a large text
  size, and height alone cannot tell that apart from a wrap. Below that line the Dynamic Type check
  carries it, by measuring width instead.
- `./tools/verify_card_header_dynamic_type.sh` — ⛔ **the only check that guards the header at a
  reader's TEXT SIZE, and the only one that does not run on this Mac.** 1,285 checks over 12 Dynamic
  Type sizes and 10 widths. **`dynamicTypeSize` does nothing on macOS** — `Text.font(.caption)`
  measures 30.5x13.0pt at every size from xSmall to accessibility5 under `ImageRenderer` there — so a
  sweep written like the other seventeen would pass without measuring anything. This one compiles for
  `iphonesimulator` and runs under `simctl spawn`, where the same text is 35.5pt at `large` and
  115.0pt at `accessibility5`. It compiles `CardHeaderRow`, `ListenButton`, `SaveButton`,
  `ShareButton` and `ACIMColors` — **the real controls, because a `Color.clear` placeholder cannot
  grow with text size and would hide the whole defect** — and greps all four for a store, a service
  or a session. It boots an iPhone SE (3rd gen) headlessly and shuts down only a device it booted.
  ⛔ It never drives the iPad sim. What it caught: `Save` drawn 99.5pt against a natural 150.5pt on
  his 303pt card, and the eyebrow `WORKBOOK FOR STUDENTS` drawn **569.5pt wide inside 303pt**.
- `./tools/verify_folder_copy.sh` — ⛔ **the only check that guards the FOLDER a reader chose.**
  27 cases against a real directory on this Mac, and **it compiles `FolderCopy.swift` and
  `BackupDocument.swift` and nothing else**. A real encoded backup lands, reads back byte for byte,
  and a second write replaces rather than accumulates; a folder renamed after it was chosen is still
  found, and the refreshed bookmark resolves straight to it; a read-only folder refuses the write
  and leaves the previous copy intact with no temporary file behind; a deleted folder, a plain file
  and garbage bookmark data all come back as `folderMissing` with the sentence the reader sees,
  never a crash.
- `./tools/verify_schedules.sh` — ⛔ **the only check that guards a PROMISE about the future.**
  37 cases, and **it compiles `LessonSchedule.swift` and `MinuteSchedule.swift` and nothing else**.
  A lesson the publisher has not recorded is told the weekday it lands, counted from the newest
  dated recording and never from a dateless one; a day the Daily Minute run missed is told its
  place in the line of missed days, which the nightly run clears one per night oldest first, with
  the real feed's two gaps (05-31, 08-14) as the case; a future day publishes on itself; a day
  before the first is before the archive; an empty archive says nothing. Every sentence names its
  day as `yyyy-MM-dd` in the publisher's zone.
- `./tools/verify_corpus_search.sh` — ⛔ **the only check that guards the ADDRESS of a match.**
  Over all 744 readable records it proves the fold is one character in and one out, that every
  hit's range holds the folded query, that hits come back in book order without overlap, that
  the 1,000 cap holds and is reported, that snippets cut on word boundaries, and that a passage
  cut from a record at a known offset is found at that offset — 9,796 checks. **It compiles
  `CorpusSearch.swift` and nothing else** — no SwiftUI, SwiftData, `Bundle`, `CorpusService`,
  `ReadingKey` or `Citation` may enter that file — the compile pins the three repo types, and a
  `grep` in the same script pins the two frameworks and `Bundle`, because a lone-file `swiftc`
  would link those without complaint.
- `./tools/verify_cross_references.sh` — ⛔ **the only check that guards where a TAP goes.**
  Over all 2,727 bundled records it proves the bracket rule finds exactly the 150 lesson
  numbers the 70 review lessons print, each earlier than its host, none in the Text, the Manual,
  the Introductions or any segment not cut from the Workbook; that the reader's own blanks
  (`[name of person]`) are not links; and that the link's URL decodes back to the same lesson
  for all 365 and refuses everything else — 5,215 checks. **It compiles `CrossReference.swift`
  and nothing else**, and a `grep` pins the frameworks a lone-file `swiftc` would link without
  complaint. That `grep` strips comments first: what must stay out of the file is a dependency,
  and the doc comment names `CorpusService` and `ReadingKey` precisely to say it uses neither.
- `./tools/verify_reading_position.sh` — ⛔ **the only check that guards WHERE A READER GOT TO.**
  Over all 272 Text sections, 365 lesson bodies and 2 Introductions it proves that a position keeps
  its offset and its words, that at **every one of 3,606 paragraph starts** a 120-character quote cut
  there re-anchors to that same offset, that it still does after the spacing repair has moved the
  display, that a wild offset is clamped and gone words open the reading at its top, that garbage and
  an unknown book name yield no ribbon rather than a crash, and that the merge is idempotent,
  commutative, associative and never moves a book's ribbon backwards — 20,815 checks. **It compiles
  `ReadingPosition.swift`, `ReadingKey.swift`, `AnchorResolver.swift` and `PunctuationSpacing.swift`
  and nothing else**, with a `grep` over all four pinning SwiftUI, SwiftData, `CorpusService`,
  `UserDefaults` and `Bundle`.
- `./tools/verify_reading_time.sh` — ⛔ **the only check that guards a number the app states with
  confidence.** Over all 2,727 bundled records it proves no reading reads "about 0 min", that the
  wording changes at exactly 200 words, that the longest Daily Minute never contradicts the name on
  the card above it, and that `ReadingTime.wordCount(of:)` agrees with Python's `str.split()` on
  every body — it splits on newlines as well as spaces, because a space-only split reads
  "end.\n\nBegin" as one word. **It compiles `ReadingTime.swift` and nothing else** — 8,193 checks.
- `./tools/verify_practice_reminders.sh` — ⛔ **the only check that guards a phone BUZZING at the
  wrong time.** 544,486 checks: the 365 records decode and are the cadence the text states at
  twenty spot-checked lessons; every lesson × five windows (including an inverted one and a
  half-hour one) × three times of day plans without a crash, under budget, strictly ascending, every
  reminder after now, inside the window, no clock stop on the window's edge, every identifier
  carrying the prefix and parsing back to its own fire time; the drop order at budget 56, 6 and 0;
  the weekday walk and the reader's own sequence across a weekend, a DST change and the 365 cap;
  and the words. **It compiles `PracticePlanner.swift` and `LessonSchedule.swift` and nothing
  else**, greps the planner for SwiftUI, SwiftData, `UserDefaults`, `Bundle` and `Date()`, and greps
  the whole app tree for `timeSensitive` and `.critical`.
- `./tools/verify_watch_offline.sh` — ⛔ **the only check that guards what the WATCH can say with no
  phone and no network**, and the only one that reads the project file rather than the source tree.
  It parses the watch target's own Sources and Resources phases out of `project.pbxproj`, typechecks
  that exact source list against the **watchOS SDK** with `-wmo`, then builds a directory holding
  **exactly the JSON the watch's Resources phase names** and asks `CorpusFallback` to answer out of
  that and nothing else — 1,501 checks over 400 days: always a passage, the same passage for the same
  day, always an address or a book name, and the staleness rule the phone's Today tab shares.
  ⛔ **The defect it exists for is silent.** `CorpusService.load()` returns `[]` for a file missing
  from the bundle — no crash, no log — so a corpus JSON dropped from the watch's Resources phase
  compiles green, ships, and shows a blank wrist. Every other check reads
  `ACIMDailyMinute/Resources/` directly and therefore cannot see it. It also pins two rules that were
  comments until now: the watch asks for `includeReader: false` and never `true`, and its
  entitlements carry no iCloud key. All three failure paths are negative-tested.

⛔ **Design documents are NOT in git.** `.gitignore:54` ignores `docs/` on purpose. They live only on
this Mac:
- `docs/superpowers/specs/2026-08-30-timeless-corpus-design.md` + its plan — implemented.
- `docs/superpowers/specs/2026-08-30-reader-annotations-design.md` + its plan — implemented.
- `docs/superpowers/specs/2026-08-30-text-reading-ui-design.md` + its plan — implemented. Three places
  where the code is ahead of the plan's text, all deliberate: the recovery drops a *shallow* all-caps
  running head as well as a centred one; a semicolon joins the colon as a legitimate paragraph
  terminator; and the two Part Introduction rows take their titles from the corpus rather than from
  literals.
- `docs/superpowers/specs/2026-08-30-canonical-citations-design.md` + its plan — implemented.
- `docs/superpowers/specs/2026-08-30-portable-reader-data-design.md` + its plan — **all five steps
  implemented.** The plan covers step 1 only; steps 2-5 were planned in session. Places where the
  code is ahead of the spec's text, all deliberate: `AnnotationExport.Entry` gained an `id` so the
  backup can join a citation to a particular highlight without matching on its quote; the file
  records milliseconds while the store keeps full precision, so `BackupMerge` compares dates at the
  format's own resolution rather than with `<`; and the folder tier writes a **stable, per-device
  filename** — `ACIM Daily Minute backup (<device>).json` — rather than the dated one the Save
  button uses, so the folder never fills and two machines sharing it never race on one name.
- ⛔ **The chapter-opening recovery has NO design document.** Its only written record besides
  `tools/chapter_openings.py`'s own docstrings is an approved plan at
  `~/.claude/plans/iridescent-moseying-engelbart.md`, outside the repo.
  One judgement in it is his and was taken deliberately: the recovered Preface front matter is a
  single section titled `Publisher's Note`, even though the source sets a letter-spaced
  `p u b l i s h e r ’s n o t e` heading part-way through it, which would justify splitting it in
  two. The heading is stripped; ask before splitting.
- `docs/superpowers/specs/2026-09-02-corpus-search-design.md` + its plan — implemented, all six code
  tasks. Places where the code is ahead of the spec's text, all deliberate: the spotlight paints
  `systemBlue`, not the accent (the accent is gold); the two `scroll` helpers use `Task { @MainActor
  in }` rather than `DispatchQueue.main.asyncAfter`, because the latter's closure is `@Sendable`
  and cannot capture a text view under strict concurrency; and `BookmarkRow` gained a Manual
  branch the spec did not name, because the Manual screen offers Save.
- `docs/superpowers/specs/2026-09-02-cross-reference-links-design.md` + its plan — implemented, all
  five code tasks. The Course was measured before it was designed: it never cites itself by
  address, so nothing of the app's own `T-5.3` shape is detected in prose; the review lessons'
  bracketed numbers are the one numbered self-reference, and they are the only in-prose link.
  Two places where the code is ahead of the plan's text, both deliberate: `OpenReadingAction` is
  `Sendable` with a `@Sendable` handler, because an `EnvironmentKey`'s `defaultValue` is a
  nonisolated static under complete strict concurrency; and the harness accepts `[5][` as the
  reference `[5]` followed by a stray bracket, because Python's `\[(\d+)\]` — the oracle for all
  2,727 records — reads it that way and the two must not disagree.
- `docs/superpowers/specs/2026-09-02-resume-where-you-stopped-design.md` — implemented. One place
  where the code is ahead of the spec's text and it is written into the spec: the row sits **above**
  the shelf rather than at the head of its list, because the Workbook spine scrolls itself to the
  lesson in play and carried a row inside that list off the screen.
- `docs/superpowers/specs/2026-09-02-standardized-reading-layout-design.md` + its plan —
  implemented, piece A of five. The other four (D Archive to Video, E structure the Manual, B media
  index, C Listen as activity) are `⏸ PAUSED` in todo.md and are his to resume; **D is next.**
  Two places where the code is ahead of the plan's text, both deliberate: `ReadingTime.wordCount(of:)`
  exists because a space-only split undercounts every newline-joined body, and the Archive's footer
  carries a book name and its date rather than a citation and a read time, which is why the footer's
  slots are named by position — an address and a measure.
- `docs/superpowers/specs/2026-08-30-punctuation-spacing-repair-design.md` — implemented. Two places
  where the code is ahead of the spec's text, both deliberate: `PunctuationSpacing.swift` lives in
  `Utilities/` rather than `Views/`, because the widget and watch targets compile it too; and the
  widget and Live Activity are repaired where their `minuteText` is *produced*
  (`ACIMDailyMinuteTimelineProvider.swift`, `LiveActivityManager.swift`) rather than at the five
  places it is displayed.

---

## ⛔ PICK UP HERE

⛔ **He is testing now, and the `⏸ PARKED` block in [`todo.md`](todo.md) is live rather than held.**
He asked for it as a list and has begun working through it, so an item there may be surfaced — but
only from that block, and only as part of the list. **Never invent a new thing for him to check while
work is still going in.** An item leaves the block when he confirms it; an item he half-confirms is
**narrowed to what is left**, not closed.

Verify everything else without him: `swiftc` harnesses against real bundled data, the nineteen committed
checks above, `./build.sh`, the arm64 device build, install + launch, process-alive checks, the macOS
store migration, real feed payloads. **Run the nineteen checks first thing in a new session** — about
three minutes, and they are how you find out the tree is what this file says it is.

⛔ **A screen can be driven from here, and it earns its keep — but it is not reliable.** The Mac
build takes synthetic clicks: `System Events` for the tab bar and the shelf picker, a small `CGEvent`
tool for a row inside a SwiftUI `List`, `screencapture -R` for the result. That is how the ribbon was
taken end to end without him, and it found a defect no harness could reach. **Its failure mode is
that this terminal reclaims focus after every command**, so the app window sits behind it and the
clicks land on the terminal — a capture that shows this transcript means exactly that, not a broken
screen. `open -a` does not reliably raise it; **`osascript -e 'tell application "System Events" to
set frontmost of process "ACIMDailyMinute" to true'` does**, and asking System Events for the name of
the frontmost process is how to prove it before clicking. ⛔ **The second failure mode is another
app taking the screen mid-sequence** — other apps drive this computer — so raise the window before
**every** click rather than once at the start, and read the capture before believing the click
landed. When it will not come forward, stop and say so rather than spending the session on it.
⛔ **If macOS asks for "access data from other apps", the copy in `/Applications` is the WRONG
BUILD** — that is the tell, not a question to answer. A properly signed copy owns its App Group and
never asks. Check `codesign -dv` first; see `./build.sh` below for what goes wrong and how badly.

⛔ **A SIMULATOR can be driven too, and the recipe is not the Mac one.** `cliclick` is **killed on
sight here** (`exit 137`, sandboxed or not) and is not the tool. Two things do work and they are used
together: `osascript … System Events … click at {x, y}` posts a tap and reports back which element it
hit, and a five-line `swiftc` CGEvent tool posts the press-and-holds and drags that System Events has
no verb for — a long press on a watch face needs a 2.2-second `leftMouseDown`, and a scroll needs
twenty `leftMouseDragged` steps. Read state with `xcrun simctl io <udid> screenshot`, which captures
the device regardless of what is stacked over the window. ⛔ **Re-query the window's position before
EVERY click.** Simulator windows move on their own and they reorder: booting a second watch sim put
its window first, so `first window whose name contains "watchOS"` silently began pointing at the
wrong device and half an hour of taps landed nowhere. Match on the device's own name — `"46mm"` —
never on the platform. Map device-screenshot pixels to the screen with two calibration taps on
targets you can identify in a screenshot, and check the result rather than trusting the arithmetic.
⛔ **`Device > Home` from the menu bar is what leaves a mode**; the toolbar's Crown button pressed
through accessibility does not, and neither does ⌘⇧H once the window has moved.

⏳ **The audio is published and nothing about it is left to do.** The `▶ WATCHING` block of
[`todo.md`](todo.md) holds the one thing still moving on its own: two catch-up gaps the nightly run
fills one per night. Read them off the feed's archive dates; nothing needs a hand. Do not re-open
the hosting decision.

⏸ **The standardized reading layout is PAUSED and is his to resume.** Piece A — the scaffold — is
built and guarded. The four that remain are D (`Archive` becomes `Video`), E (structure the Manual),
B (media index) and C (Listen as activity), in that order, and the `⏸ PAUSED` block of
[`todo.md`](todo.md) holds the decisions he made about each. ⛔ Do not restart this without him; it
stopped mid-brainstorm, not mid-build.

**⭐ The ribbon is built.** The Read tab names where he stopped in the Text and in the Workbook,
above the shelf; on the phone following it puts that passage back at the top of the screen, and on
the Mac it opens the right reading at its top. It travels in the backup file, merging per book by
the later moment.

⛔ **A saved row opens the passage itself, and `Views/Segment/SegmentReadingView.swift` is where a
`segment:` key lands.** `ReadingKey.savedDestination(spotlight:)` is gated on the **bundle** — no
`SegmentMedia` row, no feed, no network — so every one of the 1,983 segments resolves. It takes a
`ReadingSpotlight` and every case but `.archiveDate` carries the ref that can hold one, which is how
a note lands on the reader's own sentence: `HighlightRow` builds one from the mark, `NoteRow` from
the `Highlight` its `highlightID` names, and a standalone note correctly has none. `.minuteDate` is
the one key that still names an archive day, because it exists only for an archived minute whose
segment is unknown — that day is in the archive by construction. `BookmarkRow` parses its channel
separately and now prefers the same passage screen wherever its `DailyMinute` row names a segment;
an `ArchivedReading` carries no segment id and keeps the day.

⛔ **He is using the build and the Saved rows answer him. Two calls on that screen are still his to
veto and are in the parked block.** It offers **Share and not Save** — Today keys a minute bookmark `minute:<segmentHash>` and the Archive keys it
`minute:<lineHash>`, and a third address for one passage is the duplicate-row bug this project keeps
rediscovering. And its footer address **is tappable**, the only pushed reading where that is true:
everywhere else the address names the passage already on screen, and here it names where the passage
begins in the book. ⛔ **That tap is the one thing in this work no eye has seen** — the Mac's screen
was taken by another app mid-check — though it is the same `CitationButton` path the Today card
uses, on a stack that declares `.readingDestinations(path:)`.

**Piece D — Archive becomes Video** is app-only, the data exists today, and it retires the last
exemption to the no-publication-dates rule. Its decisions are in the `⏸ PAUSED` block; it was his
brainstorm, so confirm the recast with him before building it. What to build meanwhile is in
`⬜ AGENT-OWNED WORK` below.

These facts were settled by measuring the bundle, not by preference, and they are load-bearing:
- **The Course never cites itself by address.** Zero `T-`/`W-`/`M-` forms, zero `Lesson N` or
  `Chapter N`, in all 2,727 bundled records. Nothing of the app's own citation shape is detected
  in prose, and no detector for it is planned.
- **The review lessons' bracketed numbers are the one numbered self-reference.** Exactly 150
  `[N]` in exactly the 70 review lessons (51-60, 81-90, 111-120, 141-150, 171-180, 201-220), all
  in 1…365, all earlier than their host, none in the Text, Manual, Introductions or any
  non-Workbook segment. The feed carries the same brackets (today's Lesson 84 arrives with
  `[67]` `[68]`). That is the only in-prose link.
- **A printed citation resolves to its paragraph**, carried whole in the existing
  `ReadingSpotlight` (offset, length, the paragraph's own text as the quote), so no second
  pointer kind is needed. `Citation.paragraphRange(_:in:)` is the inverse of the existing count.
- **`Pref.N` cannot name a paragraph** — the Preface ships as two sections sharing one
  numbering — so a tap on it opens the Preface at its head with nothing painted. The defect is
  on the ledger; it is his call because it changes printed exports.
- **A link pushes in place and never switches tabs.** Today declares no navigation destinations
  of its own, so one modifier, `.readingDestinations(path:)`, sits on the Read, Saved and Today
  stacks and is the only thing that declares them.
  `LessonRef` carries `presentsVideo`, false for a reference.

Search is built: one field on the Read tab over the 744 readable records, hits in book order
with a citation and a snippet, every reading screen opening on a `ReadingSpotlight` that the
screen re-anchors with `AnchorResolver`. Its spec and plan are
`docs/superpowers/specs/2026-09-02-corpus-search-design.md` and `docs/superpowers/plans/2026-09-02-corpus-search.md`.

⛔ **The folder tier writes and never reads, and that boundary is the whole design.** A reader
picks a folder once (Settings > Your Work > Backup & Restore > Keep a copy in a folder); the app
holds a security-scoped bookmark to it in `UserDefaults.standard` and writes the backup file there
**three seconds after the last change to a highlight, note or bookmark**, and at once when the app
leaves the foreground. Settings and listened history ride along in the next write; they do
not trigger one. **Nothing is ever read from the folder**: a folder two machines both write into is
where an automatic merge would lose words, so restoring stays a thing the reader asks for. Every
call in is one line, `FolderCopyService.noteChange(in:)`, at the end of each writer in
`AnnotationStore`, `BookmarkStore` and `BackupService.apply` — a new writer owes the same line. The
four `folderCopy*` keys are device-local and on the `NotTheReaders` list; a bookmark means nothing on
another machine.

⛔ **iCloud sync is OFF by default and only `reader.store` mirrors.** The rule that keeps it that way
is **`allowsSave == false` ⇒ `cloudKitDatabase == .none`**, because `cloudKitDatabase` defaults to
`.automatic` — "mirror if entitled" — which would otherwise have started mirroring the cache store,
the Shortcut's container and the pre-split recovery copy the moment the entitlement landed. **Only the
app target has the iCloud entitlement**; the widget and watch must never get one.

⛔ **Three SwiftData facts this work paid for in crashes and failed syncs.** A second
`ModelConfiguration` **must be named** — two unnamed ones collapse onto the default configuration and
the first insert aborts the process with an Objective-C `NSInvalidArgumentException` no `catch` can
see. A **read-only** configuration cannot create a store it cannot find, which is why
`createStoresIfMissing` exists. And a **brand-new CloudKit container fails its first setup** with
`CKErrorDomain` 5 `badContainer` and works on the next launch — expect it once per fresh container and
do not chase it.

After the reading layout and the physical-book parity items: the pre-submission sweep.

⛔ **Write or delete a `Bookmark` only through `BookmarkStore` — it is the ONLY thing keeping two
rows off one passage.** `itemKey` is the whole identity; there is no `id`; and `@Attribute(.unique)`
is gone from it, so the database will no longer reject a duplicate. `BookmarkStore.toggle` and
`BookmarkStore.remove(key:in:)` are the two ways in, and both decide against a **fetch**, never
against a view's `@Query` snapshot — a snapshot is what the view last drew, not what the store holds,
and a row written by the watch or an import in the same tick is not in it yet. A raw insert or delete
now writes the duplicate silently instead of failing loudly, and the reader's next un-save does
nothing. ⛔ `BackupService.swift:187-192` is a raw `Bookmark()` insert and is the one exception: it is
safe because `BackupMerge` computes its inserts against a live fetch, but it belongs on the list
whenever this invariant moves.

⛔ **The conflict rule is decided, implemented and proved; do not re-open it.** A merge may never
make a reader's words fewer. It is in `BackupMerge.swift` with the reasoning attached, and
`./tools/verify_backup.sh` holds it: idempotent, commutative, associative, and no passage of any
note body is ever lost.

⛔ **The spotlight is a pointer, not a mark.** `ReadingSpotlight` is never stored, never
exported and never keyed; it rides `TextSectionRef`, `LessonRef`, `IntroductionRef` and
`ManualSegmentRef` into a screen and dies with it. It carries the quote because a published
lesson draws the feed's text while the index was built over the bundle, so the screen finds the
words again the way it finds a highlight. A lesson opened on a spotlight does not auto-present
its video. It paints `systemBlue` at 0.22, not the accent: the app's accent is gold and a
highlight is yellow, and on the Mac the accent is whatever the reader set in System Settings.

⛔ **A link pushes in place and never switches tabs.** `ReadingDestination` is the one value a
link pushes; `.readingDestinations(path:)` declares it and installs `openReading` on the three
stacks that draw a reading — Read, Saved, Today — and a fourth stack that draws one owes the
same line, or its links assert in Debug and do nothing in Release. `TextSectionRef` is declared
by that modifier and nowhere else on those stacks, because two declarations of one type on one
stack is a warning and the later one wins silently. `LessonRef.presentsVideo` is false for a
reference and for a citation, true for a list, a widget and a search heading: following a
reference is a request to read. The link URL `reading:lesson/N` is private and unregistered.

⛔ **Where search lives, and the one rule it keeps.** `Services/CorpusSearch.swift` is pure —
the fold, the index, the scan, the cap, the snippet — and `tools/verify_corpus_search.sh`
compiles it alone. `Services/CorpusSearchService.swift` is the actor that builds the record
table in book order and owns the only `CorpusService`/catalog/`ReadingText` calls; the index is
built once per process, on the actor, on the first non-empty query. `Views/Lessons/ReadSearchResultsList.swift`
is the list. The Read tab has ONE `.searchable`, on its root content; `TextChaptersView` is a
contents page only, and `FilteredLessonsList` no longer filters — the results list replaces the
shelf while a query is typed, so the Jump button is absent then and typing the number is the jump.

⛔ **A reader's backup file is `.json` on purpose, and that is not a small decision.** No private
extension and no private UTI: the file has to open on a Windows, Linux or Android machine with what
that machine already has, which is the whole reason tier A exists. It carries the edition note and a
human name and citation on every mark so it reads as a document rather than a table of identifiers.
**Those decorative fields are written and never read back** — the receiving device derives its own,
and nothing may come to depend on them.

⛔ **Import is strictly additive, and the screen says so before the reader taps.** A backup file is a
snapshot, not a log, so a record's absence carries no information at all — treating it as a deletion
would let a six-month-old file erase six months of work. `MergePlan` has no field that can express a
deletion, deliberately. **CloudKit will be different**: it is a live sync and deletes do propagate,
which is a real behavioural difference between the two tiers and the reader has to be told rather
than left to discover it.

⛔ **The file records milliseconds; the store keeps full precision.** So `BackupMerge` compares dates
at the format's own resolution rather than with `<`. Without that, a device importing its own export
would find every birthday a fraction earlier than the one it holds, rewrite them all, and report
changes that were not real. `BackupDocument.timeResolution` is the one place that number lives.

⛔ **Where the reader-data layer lives, and the one rule it must keep.** Six files, app target only:
- `Services/BackupDocument.swift` — the `Codable` file format and the ISO-8601 conversion.
- `Services/BackupMerge.swift` — the merge algebra. Takes a snapshot of what is local plus a decoded
  document and returns a `MergePlan`; it never touches a model.
- `Services/FolderCopy.swift` — the folder: bookmark, resolve, the per-device filename, the atomic
  write, and the three sentences a reader sees when it fails.
- `Services/BackupService.swift` and `Services/FolderCopyService.swift` — **the only two that touch
  `ModelContext` or `UserDefaults`.** The second also owns the debounce and the clock.
- `Views/Settings/BackupRestoreView.swift` — the screen, under Settings > Your Work, all three
  sections.

⛔ **`BackupDocument`, `BackupMerge` and `FolderCopy` must stay pure** — no SwiftData, no SwiftUI, no
`Bundle`, no `CorpusService`, no `UserDefaults`, no `Date()`. `tools/verify_backup.sh` compiles the
first two and `tools/verify_folder_copy.sh` the first and third, and nothing else, so purity is not a
convention anyone has to remember: breaking it breaks the check. Keep new logic on that side of the
line.

⛔ **Every reader setting lives in `UserDefaults.standard`, NOT the App Group.** There is not one
`UserDefaults(suiteName:)` call in the repo; the App Group holds only the SQLite file. Two
consequences that decide real designs: **the widget and watch targets can see none of these keys**,
and CloudKit sync of SwiftData will not carry any of them either — the reminder times, the practice
window and the reader's own place, the appearance and the listened history travel **only** in the
backup file. Anything that wants a setting on more than one Apple device has to move it deliberately.

⛔⛔ **NEVER RE-EXTRACT THE CORPUS.** `segments.id` is the identity for every recorded thing in this
project: `used_date` and `youtube_id` on all 158 published entries, the 239 MP3s, the ElevenLabs
narrations, the YouTube renders, and every reader annotation keyed `segment:<id>`. Re-extraction
renumbers those rows and severs the link between a published episode and its passage. **That is
months of his work and it is not recoverable.** Every corpus defect is repaired in place, over the
rows that already exist. This is not a preference; he raised it directly.

⛔ **The pipeline database is read-only from here, and that is not the same rule.** `tools/` reads
`/Volumes/MacLive/…/data/acim.db` and never writes it. The ElevenLabs narrations were produced from
`segments.text`; moving that column would put 239 recordings and their words out of step. **Corpus
defects are repaired at export and at render, never in the database.**

⛔ **The source PDFs are read-only reference, and they live outside the repo** at
`/Users/larryseyer/Dropbox/ACIM PDF/` — `1_ACIM_Text_A.pdf` (376pp), `2_ACIM_Text_B.pdf` (382pp),
`3_ACIM_Workbook.pdf` (500pp), `4_ACIM_Manual.pdf` (80pp). They are the edition that is shipping,
confirmed by wording and by the 53 numbered miracle principles. `pdftotext` is installed at
`/opt/homebrew/bin/pdftotext`. Use them to learn *where paragraphs break*; never to replace a row's
text, which would reintroduce page furniture and change words the publisher has already narrated.

⛔ **The Text's bodies in `ACIMTextSections.json` are display form, and that is load-bearing.**
`ReadingText.displayString(from: body) == body` holds for all 272 sections, so what is in the JSON,
what is drawn, and what a highlight offset counts are one string. It survives the spacing repair
**because the repair is idempotent and runs on both sides** — `tools/export_corpus.py` applies it to
the bundle, `ReadingText.paragraphs` applies it at render, and applying it twice changes nothing.
**Any future repair owes the same property**, or the bundle and the screen start disagreeing.

⛔ **The Text is 272 sections, and four of them were recovered rather than extracted.** The
pipeline's `text_sections` table is still missing them and always will be — it is read-only from
here, so `tools/chapter_openings.py` puts them back at export, every run, by asking which parts of
the segment stream no section contains. **Never "fix" this by editing the JSON**: the next export
would drop the edit. The recovery is deterministic and it fails loud — if a chapter's opening no
longer starts with its own number and title, `strip_chapter_heading` raises rather than quietly
shipping `sixteen The Forgiveness of Illusions` into a body a reader is going to read.

⛔ **Three chapters' addresses moved, once, and that can never happen again cheaply.** Chapters 13,
16 and 20 had no Introduction, so the recovered opening became section 1 and everything after it
shifted: **`T-16.1 True Empathy` is now `T-16.2`.** It cost nothing only because the annotation
store was empty — 0 highlights, 0 notes, 0 bookmarks, verified before and after — and nothing had
shipped. `Highlight`, `Note` and `Bookmark` all persist `text:<chapter>.<section>`, and there is no
migration anywhere that rewrites those keys. **A renumber after a reader has marked anything needs
one, and it has to be written before the corpus moves, not after.**

⛔ **Two of the eight recovered seams join mid-sentence**, and that is why `splice` decides between a
space and a paragraph break instead of always using one. Chapter 7 stops at `...and His Kingdom. BY`
and the surviving body carries on `ACCEPTING this power as yours`; chapter 22 stops at `in the same`
and continues `room and yet a world apart.` A paragraph break there would invent structure the book
does not have — and `text_paragraphs.py`'s mid-sentence-break guard is what proves every seam joined
cleanly.

⛔ **The citations this app prints are NOT the ones of the widely-cited edition, and that is
deliberate and measured.** Ours is a different book: our Chapter 1 is "INTRODUCTION TO MIRACLES" with
**53** numbered miracle principles rather than 50, and a chapter's Introduction occupies section 1.
**Arabic section numbers — `T-5.3.7`, never `T-5.III.7` — are the visible signal** that these are not
those citations. There is no sentence number either: two defensible splitters disagree on 644 of 3,564
paragraphs, so a `:1` would be a number this app invented and then printed permanently into an export.
`Citation` is pure by design — no SwiftUI, no `CorpusService`, no `ReadingKey` — so a `swiftc` harness
can compile it alone.

⛔ **118 passages carry no citation and show their book name instead** — all 105 Manual segments, plus
13 that did not resolve uniquely. **Nothing is guessed.** The Archive card is the other exception: it
shows a book name because an archived row carries no segment id, the feed's inline archive entries
having none. **Resolving one by matching its text at runtime was rejected** — the locator belongs at
export, and keying a row by its content is the bug this project keeps rediscovering. Giving the
Archive a real citation means adding `segment_id` to the pipeline's archive entries first.

⛔ **The reading surfaces already carry annotation.** Any new reading view should render through
`AnnotatableReadingText(raw:key:design:lineSpacing:)`, which brings selection, highlighting, notes and
export with it for free. Every bundled corpus has a reading screen now; the Manual's
(`Views/Manual/ManualSegmentView.swift`) is one passage at a time with no structure behind it,
and `BookmarkRow` parses its channel separately from `savedDestination`, so a new reading kind
owes both a branch.

⛔ **The idea that breaks silently, and it now has a name:** what the reader sees is not what is in
the model. `ReadingText.displayString(from:)` is the one string both the renderer and every highlight
offset are measured against. Anything that draws a reading must go through it. **The widget, the Live
Activity and the watch do not** — they draw feed text directly, so anything that changes what a
reading looks like has to be applied to them by hand as well.

⛔ **A change to displayed text moves stored highlight offsets, and that is handled, not avoided.**
`AnchorResolver.resolve` repairs the incoming quote by the same rule before matching, so a mark made
before a repair still finds its words; `AnnotationStore.reanchor` writes the repaired quote back on a
successful resolution, which is why the Saved tab, the note editor and the plain-text export needed no
change of their own. **An orphan's quote is never rewritten** — it is the only record of what the
reader marked.

⛔ **Offsets are `Character`-based, never UTF-16.** The conversion lives in exactly one place —
`SelectableReadingText.utf16Range(of:in:)` and `.characterRange(of:in:)`. A single emoji or accented
character shifts every stored offset after it if that boundary is crossed anywhere else.

---

## ⛔ WHAT ONLY HE CAN CLOSE

- **Anything needing eyes on a device**, which is now everything in the parked block. Three entries
  there are the ones no harness can reach: whether the Text's recovered paragraphing reads correctly
  to someone who knows the book, whether the 6,221 restored spaces read as the book does, and whether
  Chapter 1.2 — 34,385 characters in one non-scrolling text view — scrolls without stutter on the
  phone.

---

## ⬜ AGENT-OWNED WORK

⛔ **Platform expansion is the arc he has asked for next, and it is planned in four phases in
[`todo.md`](todo.md).** Four of his calls are made: **tvOS is a player** — listen and watch first,
reading secondary — **Windows and Linux are one web reader over the same bundled JSON**, served from
acimdailyminute.org, not a Swift port, **the iPad gets no sidebar** and the listing was corrected to
match the full-width spine the code actually draws, and **visionOS is taken in compatible mode**, which
is an App Store Connect availability toggle at submission and no build change at all. **Video on the
television is settled and needs no host at all** — the app renders the reading itself; see the four
settled decisions in `PICK UP HERE`.

⛔ **Phase 1 is built and its compact slice is measured.** The one thing still in that block is the
submission-time visionOS availability toggle in App Store Connect, which is not a build.

⛔⛔ **THE TELEVISION HAS A WRITTEN DESIGN AND IT IS AWAITING HIS REVIEW:**
`docs/superpowers/specs/2026-09-05-apple-tv-player-design.md`. ⛔ **`docs/` is gitignored on
purpose** — *"Internal planning docs (kept local, not in public repo)"* — so it is local only, like
all eleven specs beside it, and it is not to be forced into git. **The implementation plan is not
written and must not be written until he has reviewed the spec.**

⛔⛔ **FOUR DECISIONS OF HIS FROM THAT DESIGN ARE SETTLED. Do not re-open them and do not ask again.**
- **NO VIDEO IS HOSTED, ANYWHERE.** The app renders the reading itself — bundled passage, the
  archive.org MP3, one bundled background image — because that is what the render already is. He
  ruled out paid hosting outright: this is a **non-profit paid out of his own pocket** for an app
  meant to **outlive him**, so a recurring bill is not a cost, it is an expiry date. Cloudflare R2
  was recommended and **rejected on exactly that ground**, and the recommendation was wrong for
  weighting cost-per-gigabyte over permanence. ⛔ Rendering also **covers all 1,983 segments rather
  than the ~165 with renders**, draws native 4K text, and obeys appearance and text size. The MP4s
  stay on YouTube for the world; the app stops needing them. Audio stays on archive.org, untouched.
- **The text does NOT advance with the narration.** Alignment data does not exist. Approximate
  pacing needs none and stays cheap later; true alignment would be ~5 KB per reading.
- **The shape is the iOS shape with one verb changed** — the same four tabs, and pressing a card
  starts a player instead of opening a reading. ⛔ **Listen does NOT become the landing tab**: a
  television's first screen answers "what do I put on now", and that is today, not the back
  catalogue. Today becomes a player home.
- **His archive.org ban was a false positive** — they took him for a bot and have cleared him
  entirely. It is not a strike against him and must not be described as one.

⛔ **What is genuinely open on the television, in order:** the focus problem above, which is now the
whole of Phase 3 and whose mechanism is UNPROVEN; then the reading column and type size, which need
his eyes; then the introduction, which is a hard gate a viewer cannot pass. The annotation removal
is done and seen.

From [`todo.md`](todo.md), in order:

1. **Phase 3 — Apple TV**, then **Phase 4 — the web reader**, in that order and never overlapping.
   ⛔ Its first item is the reading that will not scroll, and that one needs him.
   ⛔ Do not drive the iPad sim `58B7D31D-…`; he has asked that that one be left alone. The iPad
   Pro 11-inch (M5) sim `24B47A3C-E5AC-417E-AEB6-6303684193FC` (iOS 26.5) is the one to use.
   ⛔ Phase 2, the Watch, is finished apart from three design calls that are his and are marked
   `HIS CALL` there, and two complication families that need a real wrist; do not treat either as
   work to pick up.
2. **The standardized reading layout, piece D — Archive becomes Video.** Piece A is built. D is
   app-only and the data exists; its decisions are in the `⏸ PAUSED` block, and the recast is his
   call to confirm before it is built. ⛔ **It needs him, so it is not a build to start alone.**
3. **An empty Archive day offering a way onward**, then **"let it fall open"** — both his proposals
   with their shape already decided, and the two builds with no decision outstanding if the platform
   work is not what a session should pick up.
4. **Workbook completion tracking, structuring the Manual**, then the pre-submission sweep and the
   smaller open items.

Four corpus defects remain: the 186 one-paragraph lesson bodies — the one job that genuinely needs the
PDFs — the eleven running heads still inside Chapter 11's prose, **every Workbook introduction glued
to the foot of the lesson before it** (Review I ends Lesson 50, and so on through the "What is …?"
sections), and `WorkbookIntroductions.json` entry 500 two paragraphs short. Structuring the Manual is
its own item.

⛔ **Three platform facts are load-bearing and were measured, not assumed.**
**tvOS has no WebKit and no text selection**, so the YouTube player and the
whole selection→highlight→note pipeline have no port; 79 conditional directives across 43 sites treat
`os(iOS)` and `os(macOS)` as an exhaustive pair and send tvOS into the AppKit branch.
`Utilities/ReadableContentWidth.swift` is the one file already written correctly, with
`#if !os(macOS)`, and it is the pattern the rest should follow. **A NATIVE visionOS target is that
same job, and "lifting `SUPPORTED_PLATFORMS` is close to free" was wrong**: measured on a visionOS
26.5 simulator, `os(iOS)` is **false** there, `os(visionOS)` is true and `canImport(AppKit)` is
**false**, so the app's 48 `#if os(iOS)` / `#elseif os(macOS)` sites match neither branch and
`PlatformFont`, `PlatformColor`, `TextViewRepresentable`, `MacBottomTabBar` and `pageChevron` are all
undefined. Compatible mode — the unmodified iPad binary in a Vision Pro window — needs none of that
and is a store toggle. **SwiftUI does not exist on Windows or Linux**, so
those are a second front end whatever else is decided — which is why they are one web reader over the
same JSON, and why they are last.

⛔ **Two conditional-compilation idioms, and a bare `#else` is neither of them.**
`#if os(iOS)` paired with `#elseif os(macOS)` is not exhaustive: tvOS and visionOS match **neither**
branch, and the symbols the taken branch would have defined — `PlatformFont`, `PlatformColor`,
`TextViewRepresentable`, `MacBottomTabBar`, `pageChevron` — simply vanish, with errors that name the
symbol and never the fence. Use **`#if os(iOS) || os(tvOS)`** where the UIKit path is wanted and
**`#if !os(tvOS)`** where a capability is missing; guard a FRAMEWORK with `canImport`, which states
the real dependency. ⛔ **Three fences are iOS-only for a reason rather than an API, and widening
them compiles and is wrong**: `OrientationController`, `BackgroundRefreshManager` (its whole job is
the practice reminders) and the `LiveActivityManager` call sites.

⛔ **A constant must never sit behind a platform fence.** Fencing `NotificationManager.swift` took
`Notification.Name.openSettingsRequested` and `.reminderTapped` out of the tvOS build with it, and
the error read `Notification.Name has no member` — naming neither the fence nor the cause. The names
now live in `Services/NotificationNames.swift` and the practice-reminder keys in
`Services/PracticeReminderKeys.swift`, both unfenced, with `PracticeReminderService.Key` kept as a
typealias so existing call sites still read the same.

⛔ **`SharedModelContainer.groupURL` no longer force-unwraps**, because a tvOS container — App Group
included — is *purgeable*, and a target without the entitlement got `nil` and died at launch naming a
URL rather than a missing entitlement. Where the group exists nothing changed. ⛔ **Not crashing is
not the same as being durable**: on the TV the bundle and the feed are the only dependable sources,
and a reader must not be invited to make marks that have no route off the device.

⛔ **A `#if` between `}` and `else` severs an if-else chain**, and the compiler says only "expected
expression". Fence INSIDE the branch body instead — `LessonDetailView`'s video stand-in is the
worked example.

⛔ **The durability principle governs everything.** ACIM is timeless; YouTube, archive.org and every
feed are rented and will end. Bundled content is permanent, the feed lasts decades with maintenance,
YouTube and archive.org are certain to end. **The app must be wholly usable on bundled content alone,
and every higher tier must be purely additive.** The app is not permanent either, so nothing may be
trapped inside it: bundled data stays human-readable JSON, and reader-created content must export as
plain text. `AnnotationExport.plainText` is that promise kept for reading, and the backup `.json` is
it kept for reading *back* — plain UTF-8 a stranger's text editor opens, on a machine that never ran
this app. **Anything that lets a reader create something new owes both.**
