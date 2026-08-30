# ACIM Daily Minute — Continuation

> **Role:** forward state — what is true NOW and what is next. · **Status:** authoritative · **Verified:** 2026-08-29
> **Open items:** [todo.md](todo.md) · **Parity:** [PARITY.md](PARITY.md)
>
> ⛔⛔ FORWARD-ONLY, NO HISTORY, EVER. History lives in `git log`; deferral detail lives in `todo.md`.
> REPLACE the head block; never stack another under it, and never leave a ✅ recital of what a session did.

## ▶▶▶ NEW CHAT — START HERE

⛔ **NOTHING IS BROKEN.** Working tree clean, branch `ralph/acim-3.9-to-5-finish-2026-04-14` pushed
through `e37d08f`. All three sim targets green and the arm64 device slice builds clean. The operator has
the current build on the physical iPhone 11 Pro Max and has confirmed by eye: chime, iPad + iPhone layout,
and paragraph rendering.

⚠ **The pipeline scheduler is RUNNING on MacLive** (started 21:38, armed for 02:00). Do not start a second
one.

## ▶▶ NEXT ACTION

**1. Confirm the 02:00 run — it is the catch-up's first-ever execution.** On MacLive itself:

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
fails if credits are still short. It fails soft: today's episode is already published by then, it breaks
after one error, and retries the next night. One gap per night by design
(`CATCH_UP_MAX_PER_RUN = 1`); ~six nights to clear. That bound is deliberate — an unbounded sweep is how
2026-03-27 was lost in the first place.

**2. Then the one uncommitted lane: the PRE-SUBMISSION SWEEP** (`todo.md`). Walk Archive, Saved, Lessons,
deep links, widget and watch for surfaces that display data they do not have. A grep of every
view/widget/watch source finds **no** `TODO`/`FIXME`/stub copy, so what is left is behavioural
empty-state handling — it needs an interactive pass on the device, not a text search.

## ⏸ BLOCKED ON ARCHIVE.ORG (external, operator ruled "no rush")

Audio publishing is built and tested and cannot run until Internet Archive clears the account. The flag
refuses item *creation*; adding files to an item that already exists returns 200. Cheap read-only
re-check — costs nothing, touches no write path:

```bash
curl -s https://archive.org/metadata/acim-daily-minute     # {} = still does not exist
```

When it returns real metadata: create `acim-daily-minute` and `acim-daily-lessons` by hand at
https://archive.org/upload (mediatype: audio), then on MacLive run `backfill_archive_audio.py --dry-run`
and then for real. 237 MP3s ready locally (475 MB). **No app release needed** — everything is feed-driven.

⛔ **This gate is bigger than the backfill, and the operator has already ruled on it.** The Listen button
on the Today card is fully built (`DailyMinuteCard`, gated on a non-empty `audioURL`) and invisible only
because no audio is published — it ships the moment hosting works. Alternatives (rolling window on GitHub
Pages, R2/B2) were put to him 2026-08-29 and he chose **keep waiting on Archive.org, explicitly "no
rush."** Do NOT re-open that unprompted.

## ▶ STANDING HAZARDS (durable)

⛔ **A clean or Release build does NOT clear bad data.** SwiftData lives in the app container and survives
reinstalling over the top; only deleting the app clears it. That is also why the **simulator cannot
reproduce store-migration bugs** — a fresh install has no stale rows. Test those by deploying over an
existing install, or with a standalone harness: `swiftc` the real model + service files together and drive
them directly. That is how both repair passes were proven, and it is stronger evidence than a screenshot.

⛔ **MacLive is an SMB mount of ANOTHER machine** (`//…@Chat._smb._tcp.local/MacLive`). `pgrep` from this
Mac cannot see its processes — judging the scheduler dead that way has already produced one wrong claim.
Read `logs/acim.log`, and run `./start.sh` **on that machine**, never through the mount.

⛔ **Two copies of the chime.** `assets/ACIMChime.caf` is the source the operator edits;
`ACIMDailyMinute/Resources/ACIMChime.caf` is what ships. **Nothing syncs them — update both.** Notification
sounds want little-endian Int16 CAF; a big-endian file fails **silently** and you just get the default
sound. Lossless fix: `afconvert -f caff -d LEI16@44100 -c 1 in.caf out.caf`.

⛔ **New files must be registered in `project.pbxproj` BY HAND** — manual file references, not synchronized
groups, in four places (build file, file reference, group children, sources phase). `plutil -lint` after.

⛔ **Never key a row by a hash of its content.** Three duplicate-row bugs came from
`@Attribute(.unique)` identities computed from the text they identify. Key by date / `channel|date` /
lesson number, and once an identity is assigned never recompute it — bookmarks key off `segmentHash`.
See [[project_identity_never_from_content]].

## ▶ STANDING RULES (durable)

- **Verify on the physical iPhone.** UDID `00008030-0004299C1410802E`. A green `./build.sh` does NOT prove
  the device build compiles — the arm64 slice has caught Swift 6 concurrency errors the simulator passed.
  `./build.sh` = 3 targets compile-only; `./both.sh` = + install/launch on iPad sim and the iPhone.
- **Feeds are the delivery mechanism.** Most app-visible fixes need a feed push.
  `github_push.push_all_daily_minute` / `push_all_daily_lesson` rebuild from the DB; Pages takes ~40 s.
- **Record, never compute** — applies to URLs *and* to identity.
- **`segments.text` vs `segments.text_paragraphs`.** `text` feeds ElevenLabs and video rendering — massage
  it freely for narration. `text_paragraphs` is the published reading. Never cross them.
- **Scheduling is `./start.sh` in a terminal, deliberately not a launch agent.** The operator declined a
  background job on that machine. A corrected plist exists at pipeline commit `008e619` if ever revisited.
- **Voice is fixed.** ElevenLabs cloned voice, non-negotiable. Never propose another TTS engine — including
  for backfill or for in-app read-aloud. Pre-launch dates (2026-01-01 to 03-19) are deliberately not
  backfilled. See [[project_voice_is_non_negotiable]].
- **Zero references to the other news project anywhere in this repo.**
- **Pipeline repo has uncommitted `lessons.py` and `.claude/settings.local.json` changes that are NOT
  ours — leave them alone.**

## ▶ SESSION KICKOFF (fresh chat)

1. Read this file + [todo.md](todo.md).
2. Go to **NEXT ACTION** above. If the operator says only "proceed": check the 02:00 catch-up first, then
   offer the **pre-submission sweep** — it is the one lane that is neither blocked nor done.
3. Do NOT re-open the audio-hosting decision. Do NOT start a second scheduler.
