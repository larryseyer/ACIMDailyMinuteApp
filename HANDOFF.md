# Handoff — 2026-08-29

## Do this first

**Restart the pipeline.** It is not running. `logs/acim.log` ends with
"Shutting down..." at 19:46 on 2026-08-29 and `pgrep -f main.py` finds
nothing, so the 02:00 run will not happen and tomorrow becomes a seventh
missed day. On MacLive (`/Volumes/MacLive/Users/larryseyer/acim-daily-minute`),
in a terminal you can leave open:

```bash
./start.sh
```

Deliberately not started for you — you declined a background job on that
machine, and start.sh is meant to be a terminal you can watch.

The six missed days (**2026-03-27, 04-08, 04-29, 05-16, 05-31, 08-14**) stay
as they are: the recorded decision is to let the nightly catch-up absorb one
per night rather than spend six days of ElevenLabs credit at once. Note the
catch-up has never actually executed — it was committed (`0048e0f`, 20:31) a
few hours *after* that day's 02:19 run, and `grep -c "Catch-up" logs/acim.log`
is still 0. The first scheduled run after the restart is its first real test;
watch for a "Catch-up: N missing date(s)" line. `./catchup.sh list` reports
gaps, `./catchup.sh <n>` fills them by hand.

If you ever do fill them by hand, the ceiling is six per calendar day:
YouTube's Data API allows 10,000 units and `videos.insert` costs 1,600. If
that night's run has already published, only five fit. `run_catch_up` stops
after the first failure rather than hammering a dead API, and re-running is
safe — the duplicate guard makes it idempotent.

## Blocked on someone else

**Archive.org spam flag.** Audio publishing is built, tested, and cannot run
until Internet Archive clears the account. Larry emailed `info@archive.org` on
2026-08-29. The flag refuses item *creation* (S3 API and web uploader alike);
adding files to an item that already exists returns 200 — verified both ways.

Checked again 2026-08-29: `curl https://archive.org/metadata/acim-daily-minute`
and `.../acim-daily-lessons` both return HTTP 200 with body `{}` — archive.org's
answer for "identifier does not exist". Neither item has been created, so
nothing has changed yet. That probe is the cheap way to re-check; it costs
nothing and touches no write path.

Once the items exist, test whether the flag cleared by attempting one upload.
If it returns 200 instead of a 503 `"appears to be spam"`:

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
- Pipeline gained a catch-up pass to heal missed days — code is in place but
  has not executed yet (see "Do this first").

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
- ~~`fetchDailyLesson` / `fetchDailyMinute` force parameter~~, ~~`build.sh`
  watchOS destination~~, ~~`bu.sh` zip filename~~ — all three fixed in
  `c38c9b9`. The refresh note was misdiagnosed: the cooldown *was* being
  bypassed (both call sites cleared it). The actual gate was HTTP caching —
  `Cache-Control: max-age=600` meant a refresh inside ten minutes never
  reached origin. Measured old path 0 ms, new path 18 ms.
- Pre-submission sweep not started: walk Archive, Saved, Lessons, deep links,
  widget, and the watch app for surfaces that display data they don't have.
- Pipeline repo has uncommitted `lessons.py` and `.claude/settings.local.json`
  changes that are **not mine** — leave them alone.
