# continue.md — what is being worked on RIGHT NOW

⛔ **Current and future only.** No history, no history lessons, no ✅ recital of what a session did —
`git log` is the record. Open items live in [`todo.md`](todo.md), which is the source of truth; this file
says what is true now and what is next. REPLACE the state block below — never stack a new one under it.

---

## ✅ NOTHING IS CLAIMED

Working tree clean, branch `ralph/acim-3.9-to-5-finish-2026-04-14` through `10d5070`. Nothing of mine is
running.

**The pipeline scheduler is his, running on MacLive, armed for 02:00 nightly.** Do not start a second one.
MacLive is an SMB mount of another machine (`//…@Chat._smb._tcp.local/MacLive`), so `pgrep` from this Mac
cannot see its processes — read `logs/acim.log` instead, and run `./start.sh` **on that machine**, never
through the mount.

**Build state — three places are running the corpus build at `10d5070`:**
- 📱 **iPhone 11 Pro Max** (UDID `00008030-0004299C1410802E`) — Debug, installed and launched.
  ⭐ **This is where he is testing.**
- 💻 **This M4 MacBook Pro** — `/Applications/ACIMDailyMinute.app`, signed with *Apple Development:
  Larry Seyer*, running, App Group container open. The widget is registered as
  `com.larryseyer.acimdailyminute.widget` and he adds it from **Edit Widgets**.
- 📱 **iPad (10th gen) sim** `58B7D31D-70BB-4286-BBB7-09ADDE1F3EF4` — stale, still at `8cb09f9`.

⛔ **He asked that the iPad simulator not be driven** — other apps are controlling this computer. The
phone and this Mac are both fine. Ask before touching the sim again.

⛔ **A green `./build.sh` does NOT prove the device build compiles**, and it does not prove the macOS
widget works either:
- `./build.sh` = three targets, compile-only, and it passes `CODE_SIGNING_ALLOWED=NO` for macOS, so that
  binary has no entitlements and its widget is invisible to the system.
- `./both.sh` = the above **plus install/launch on the sim and the phone**. It drives the sim.
- Phone only, no sim: `xcodebuild -scheme ACIMDailyMinute -configuration Debug -destination
  "platform=iOS,id=<UDID>" -derivedDataPath build ONLY_ACTIVE_ARCH=YES build`, then
  `xcrun devicectl device install app` / `process launch`.
- macOS widget: the signed-build recipe is in [`todo.md`](todo.md) under platform expansion.

⛔ **Two design documents exist and are NOT in git.** `.gitignore:54` ignores `docs/` on purpose —
"Internal planning docs (kept local, not in public repo)". They live only on this Mac:
- `docs/superpowers/specs/2026-08-30-timeless-corpus-design.md` — approved, and now implemented.
- `docs/superpowers/plans/2026-08-30-timeless-corpus.md` — all five tasks executed.

---

## ⛔ PICK UP HERE

**1. Get his confirmation on what is on the phone** — the list in [`todo.md`](todo.md). It is now seven
items: B4/B5, B6, B7 and the date sweep were already waiting; lesson bodies, the corpus floor and the
inert download affordance are new. Three of them are the only checks the corpus work could not make
itself, because they need eyes on a device or a network turned off.

**2. Then the reader-annotations spec.** Every design decision is made and recorded in
[`todo.md`](todo.md); it needs writing up, not deciding.

**Spec 2 — the Text reading UI — is the biggest single parity gap and is now unblocked.** All 268 Text
sections are bundled with chapter and section numbers and titles, and `CorpusService.textSections`
exposes them. Nothing reads them yet.

---

## ⛔ WHAT ONLY HE CAN CLOSE

- **Archive.org.** He has heard nothing back about the spam ban. The flag refuses item *creation*; adding
  files to an item that already exists returns 200. Re-check cheaply, no write path touched:
  `curl -s https://archive.org/metadata/acim-daily-minute` → `{}` means still blocked.
  ⛔ **Do not re-open the hosting decision unprompted.** Two finished features are waiting on it and
  neither needs an app change to come alive: the Today card's **Listen** button, and MP3 download in the
  Listen tab. Both are invisible today only because `audio_url` is empty on every episode and all 158
  archive entries.
- **Anything needing eyes on the phone.** No synthetic taps are available here: `cliclick` is killed on
  launch (no Accessibility permission), and there is no deep-link route for the Listen tab.

---

## ⬜ AGENT-OWNED WORK

From [`todo.md`](todo.md), in order: the reader-annotations spec, then Spec 2 for the Text, then the
pre-submission sweep, then the smaller open items. **Apple TV is now on the list** and is the only
unbuilt Apple platform; Windows and Linux come after every Apple target and not before.

⛔ **The durability principle governs everything.** ACIM is timeless; YouTube, archive.org and every feed
are rented and will end. Bundled content is permanent, the feed lasts decades with maintenance, YouTube
and archive.org are certain to end. **The app must be wholly usable on bundled content alone, and every
higher tier must be purely additive.** The app is not permanent either, so nothing may be trapped inside
it: bundled data stays human-readable JSON, and reader-created content must export as plain text.
