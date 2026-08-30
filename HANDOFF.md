# Handoff — 2026-08-29

## Do this first

Fill all six missed publishing days. On MacLive (volume mounted at
`/Volumes/MacLive/Users/larryseyer/acim-daily-minute`):

```bash
./catchup.sh list     # confirm the six are still listed
./catchup.sh 6        # fill them, oldest first
```

The six: **2026-03-27, 04-08, 04-29, 05-16, 05-31, 08-14**.

**Read this before running it.** Six uploads in one day has never been done —
every day in `upload_log` has exactly one. Two limits are in play:

- **YouTube Data API**: 10,000 units/day, `videos.insert` costs 1,600 → a hard
  ceiling of **six uploads per calendar day**. If the normal nightly run has
  already published today, only **five** will fit and the sixth fails with a
  quota error. Prefer running the catch-up *before* that night's run, or fill
  five now and let the nightly pass take the last one.
- **ElevenLabs**: needs ~7,700 characters (avg unused segment is 1,281 chars ×
  6). Small against the ~130k/month the 2026-03-27 quota error implies, but the
  `/v1/user/subscription` endpoint returned no usable fields when checked, so
  remaining credit is **unverified**. Watch the first run's log.

`run_catch_up` stops after the first failure rather than hammering a dead API,
so a quota wall costs one failed day, not six. Re-running is safe — the
duplicate guard (`Already uploaded for <date> — skipping`) makes it idempotent.

Each filled day pushes the regenerated feeds automatically. Verify after:

```bash
./catchup.sh list                      # expect "No missing dates."
curl -s https://www.acimdailyminute.org/daily-minute.json | head
```

## Blocked on someone else

**Archive.org spam flag.** Audio publishing is built, tested, and cannot run
until Internet Archive clears the account. Larry emailed `info@archive.org` on
2026-08-29. The flag refuses item *creation* (S3 API and web uploader alike);
adding files to an item that already exists returns 200 — verified both ways.

Test whether it has cleared by attempting one upload. If it returns 200 instead
of a 503 `"appears to be spam"`:

```bash
# 1. create the two items once at https://archive.org/upload (mediatype: audio)
#      acim-daily-minute      acim-daily-lessons
# 2. then, on MacLive:
venv/bin/python3 backfill_archive_audio.py --dry-run
venv/bin/python3 backfill_archive_audio.py
```

232 episodes are ready (150 minutes + 82 lessons; 9 older minutes have no local
MP3 left and are skipped with a warning). **No app release is needed** — Listen
buttons return on their own because everything is feed-driven.

## State

Two repos. App is `/Users/larryseyer/ACIMDailyMinuteApp` on branch
`ralph/acim-3.9-to-5-finish-2026-04-14`, pushed. Pipeline is
`/Volumes/MacLive/Users/larryseyer/acim-daily-minute`, committed locally (no
remote configured).

Shipped this session, all live and on the physical iPhone:

- Audio load failures tear the player down and report in plain language instead
  of echoing the origin server's HTML.
- Readings render ACIM's real paragraphs. 1983/1983 segments matched.
- Tapping a lesson opens its video full screen, autoplaying, landscape on
  iPhone.
- Each lesson plays **its own** video, not a playlist index.
- YouTube captions forced off (they covered the burned-in reading text).
- Listen falls back to the episode video when no audio is published.
- Archive calendar marks days that have readings and has a legible selection.
- Feeds only advertise audio that exists; each item carries its video as
  `<link>`.
- Pipeline heals missed days automatically.

## Things that will bite you

**Feeds are the delivery mechanism.** Most app-visible fixes need a feed push
to appear. `github_push.push_all_daily_minute` / `push_all_daily_lesson`
rebuild everything from the DB. GitHub Pages takes ~40s to serve the change.

**Record, never compute.** The original bug: feed URLs were derived from a
formula that never checked whether a file existed, so every enclosure 404'd
since launch. Audio URLs now come from `upload_log.audio_public_url`, written
only after a verified upload. Same class of bug produced the playlist-index
video mix-up. Do not reintroduce either.

**`segments.text` vs `segments.text_paragraphs`.** `text` feeds ElevenLabs and
video rendering — massage it freely for narration. `text_paragraphs` is the
published reading. Never cross them.

**Scheduling is `./start.sh` in a terminal, deliberately not a launch agent.**
Larry declined a background job on that machine. Reverted; agent file removed.
A corrected plist exists at pipeline commit `008e619` if ever revisited.

**Voice is fixed.** ElevenLabs cloned voice, non-negotiable. Never propose
another TTS engine, including for backfill. Pre-launch dates (2026-01-01 to
03-19) are deliberately not backfilled.

**Verify on the physical iPhone.** UDID `00008030-0004299C1410802E`. A green
`./build.sh` does not prove the device build compiles — the arm64 slice caught
two Swift 6 concurrency errors the simulator passed.

**Zero references to the other news project anywhere in this repo.**

## Still open (also in todo.md)

- Lesson bodies render as one block. The paragraph repair covered `segments`
  only; lesson text comes from the `lessons` table, which has no indented
  source to recover structure from.
- `fetchDailyLesson` / `fetchDailyMinute` have no `force` parameter, so
  pull-to-refresh cannot bypass the cooldown (15 min for lessons).
  `PodcastService` already supports `force:`.
- `build.sh`'s watchOS step pins `Apple Watch Series 10 (46mm)` with no runtime;
  `OS:latest` resolves to 26.5 where no such sim exists. Needs the UUID
  resolution `resolve_ipad_sim_uuid` already does.
- `bu.sh`'s backup zip fails when a commit message contains `/`.
- Pre-submission sweep not started: walk Archive, Saved, Lessons, deep links,
  widget, and the watch app for surfaces that display data they don't have.
- Pipeline repo has uncommitted `lessons.py` and `.claude/settings.local.json`
  changes that are **not mine** — leave them alone.
