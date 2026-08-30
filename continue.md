# continue.md — what is being worked on RIGHT NOW

⛔ **Current and future only.** No history, no history lessons, no ✅ recital of what a session did —
`git log` is the record. Open items live in [`todo.md`](todo.md), which is the source of truth; this file
says what is true now and what is next. REPLACE the state block below — never stack a new one under it.

---

## ✅ NOTHING IS CLAIMED

Working tree clean, branch `ralph/acim-3.9-to-5-finish-2026-04-14` pushed through `74b1ff5`. Nothing of
mine is running.

**The pipeline scheduler is his, running on MacLive, armed for 02:00 nightly.** Do not start a second one.
MacLive is an SMB mount of another machine (`//…@Chat._smb._tcp.local/MacLive`), so `pgrep` from this Mac
cannot see its processes — read `logs/acim.log` instead, and run `./start.sh` **on that machine**, never
through the mount.

**Build state — the binaries on both devices are at `e37d08f`:**
- 📱 **iPhone 11 Pro Max** (UDID `00008030-0004299C1410802E`) — Debug. ⭐ **This is where he is testing.**
- 💻 **iPad (10th gen) sim** `58B7D31D-70BB-4286-BBB7-09ADDE1F3EF4` — same build, booted.
- Commits after `e37d08f` are docs only — neither binary needs redeploying for them.
- ⛔ **A green `./build.sh` does NOT prove the device build compiles.** The arm64 slice catches Swift 6
  concurrency errors the simulator passes. `./build.sh` = 3 targets compile-only; `./both.sh` = +
  install/launch on the sim and the phone.

---

## ⛔ PICK UP HERE

**He is reporting bugs from the phone.** Take that list first — it outranks any sweep of mine.

**Then the pre-submission sweep.** Walk Archive, Saved, Lessons, deep links, widget and watch for surfaces
that display data they do not have. No `TODO`/`FIXME`/stub copy exists in any view/widget/watch source, so
what is left is behavioural empty-state handling — it needs an interactive pass on the device, not a text
search.

---

## ⛔ WHAT ONLY HE CAN CLOSE

- **Archive.org.** The flag refuses item *creation*; adding files to an existing item returns 200. He must
  create `acim-daily-minute` and `acim-daily-lessons` by hand at https://archive.org/upload (mediatype:
  audio). Then the backfill runs unattended. Re-check cheaply, no write path touched:
  `curl -s https://archive.org/metadata/acim-daily-minute` → `{}` means still blocked.
  ⛔ **Do not re-open the hosting decision unprompted** — he is choosing to wait. The gate is bigger than
  the backfill: the Today card's **Listen** button is already built and is invisible *only* because
  `audioURL` is empty. It ships the moment hosting works.
- **`Workbook365Bodies.json` is still the 3-byte `[]` placeholder** — content supply, his call. Until he
  drops the real file, most lessons render MetadataOnly/Absent and fall back to a YouTube embed.
- **Anything needing eyes on the phone.** No synthetic taps are available here: `cliclick` is killed on
  launch (no Accessibility permission), and there is no deep-link route for the Listen tab.

---

## ⬜ AGENT-OWNED WORK

His bug list, then the pre-submission sweep. After that, from [`todo.md`](todo.md): the `"YOURS.You"`
missing space (pipeline-side source data, not the app), a Listen deep-link route, and the Today-vs-Archive
bookmark aliasing.
