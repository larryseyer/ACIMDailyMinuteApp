# continue.md — what is being worked on RIGHT NOW

⛔ **No history here** — `git log` is the record. ⛔ **No ✅ recital of what a session did.** Open items
live in [`todo.md`](todo.md), which is the source of truth; this file says what is true now and what is
next. REPLACE the state block below — never stack a new one under it.

---

## ✅ NOTHING IS CLAIMED

Working tree **clean**, branch `ralph/acim-3.9-to-5-finish-2026-04-14` pushed through `9452f47`. Nothing
of mine is running.

⚠ **The pipeline scheduler IS running — his, started 21:38 on MacLive, armed for 02:00.** Do NOT start a
second one. ⛔ MacLive is an **SMB mount of another machine** (`//…@Chat._smb._tcp.local/MacLive`), so
`pgrep` from this Mac cannot see its processes — judging it dead that way already produced one wrong
claim. Read `logs/acim.log`, and run `./start.sh` **on that machine**, never through the mount.

**Build state — the binaries on both devices are at `e37d08f`:**
- 📱 **iPhone 11 Pro Max** (UDID `00008030-0004299C1410802E`) — Debug, installed 2026-08-29. ⭐ **This is
  where he is testing**, and he has confirmed by eye: chime, layout, paragraph rendering.
- 💻 **iPad (10th gen) sim** `58B7D31D-70BB-4286-BBB7-09ADDE1F3EF4` — same build, booted.
- ⛔ `9452f47` is **docs only** — it did not change either binary. Nothing needs redeploying for it.
- ⛔ **A green `./build.sh` does NOT prove the device build compiles.** The arm64 slice has caught Swift 6
  concurrency errors the simulator passed. `./build.sh` = 3 targets compile-only; `./both.sh` = +
  install/launch on the sim and the phone.

---

## ⛔ PICK UP HERE

**1. Confirm the 02:00 run — it is the catch-up's FIRST-EVER execution.** On MacLive:

```bash
cd /Volumes/MacLive/Users/larryseyer/acim-daily-minute
tail -40 logs/acim.log
./catchup.sh list
```

⭐ Watch for a line that has **never** appeared in that log:

```
Catch-up: 6 missing date(s): 2026-03-27, ...
Catch-up: producing 2026-03-27
```

`grep -c "Catch-up" logs/acim.log` is still **0**. 2026-08-30 is a **Sunday**, so the Lessons leg
self-skips (`lessons.py:363`) and the run is Daily Minute (~20–26 min) + one catch-up (~22 min), done by
~02:45. It reaches for **2026-03-27** first — the day ElevenLabs credits ran out — so that is where it
fails if credits are still short. ⭐ It fails soft: today's episode is already published by then, it
breaks after one error, and retries the next night. One gap per night by design
(`CATCH_UP_MAX_PER_RUN = 1`), ~six nights to clear; that bound is deliberate — an unbounded sweep is how
2026-03-27 was lost.

**2. Then the one open lane: the PRE-SUBMISSION SWEEP.** Walk Archive, Saved, Lessons, deep links, widget
and watch for surfaces that display data they do not have. ⚠ A grep of every view/widget/watch source
finds **no** `TODO`/`FIXME`/stub copy — so what is left is behavioural empty-state handling, and it needs
an interactive pass on the device, not a text search.

---

## ⛔ WHAT ONLY HE CAN CLOSE

- **Archive.org.** The flag refuses item *creation*; adding files to an existing item returns 200. He must
  create `acim-daily-minute` and `acim-daily-lessons` by hand at https://archive.org/upload (mediatype:
  audio). Then the backfill runs unattended. Re-check cheaply, no write path touched:
  `curl -s https://archive.org/metadata/acim-daily-minute` → `{}` means still blocked.
  ⛔ **He ruled "no rush" on 2026-08-29 and chose to keep waiting** rather than move hosting (rolling
  window on Pages, R2/B2 were all offered). **Do not re-open it unprompted** — but know the gate is bigger
  than the backfill: the Today card's **Listen** button is already built and is invisible *only* because
  `audioURL` is empty. It ships the moment hosting works.
- **`Workbook365Bodies.json` is still the 3-byte `[]` placeholder** — content supply, his call. Until he
  drops the real file, most lessons render MetadataOnly/Absent and fall back to a YouTube embed.
- **Anything needing eyes on the phone.** No synthetic taps are available here: `cliclick` is killed on
  launch (no Accessibility permission), and there is no deep-link route for the Listen tab.

---

## ⬜ AGENT-OWNED WORK

The pre-submission sweep above is the pick of it. After that, from [`todo.md`](todo.md): the `"YOURS.You"`
missing space (pipeline-side source data, not the app), a Listen deep-link route, and the Today-vs-Archive
bookmark aliasing — that last one is now *fixable* because the archive key was made stable, which was its
prerequisite.

---

## ⛔ TRAPS THAT HAVE EACH COST A CYCLE

- **A clean or Release build does NOT clear bad data.** SwiftData lives in the app container and survives
  reinstalling over the top; only deleting the app clears it. ⭐ That is also why **the simulator cannot
  reproduce store-migration bugs** — a fresh install has no stale rows, so it looks correct while the
  phone is wrong. Test those by deploying over an existing install, or with a standalone harness:
  `swiftc` the real model + service files together and drive them directly. Both repair passes were proven
  that way, and it is stronger evidence than a screenshot.
- **Never key a row by a hash of its content.** Three duplicate-row bugs came from `@Attribute(.unique)`
  identities computed from the text they identify. Key by date / `channel|date` / lesson number, and once
  an identity is assigned **never recompute it** — bookmarks key off `segmentHash`.
  [[project_identity_never_from_content]]
- **Two copies of the chime.** `assets/ACIMChime.caf` is the source he edits;
  `ACIMDailyMinute/Resources/ACIMChime.caf` is what ships. **Nothing syncs them — update both.**
  Notification sounds want little-endian Int16 CAF; a big-endian file fails **silently** and you get the
  default sound. Lossless: `afconvert -f caff -d LEI16@44100 -c 1 in.caf out.caf`.
- **New files must be added to `project.pbxproj` BY HAND** — manual file references, not synchronized
  groups, in four places (build file, file reference, group children, sources phase). `plutil -lint` after.
- **Feeds are the delivery mechanism.** Most app-visible fixes need a feed push;
  `github_push.push_all_daily_minute` / `push_all_daily_lesson` rebuild from the DB, Pages takes ~40 s.
- **`segments.text` vs `segments.text_paragraphs`.** `text` feeds ElevenLabs and video rendering — massage
  it freely for narration. `text_paragraphs` is the published reading. **Never cross them.**
- ⛔ **Voice is fixed.** ElevenLabs cloned voice, non-negotiable — never propose another TTS engine,
  including for backfill or in-app read-aloud. Pre-launch dates (2026-01-01 to 03-19) are deliberately not
  backfilled. [[project_voice_is_non_negotiable]]
- ⛔ **Zero references to the other news project anywhere in this repo.**
- ⛔ **The pipeline repo has uncommitted `lessons.py` and `.claude/settings.local.json` changes that are
  NOT ours** — leave them alone.
- **Scheduling is `./start.sh` in a terminal, deliberately not a launch agent** — he declined a background
  job on that machine. A corrected plist exists at pipeline commit `008e619` if ever revisited.
