# continue.md — what is being worked on RIGHT NOW

⛔ **Current and future only.** No history, no history lessons, no ✅ recital of what a session did —
`git log` is the record. Open items live in [`todo.md`](todo.md), which is the source of truth; this file
says what is true now and what is next. REPLACE the state block below — never stack a new one under it.

---

## ✅ NOTHING IS CLAIMED

Working tree clean, branch `ralph/acim-3.9-to-5-finish-2026-04-14` pushed through `e2d0227`. Nothing of
mine is running.

**The pipeline scheduler is his, running on MacLive, armed for 02:00 nightly.** Do not start a second one.
MacLive is an SMB mount of another machine (`//…@Chat._smb._tcp.local/MacLive`), so `pgrep` from this Mac
cannot see its processes — read `logs/acim.log` instead, and run `./start.sh` **on that machine**, never
through the mount.

**Build state — the binaries on both devices are at `8cb09f9`:**
- 📱 **iPhone 11 Pro Max** (UDID `00008030-0004299C1410802E`) — Debug. ⭐ **This is where he is testing.**
- 💻 **iPad (10th gen) sim** `58B7D31D-70BB-4286-BBB7-09ADDE1F3EF4` — same build, booted.
- `e2d0227` is docs only — neither binary needs redeploying for it.
- ⛔ **A green `./build.sh` does NOT prove the device build compiles.** The arm64 slice catches Swift 6
  concurrency errors the simulator passes. `./build.sh` = 3 targets compile-only; `./both.sh` = +
  install/launch on the sim and the phone.

⛔ **Two design documents exist and are NOT in git.** `.gitignore:54` ignores `docs/` on purpose —
"Internal planning docs (kept local, not in public repo)". They live only on this Mac:
- `docs/superpowers/specs/2026-08-30-timeless-corpus-design.md` — approved by him.
- `docs/superpowers/plans/2026-08-30-timeless-corpus.md` — 5 tasks, written, **not started**.

---

## ⛔ PICK UP HERE

**1. Execute the Timeless Corpus plan.** It is written, reviewed against its spec, and needs no further
design. Task 1 alone is worth doing first and standalone: it exports the corpus and fills
`Workbook365Bodies.json`, which is a 3-byte `[]` today, and that makes every lesson body render with **no
code change** — `WorkbookBodiesCatalog.body(for:)` is already wired into `LessonDetailView:227` and `:313`.
⭐ That file was tracked for months as blocked on content supply. It never was. All 365 bodies are in
`data/acim.db` on MacLive and always have been.

**2. Get his confirmation on four fixes already on his phone** — B4/B5, B6, B7 in [`todo.md`](todo.md).
B1, B2 and B3 are confirmed and gone from the ledger.

---

## ⛔ WHAT ONLY HE CAN CLOSE

- **Archive.org.** He has heard nothing back about the spam ban. The flag refuses item *creation*; adding
  files to an item that already exists returns 200. Re-check cheaply, no write path touched:
  `curl -s https://archive.org/metadata/acim-daily-minute` → `{}` means still blocked.
  ⛔ **Do not re-open the hosting decision unprompted.** The gate is bigger than the backfill: the Today
  card's **Listen** button is built and invisible only because `audioURL` is empty, and Task 5 of the plan
  builds MP3 download that stays inert until these items exist.
- **Anything needing eyes on the phone.** No synthetic taps are available here: `cliclick` is killed on
  launch (no Accessibility permission), and there is no deep-link route for the Listen tab. The Lessons
  list can be reached for a screenshot with `xcrun simctl openurl <SIM> "acimdailyminute://saved"` then
  `"acimdailyminute://lesson/82"` — the second call lands on the list rather than the detail view when the
  tab was not already frontmost.

---

## ⬜ AGENT-OWNED WORK

The Timeless Corpus plan is the pick of it. After that, from [`todo.md`](todo.md): the reader-annotations
spec (all design decisions are already made and recorded, it needs writing up), then the pre-submission
sweep, then the smaller open items.

⛔ **Design principle he set today, and it governs everything now:** ACIM is timeless; YouTube,
archive.org and every feed are rented and will end. Rank every dependency — bundled content is permanent,
the feed lasts decades with maintenance, YouTube and archive.org are certain to end. **The app must be
wholly usable on bundled content alone, and every higher tier must be purely additive.** The app is not
permanent either, so nothing may be trapped inside it: bundled data stays human-readable JSON, and
reader-created content must export as plain text.
