# continue.md — what is being worked on RIGHT NOW

⛔ **Current and future only.** No history, no history lessons, no ✅ recital of what a session did —
`git log` is the record. Open items live in [`todo.md`](todo.md), which is the source of truth; this file
says what is true now and what is next. REPLACE the state block below — never stack a new one under it.

---

## ✅ NOTHING IS CLAIMED

Working tree clean, branch `ralph/acim-3.9-to-5-finish-2026-04-14` through `c1f1330`, pushed. Nothing
of mine is running.

**The pipeline scheduler is his, running on MacLive, armed for 02:00 nightly.** Do not start a second
one. MacLive is an SMB mount of another machine (`//…@Chat._smb._tcp.local/MacLive`), so `pgrep` from
this Mac cannot see its processes — read `logs/acim.log` instead, and run `./start.sh` **on that
machine**, never through the mount.

**Build state — both live targets are current at `c1f1330`:**
- 📱 **iPhone 11 Pro Max** (UDID `00008030-0004299C1410802E`) — Debug, installed and launched.
  ⭐ **This is where he tests.**
- 💻 **This M4 MacBook Pro** — `/Applications/ACIMDailyMinute.app`, signed *Apple Development: Larry
  Seyer*, running with its widget extension up. Widget registered as
  `com.larryseyer.acimdailyminute.widget`; he adds it from **Edit Widgets**.
- 📱 **iPad (10th gen) sim** `58B7D31D-70BB-4286-BBB7-09ADDE1F3EF4` — stale, at `8cb09f9`, and
  ⛔ **he has asked that it not be driven.** Other apps control this computer. Ask before touching it.

⛔ **A green `./build.sh` proves less than it looks like it does:**
- `./build.sh` = three targets, **compile-only**, and it passes `CODE_SIGNING_ALLOWED=NO` for macOS, so
  that binary has no entitlements, cannot open the App Group, and its widget is invisible to the system.
- `./both.sh` = the above **plus install/launch on the sim and the phone**. It drives the sim.
- `./bu.sh "msg"` is **not a build**: `git add .` + commit + push + Dropbox zip.
- **Phone only, no sim:** `xcodebuild -scheme ACIMDailyMinute -configuration Debug -destination
  "platform=iOS,id=00008030-0004299C1410802E" -derivedDataPath build ONLY_ACTIVE_ARCH=YES build`, then
  `xcrun devicectl device install app --device <UDID> build/Debug-iphoneos/ACIMDailyMinute.app` and
  `process launch`. Check for a SwiftData schema crash with `xcrun devicectl device info processes` —
  **the widget extension process being alive is the proof**, since it is what `fatalError`s on mismatch.
- **macOS + widget:** `xcodebuild -scheme ACIMDailyMinute -configuration Debug -destination
  "platform=macOS" -allowProvisioningUpdates DEVELOPMENT_TEAM=RR5DY39W4Q build`, copy to
  `/Applications`, launch once. Verify with `pluginkit -mAv -p com.apple.widgetkit-extension | grep -i acim`.

⛔ **Four design documents exist and are NOT in git.** `.gitignore:54` ignores `docs/` on purpose. They
live only on this Mac:
- `docs/superpowers/specs/2026-08-30-timeless-corpus-design.md` — implemented.
- `docs/superpowers/plans/2026-08-30-timeless-corpus.md` — all five tasks executed.
- `docs/superpowers/specs/2026-08-30-reader-annotations-design.md` — his decisions, written up.
- `docs/superpowers/plans/2026-08-30-reader-annotations.md` — **eight tasks, not started. This is next.**

---

## ⛔ PICK UP HERE

⛔⛔ **DO NOT ASK HIM TO TEST ANYTHING.** He has parked the entire confirmation list until every
outstanding item is spec'd, planned and implemented — "otherwise, I will just repeat myself on things
that simply have not been done yet." The `⏸ PARKED` block in [`todo.md`](todo.md) only grows and is
handed over once, whole, at the end. Verify everything verifiable without him: `swiftc` harnesses
against real bundled data, `./build.sh`, the arm64 device build, install + launch, process-alive
checks, real feed payloads.

**Execute Task 1 of the reader-annotations plan.** He asked to start it in a fresh chat.

Task 1 is pure foundation — `ReadingText.displayString(from:)` plus a positional `ReadingKey` enum,
with a harness and **no UI change at all**. The plan carries the full code for both, and that code is
**already typechecked against the real `CorpusService`, `WorkbookCatalog` and `ReadingTextView`**, so it
is working code rather than a sketch. `AnchorResolver` in Task 3 is likewise typechecked and
smoke-tested across nine cases, including the one expectation that is easy to get wrong: a stored
offset far past the end resolves to the **last** occurrence, not the first.

⛔ The single most important idea in the feature, and the one that breaks silently: **what the reader
sees is not what is in the model.** `ReadingTextView` collapses lone newlines and preserves blank lines,
so highlight offsets must be measured against one shared `displayString` used by both the renderer and
the anchor arithmetic. If those ever diverge, every stored offset is wrong by a variable amount and
nothing looks broken until a reader reopens an old highlight.

---

## ⛔ WHAT ONLY HE CAN CLOSE

- **Archive.org.** He has heard nothing back about the spam ban. The flag refuses item *creation*;
  adding files to an item that already exists returns 200. Re-check cheaply, no write path touched:
  `curl -s https://archive.org/metadata/acim-daily-minute` → `{}` means still blocked.
  ⛔ **Do not re-open the hosting decision unprompted.** Two finished features wait on it and neither
  needs an app change to come alive: the Today card's **Listen** button, and MP3 download in the Listen
  tab. Both are invisible only because `audio_url` is empty on every episode and all 158 archive entries.
- **Anything needing eyes on a device**, which is now everything in the parked block.

---

## ⬜ AGENT-OWNED WORK

From [`todo.md`](todo.md), in order: the reader-annotations plan (eight tasks), then **Spec 2 — the
Text reading UI**, the biggest remaining parity gap and now unblocked: all 268 Text sections are bundled
with chapter and section numbers and titles, `CorpusService.textSections` exposes them, and nothing
reads them yet. Then the pre-submission sweep and the smaller open items.

**Apple TV is on the list** and is the only unbuilt Apple platform — no tvOS target exists yet, though
four tvOS runtimes are installed here. Windows and Linux come after every Apple target, never before.

⛔ **The durability principle governs everything.** ACIM is timeless; YouTube, archive.org and every
feed are rented and will end. Bundled content is permanent, the feed lasts decades with maintenance,
YouTube and archive.org are certain to end. **The app must be wholly usable on bundled content alone,
and every higher tier must be purely additive.** The app is not permanent either, so nothing may be
trapped inside it: bundled data stays human-readable JSON, and reader-created content must export as
plain text. That last clause is the whole reason the annotations plan ships export in Task 8 rather
than later — there is no server and no account, so nothing could ever re-send a reader's notes.
