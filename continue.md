# continue.md — what is being worked on RIGHT NOW

⛔ **Current and future only.** No history, no history lessons, no ✅ recital of what a session did —
`git log` is the record. Open items live in [`todo.md`](todo.md), which is the source of truth; this file
says what is true now and what is next. REPLACE the state block below — never stack a new one under it.

---

## ✅ NOTHING IS CLAIMED

Working tree clean on branch `ralph/acim-3.9-to-5-finish-2026-04-14` through the portable backup
file, committed. Nothing of mine is running.

**The pipeline scheduler is his, running on MacLive, armed for 02:00 nightly.** Do not start a second
one. MacLive is an SMB mount of another machine (`//...@Chat._smb._tcp.local/MacLive`), so `pgrep` from
this Mac cannot see its processes — read `logs/acim.log` instead, and run `./start.sh` **on that
machine**, never through the mount.

**Build state — all three live targets are current and carry Backup & Restore:**
- 📱 **iPhone 11 Pro Max** (UDID `00008030-0004299C1410802E`) — Debug, **installed and launched**.
  Both processes confirmed alive with `xcrun devicectl device info processes`: the app and
  `ACIMDailyMinuteWidgetExtension`. The widget extension coming up is the proof the schema is
  clean, since it is what `fatalError`s on a mismatch — and this change adds no model and no schema
  entry, deliberately. ⭐ **This is where he tests.** ⛔ A `devicectl install` that returns
  `CoreDeviceError 4000, "the device disconnected immediately after connecting"` is the phone, not
  the build — retry once before believing it.
- 💻 **This M4 MacBook Pro** — `/Applications/ACIMDailyMinute.app`, arm64, signed team `RR5DY39W4Q`,
  launched, with its widget extension registered as `com.larryseyer.acimdailyminute.widget`; he adds
  it from **Edit Widgets**. ⛔ **`build/Debug/` is the macOS product.** `build/Debug-iphonesimulator/`
  also contains an `ACIMDailyMinute.app` and a `find` that is not anchored will hand you the wrong
  one — check `codesign -dv` says `TeamIdentifier=RR5DY39W4Q` before believing you installed it.
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
- **Real SwiftData migrations can be proved here without the phone.** The macOS App Group store at
  `~/Library/Group Containers/group.com.larryseyer.acimdailyminute/ACIMDailyMinute.sqlite` holds real
  data. Back it up, launch the signed build, then read `.tables` and `PRAGMA table_info(...)` with
  `sqlite3` to see the migration actually happened and the rows survived. ⛔ **Its annotation tables
  are empty** — `ZHIGHLIGHT`, `ZNOTE` and `ZBOOKMARK` are all 0 — so it can prove a schema change but
  it cannot prove anything about annotations. For that, drive the real corpus through a harness.

⛔ **Seven committed checks now guard this repo. Run all seven after any change to a bundled file:**
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
- `docs/superpowers/specs/2026-08-30-portable-reader-data-design.md` + its plan — **step 1 of five
  implemented** (the portable file). Steps 2-5 are spec'd and not started; they are the
  `▶ NEXT` block of [`todo.md`](todo.md). Two places where the code is ahead of the plan's text,
  both deliberate: `AnnotationExport.Entry` gained an `id` so the backup can join a citation to a
  particular highlight without matching on its quote; and the file records milliseconds while the
  store keeps full precision, so `BackupMerge` compares dates at the format's own resolution rather
  than with `<`.
- ⛔ **The chapter-opening recovery has NO design document.** It was found by measurement rather
  than requested, so it went straight from evidence to an approved plan, which is at
  `~/.claude/plans/iridescent-moseying-engelbart.md` — outside the repo, and the only written
  record of why it is shaped the way it is besides `tools/chapter_openings.py`'s own docstrings.
  One judgement in it is his and was taken deliberately: the recovered Preface front matter is a
  single section titled `Publisher's Note`, even though the source sets a letter-spaced
  `p u b l i s h e r ’s n o t e` heading part-way through it, which would justify splitting it in
  two. The heading is stripped; ask before splitting.
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
handed over once, whole, at the end. Verify everything verifiable without him: `swiftc` harnesses
against real bundled data, the seven committed checks above, `./build.sh`, the arm64 device build,
install + launch, process-alive checks, the macOS store migration, real feed payloads. **The seven
committed checks above are the first thing to run in a new session** — they take about a minute and
they are how you find out the tree is what this file says it is.

