# continue.md — what is being worked on RIGHT NOW

⛔ **Current and future only.** No history, no history lessons, no ✅ recital of what a session did —
`git log` is the record. Open items live in [`todo.md`](todo.md), which is the source of truth; this file
says what is true now and what is next. REPLACE the state block below — never stack a new one under it.

---

## ✅ NOTHING IS CLAIMED

Working tree clean, branch `ralph/acim-3.9-to-5-finish-2026-04-14` through `0aa29b8`. Nothing of mine
is running.

**The pipeline scheduler is his, running on MacLive, armed for 02:00 nightly.** Do not start a second
one. MacLive is an SMB mount of another machine (`//…@Chat._smb._tcp.local/MacLive`), so `pgrep` from
this Mac cannot see its processes — read `logs/acim.log` instead, and run `./start.sh` **on that
machine**, never through the mount.

**Build state — both live targets are current at `0aa29b8`:**
- 📱 **iPhone 11 Pro Max** (UDID `00008030-0004299C1410802E`) — Debug, installed and launched, app and
  widget extension both alive. ⭐ **This is where he tests.**
- 💻 **This M4 MacBook Pro** — `/Applications/ACIMDailyMinute.app`, signed *Apple Development: Larry
  Seyer*, running with its widget extension up. Widget registered as
  `com.larryseyer.acimdailyminute.widget`; he adds it from **Edit Widgets**.
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
  a clean schema, since it is what `fatalError`s on mismatch, and it comes up even while locked.
- **macOS + widget:** `xcodebuild -scheme ACIMDailyMinute -configuration Debug -destination
  "platform=macOS" -allowProvisioningUpdates DEVELOPMENT_TEAM=RR5DY39W4Q build`, copy to
  `/Applications`, launch once. Verify with `pluginkit -mAv -p com.apple.widgetkit-extension | grep -i acim`.
  ⛔ Quit the running copy first, or `rm -rf /Applications/ACIMDailyMinute.app` fails mid-flight.
- **Real SwiftData migrations can be proved here without the phone.** The macOS App Group store at
  `~/Library/Group Containers/group.com.larryseyer.acimdailyminute/ACIMDailyMinute.sqlite` holds real
  data. Back it up, launch the signed build, then read `.tables` and `PRAGMA table_info(...)` with
  `sqlite3` to see the migration actually happened and the rows survived.

⛔ **Design documents are NOT in git.** `.gitignore:54` ignores `docs/` on purpose. They live only on
this Mac:
- `docs/superpowers/specs/2026-08-30-timeless-corpus-design.md` + its plan — implemented.
- `docs/superpowers/specs/2026-08-30-reader-annotations-design.md` + its plan — **all eight tasks
  executed.** The plan's own text is now behind the code in three places, all deliberate and all
  recorded in `git log`: `ReadingTextView` the *view* was deleted once nothing referenced it (the
  `ReadingText` enum stays and is still the single source of truth); the six call sites go through a
  new `AnnotatableReadingText` wrapper rather than six copies of the same wiring; and the export
  format carries a date on an attached note, which the plan's sample omitted.

---

## ⛔ PICK UP HERE

⛔⛔ **DO NOT ASK HIM TO TEST ANYTHING.** He has parked the entire confirmation list until every
outstanding item is spec'd, planned and implemented — "otherwise, I will just repeat myself on things
that simply have not been done yet." The `⏸ PARKED` block in [`todo.md`](todo.md) only grows and is
handed over once, whole, at the end. Verify everything verifiable without him: `swiftc` harnesses
against real bundled data, `./build.sh`, the arm64 device build, install + launch, process-alive
checks, the macOS store migration, real feed payloads.

**Next is Spec 2 — the Text reading UI**, the largest remaining parity gap and now fully unblocked.
See the `▶ NEXT` block in [`todo.md`](todo.md). Spec first, then plan, then execute.

⛔ **The reading surfaces already carry annotation.** Any Text reading view should render through
`AnnotatableReadingText(raw:key:design:lineSpacing:)`, which brings selection, highlighting, notes and
export with it for free. `ReadingKey.textSection(chapter:section:)` already exists and already stores;
`savedDestination` returns nil for it only because there is nowhere to navigate yet, and that is the
one line Spec 2 makes true.

⛔ **The idea that breaks silently, and it now has a name:** what the reader sees is not what is in
the model. `ReadingText.displayString(from:)` is the one string both the renderer and every highlight
offset are measured against. Anything that draws a reading must go through it. Six harnesses hold this
down against all 365 lesson bodies, 1,983 corpus segments and 268 Text sections; keep them passing.

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
- **Anything needing eyes on a device**, which is now everything in the parked block — and that block
  has grown, because six reading surfaces changed renderer and no harness can settle how they look.

---

## ⬜ AGENT-OWNED WORK

From [`todo.md`](todo.md), in order: **Spec 2 — the Text reading UI**, then canonical citations, then
the pre-submission sweep and the smaller open items.

**Apple TV is on the list** and is the only unbuilt Apple platform — no tvOS target exists yet, though
four tvOS runtimes are installed here. Windows and Linux come after every Apple target, never before.

⛔ **The durability principle governs everything.** ACIM is timeless; YouTube, archive.org and every
feed are rented and will end. Bundled content is permanent, the feed lasts decades with maintenance,
YouTube and archive.org are certain to end. **The app must be wholly usable on bundled content alone,
and every higher tier must be purely additive.** The app is not permanent either, so nothing may be
trapped inside it: bundled data stays human-readable JSON, and reader-created content must export as
plain text. `AnnotationExport.plainText` is that promise kept for highlights and notes; anything that
lets a reader create something new owes the same.
