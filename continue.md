# continue.md — what is being worked on RIGHT NOW

⛔ **Current and future only.** No history, no history lessons, no ✅ recital of what a session did —
`git log` is the record. Open items live in [`todo.md`](todo.md), which is the source of truth; this file
says what is true now and what is next. REPLACE the state block below — never stack a new one under it.

---

## ✅ WHAT IS TRUE RIGHT NOW

Working tree clean on branch `ralph/acim-3.9-to-5-finish-2026-04-14`, committed and pushed. Nothing of
mine is running.

**The pipeline scheduler is his, running on MacLive, armed for 02:00 nightly.** Do not start a second
one. MacLive is an SMB mount of another machine (`//...@Chat._smb._tcp.local/MacLive`), so `pgrep`
from this Mac cannot see its processes — read `logs/acim.log` **on that machine** instead, and run
`./start.sh` there, never through the mount.

⛔ **The card header is two bands on every card and every screen size** — title centred on its own
line, then **Listen on the leading edge, Share and Save on the trailing edge**. `CardHeaderRow` owns
it, `ListenButton` and `SaveButton` are the shared controls, and `tools/verify_card_header.sh` is the
tenth check. **The play control is leftmost on purpose**: most readings have no audio, so it is
usually absent, and anchoring it there is what stops Share and Save moving between passages. His
layout decisions — do not undo them without asking.

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

**Build state — the phone and the Mac carry Backup & Restore, the store split, iCloud sync and the
reader-chosen folder, and NOT search: nothing has been installed since search landed. The next
install on each is what puts the Read-tab search, the spotlight and the Manual screen in front of
him; `./build.sh` and the thirteen checks are green at the search commits.**
- 📱 **iPhone 11 Pro Max** (UDID `00008030-0004299C1410802E`) — Debug, install current, both the app
  and `ACIMDailyMinuteWidgetExtension` seen alive, which is the proof the schema is clean since the
  extension is what `fatalError`s on a mismatch. It has run its one-time reader migration. iCloud sync
  is **off**, its default. No folder is chosen, its default.
  ⛔ **`devicectl device info processes` showing none of them means nothing is wrong** — the app is
  simply not open. It is a check to run *after* launching, never a way to ask what is installed.
  ⭐ **This is where he tests.** ⛔ A `devicectl install` returning
  `CoreDeviceError 4000, "the device disconnected immediately after connecting"` is the phone, not the
  build — retry once before believing it. A locked phone refuses `process launch` with
  `FBSOpenApplicationErrorDomain error 7`; that is the lock, not the build.
- 💻 **This M4 MacBook Pro** — `/Applications/ACIMDailyMinute.app` is current: arm64, signed team
  `RR5DY39W4Q`, widget extension registered as `com.larryseyer.acimdailyminute.widget`; he adds it
  from **Edit Widgets**. Not running is the ordinary state, not a fault. Confirm with `codesign -dv`
  and `pluginkit -mAv -p com.apple.widgetkit-extension`, which answer without launching anything.
  iCloud sync is **off**, its default. No folder is chosen — `defaults read com.larryseyer.acimdailyminute`
  shows no `folderCopy` key, checked after the launch. ⛔ **`build/Debug/` is the macOS product.**
  `build/Debug-iphonesimulator/` also contains an `ACIMDailyMinute.app`, and a `find` that is not
  anchored hands you the wrong one — check `codesign -dv` says `TeamIdentifier=RR5DY39W4Q`.
- 📱 **iPad (10th gen) sim** `58B7D31D-70BB-4286-BBB7-09ADDE1F3EF4` — driven only by `./build.sh`'s
  compile step. ⛔ **He has asked that it not be driven.** Other apps control this computer.

⛔ **A green `./build.sh` proves less than it looks like it does:**
- `./build.sh` = three targets, **compile-only**, and it passes `CODE_SIGNING_ALLOWED=NO` for macOS, so
  that binary has no entitlements, cannot open the App Group, and its widget is invisible to the system.
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

⛔ **Thirteen committed checks now guard this repo. Run all thirteen first thing — they take about a
minute and they are how you find out the tree is what this file says it is:**
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
  words.** 182 measurements over 45 real bodies at four window widths: every reading occupies real
  height, at least one line of it, never shorter as the window narrows, and a body twenty times
  longer is more than twice as tall. **It compiles `ReadingTextMeasurement.swift` and nothing else**,
  which is what keeps the measurement free of SwiftUI and therefore checkable at all. ⛔ A
  reading measuring zero does not crash and no other check can see it: the card collapses and the
  text draws over `Add note` and the citation.
- `./tools/verify_bookmark_identity.sh` — ⛔ **the only check that guards a reader's SAVE.** 381 cases
  over `BookmarkIdentity`, and **it compiles that one file and nothing else**, which is what keeps the
  rule free of SwiftData and therefore checkable. `Bookmark` has no `id` — `itemKey` is its whole
  identity — so it proves that a save is an involution, that ONE un-save removes EVERY row holding a
  key rather than the first, that a re-key onto an occupied address folds rather than collides, that
  the survivor keeps the earlier `createdAt` exactly as `BackupMerge` does, and that no rule depends
  on the order a fetch returned rows in. All three failures it guards are silent: a half-deleted
  duplicate makes un-save do nothing, and a collision throws today's minute out of `persistMinute`.