**⭐ The next piece is the rest of carrying a reader's work between devices, and its whole brief is
the `▶ NEXT` block of [`todo.md`](todo.md).** The portable file is done; iCloud is not. Take the
items in the order they are written there, because the first one is a hard prerequisite:

1. **Bookmark uniqueness has to move into code before anything else.** SwiftData refuses
   `@Attribute(.unique)` in a CloudKit-backed store and `Bookmark.itemKey` is the only thing
   preventing duplicate bookmark rows today, so the constraint cannot come off until the six
   `itemKey` call sites fetch before they insert.
2. Split the container into a reader store and a cache store — **four container declarations, not
   three**: app, widget, watch and `Shortcuts/GetTodaysReadingIntent.swift`.
3. CloudKit private database, off by default. **The widget reads `Bookmark`**, so the widget
   extension needs the iCloud entitlement too.
4. **Rewrite `PrivacyPolicyView.swift:23` in the same change**, because "never leaves your device"
   becomes false the moment CloudKit is on.
5. The reader-chosen folder, in its smallest form only.

⛔ **The conflict rule is decided, implemented and proved; do not re-open it.** A merge may never
make a reader's words fewer. It is in `BackupMerge.swift` with the reasoning attached, and
`./tools/verify_backup.sh` holds it: idempotent, commutative, associative, and no passage of any
note body is ever lost.

**Corpus-wide search — the book's index — is still the other open item** and is unstarted. Its brief
is the `▶ THEN` block of [`todo.md`](todo.md): the three narrow searches that exist today and what
each actually matches, the 5,137,927 characters over 2,727 records a real search has to cover, and
the four questions its spec has to answer.

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
`ReadingText.displayString(from: body) == body` holds for all 268 sections, so what is in the JSON,
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
export with it for free. The Manual is the one bundled corpus still without a reading UI, and
`savedDestination` returns nil for `.manual` alone now.

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

- **Archive.org.** He has heard nothing back about the spam ban. The flag refuses item *creation*;
  adding files to an item that already exists returns 200. Re-check cheaply, no write path touched:
  `curl -s https://archive.org/metadata/acim-daily-minute` → `{}` means still blocked.
  ⛔ **Do not re-open the hosting decision unprompted.** Two finished features wait on it and neither
  needs an app change to come alive: the Today card's **Listen** button, and MP3 download in the Listen
  tab. Both are invisible only because `audio_url` is empty on every episode and all 158 archive entries.
- **Anything needing eyes on a device**, which is now everything in the parked block. Three entries
  there are the ones no harness can reach: whether the Text's recovered paragraphing reads correctly
  to someone who knows the book, whether the 6,221 restored spaces read as the book does, and whether
  Chapter 1.2 — 37,222 characters in one non-scrolling text view — scrolls without stutter on the
  phone.

---

## ⬜ AGENT-OWNED WORK

From [`todo.md`](todo.md), in order: **the four remaining sync items** (bookmark uniqueness, the
store split, CloudKit, the reader-chosen folder), then **corpus-wide search**, then cross-reference
links — which citations unblocked, since `Citation(rawValue:)` parses an address back to a
`ReadingKey` the app already navigates — then the pre-submission sweep and the smaller open items. The 186 one-paragraph lesson bodies and the eleven
running heads still sitting inside Chapter 11's prose are the two remaining corpus defects; the lesson
bodies are the one job that genuinely needs the PDFs. The Manual is the last bundled corpus with no
reading UI, and structuring it is its own item.

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