- `./tools/verify_card_header.sh` — ⛔ **the only check that guards the STRIP ABOVE a reading.**
  401 cases, and **it compiles `CardHeaderRow.swift` and nothing else**. When a title and its controls
  want more width than the card has, SwiftUI drops nothing and warns about nothing — it squeezes the
  only squeezable things, which are the words. It proves the block is two bands at every width from
  90pt to 672pt with no word ever broken, that Share precedes Save on the trailing edge, and that
  **neither moves when the play control appears** — which is what the leading play control buys, since
  most readings have no audio and that button is usually absent.
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
- `docs/superpowers/specs/2026-08-30-punctuation-spacing-repair-design.md` — implemented. Two places
  where the code is ahead of the spec's text, both deliberate: `PunctuationSpacing.swift` lives in
  `Utilities/` rather than `Views/`, because the widget and watch targets compile it too; and the
  widget and Live Activity are repaired where their `minuteText` is *produced*
  (`ACIMDailyMinuteTimelineProvider.swift`, `LiveActivityManager.swift`) rather than at the five
  places it is displayed.

---

## ⛔ PICK UP HERE

⛔⛔ **DO NOT ASK HIM TO TEST ANYTHING.** He has parked the entire confirmation list until every
outstanding item is spec'd, planned and implemented — "otherwise, I will just repeat myself on things
that simply have not been done yet." The `⏸ PARKED` block in [`todo.md`](todo.md) only grows and is
handed over once, whole, at the end.

Verify everything else without him: `swiftc` harnesses against real bundled data, the thirteen committed
checks above, `./build.sh`, the arm64 device build, install + launch, process-alive checks, the macOS
store migration, real feed payloads. **Run the thirteen checks first thing in a new session** — about a
minute, and they are how you find out the tree is what this file says it is.

⏳ **The audio is published and nothing about it is left to do.** The `▶ WATCHING` block of
[`todo.md`](todo.md) holds the one thing still moving on its own: two catch-up gaps the nightly run
fills one per night. Read them off the feed's archive dates; nothing needs a hand. Do not re-open
the hosting decision.

⏸ **The standardized reading layout is PAUSED and is his to resume** — the `⏸ PAUSED` block of
[`todo.md`](todo.md) holds the decisions he made. Its first piece is partly standing already: one
shared `CardHeaderRow` across the three cards, audio-first with the play control leftmost. What is
left is the rest of the scaffold — the title/body/footer bands, `Archive` becoming `Video`, and
structuring the Manual. ⛔ Do not restart this without him; it stopped mid-brainstorm, not mid-build.

**⭐ The live agent work is cross-reference links**, the `▶ NEXT` block of [`todo.md`](todo.md).
Search is built: one field on the Read tab over the 744 readable records (Text, Workbook with its
two Part Introductions, Manual), hits in book order with a citation and a snippet, and every
reading screen opens on a `ReadingSpotlight` — offset, length and quote — that the screen
re-anchors with `AnchorResolver` against the string it actually draws. The segments are not
indexed: they are the same words cut a second time. Its spec and plan are
`docs/superpowers/specs/2026-09-02-corpus-search-design.md` and `docs/superpowers/plans/2026-09-02-corpus-search.md`,
both outside git like the rest of `docs/`.

⛔ **The folder tier writes and never reads, and that boundary is the whole design.** A reader
picks a folder once (Settings > Your Work > Backup & Restore > Keep a copy in a folder); the app
holds a security-scoped bookmark to it in `UserDefaults.standard` and writes the backup file there
**three seconds after the last change to a highlight, note or bookmark**, and at once when the app
leaves the foreground. Settings, phrases and listened history ride along in the next write; they do
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

After cross-reference links: the pre-submission sweep.

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
and CloudKit sync of SwiftData will not carry any of them either — the reminder time, the alert
toggles, the watched phrases and the listened history travel **only** in the backup file. Anything
that wants a setting on more than one Apple device has to move it deliberately.

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
  Chapter 1.2 — 37,222 characters in one non-scrolling text view — scrolls without stutter on the
  phone.

---

## ⬜ AGENT-OWNED WORK

From [`todo.md`](todo.md), in order:

1. **Cross-reference links** — spec first, then plan, then build. `▶ NEXT`. `Citation(rawValue:)`
   already parses an address back to a `ReadingKey` the app navigates, and every reading screen
   takes a spotlight, so it is a view change, not a format change.
2. **The standardized reading layout** — his list for today put it second; it is `⏸ PAUSED` and
   its decisions are recorded there. Resume it as a brainstorm, not a build.
3. **Resume where you stopped, Workbook completion tracking, structuring the Manual**, then the
   pre-submission sweep and the smaller open items.

Two corpus defects remain: the 186 one-paragraph lesson bodies — the one job that genuinely needs the
PDFs — and the eleven running heads still inside Chapter 11's prose. Structuring the Manual is its
own item.

**Apple TV is on the list** and is the only unbuilt Apple platform — no tvOS target exists yet, though
four tvOS runtimes are installed here. Windows and Linux come after every Apple target, never before.

⛔ **The durability principle governs everything.** ACIM is timeless; YouTube, archive.org and every
feed are rented and will end. Bundled content is permanent, the feed lasts decades with maintenance,
YouTube and archive.org are certain to end. **The app must be wholly usable on bundled content alone,
and every higher tier must be purely additive.** The app is not permanent either, so nothing may be
trapped inside it: bundled data stays human-readable JSON, and reader-created content must export as
plain text. `AnnotationExport.plainText` is that promise kept for reading, and the backup `.json` is
it kept for reading *back* — plain UTF-8 a stranger's text editor opens, on a machine that never ran
this app. **Anything that lets a reader create something new owes both.**
