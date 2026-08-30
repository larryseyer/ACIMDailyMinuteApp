# ACIM Daily Minute — open items

## Blocked on Archive.org (external)
- [x] **Email `info@archive.org`** — SENT 2026-08-29 by Larry. Awaiting reply.
      The flag refuses item *creation* (S3 and web UI alike); adding files to
      existing items returns 200.
- [ ] **Create items** `acim-daily-minute` and `acim-daily-lessons`
      (mediatype audio) — blocked by the flag above.
- [ ] **Run the backfill** once the items exist:
      `venv/bin/python3 backfill_archive_audio.py`
      232 episodes ready (150 minutes + 82 lessons); 9 older minutes have no
      local MP3 left on MacLive and are skipped with a warning.

## Blocking — the pipeline is not running
- [ ] **Restart `./start.sh` on MacLive.** The scheduler process shut down at
      19:46 on 2026-08-29 (`logs/acim.log`: "Shutting down...") and `pgrep
      main.py` finds nothing. Until it is restarted in a terminal, nothing
      publishes at 02:00 and tomorrow becomes a seventh missed day. Not started
      automatically here: Larry declined a background job on that machine, and
      start.sh is meant to be a terminal he can watch.

## Follow-ups
- [ ] Six missed days (2026-03-27, 04-08, 04-29, 05-16, 05-31, 08-14) fill
      themselves one per night via the catch-up pass. Decided 2026-08-29 to let
      the nightly run absorb them rather than spend six days of ElevenLabs
      credits at once. Confirm with `main.py --list-missing` over the next week.
      Note the mechanism is still **unexercised**: the catch-up code landed in
      commit `0048e0f` at 20:31 on 2026-08-29, after that day's 02:19 run, so
      `grep -c "Catch-up" logs/acim.log` is still 0. The first real test is the
      first scheduled run after a restart — watch for the "Catch-up: N missing
      date(s)" line.
- [ ] **Lesson text still has no paragraph breaks.** The repair covers
      `segments` (Daily Minute). Lesson bodies come from the `lessons` table,
      which has no equivalent source-with-indentation to recover from, so
      lessons still render as one block.

## Scheduling (settled 2026-08-29)
Runs from `./start.sh` in a terminal, as before — NOT a launch agent. Larry
declined an automatic background job on that machine, which already hosts two
other long-running terminals. The launch-agent attempt was reverted and the
agent file removed from `~/Library/LaunchAgents`; a corrected plist exists in
git history at commit 008e619 if that decision is ever revisited.

Missed days are covered by the catch-up pass instead: each scheduled run
publishes today and then fills one older gap, so a night where the terminal
was not running is repaid by the next run rather than lost. `./catchup.sh`
lists or fills gaps by hand.

## Fixed 2026-08-29 (commit `c38c9b9`)
- [x] **`build.sh` watchOS step.** Added `resolve_watch_sim_uuid()` alongside
      `resolve_ipad_sim_uuid()`; it searches every installed watchOS runtime
      and takes the newest that actually has `$WATCH_SIM`, then targets it by
      `id=` rather than `name=`. Resolves to 26.2 here. All three legs green.
- [x] **`bu.sh` backup zip filename.** `tr ' /:' '___'` replaces the old
      space-only `sed`, so `/` and `:` can no longer be read as path
      separators.
- [x] **Pull-to-refresh served stale JSON.** The old note said the cooldown
      could not be bypassed; it could — both call sites cleared it. The real
      gate was HTTP: the endpoints carry `Cache-Control: max-age=600`, so a
      refresh inside that window was answered from `URLCache` without ever
      reaching origin. `DataService.fetchDailyMinute/fetchDailyLesson` now take
      `force:` (mirroring `PodcastService`), which skips the cooldown *and*
      switches to `.reloadRevalidatingCacheData`. Measured against the live
      endpoint: old path 0 ms (pure cache read), new path 18 ms (revalidated).
      `FetchCooldown.reset` had no callers left and was removed.

## Known defects, not yet fixed
- [ ] **Pre-submission sweep not started.** Walk Archive, Saved, Lessons, deep
      links, the widget and the watch app for surfaces that display data they
      do not have. A grep of all 39 view/widget/watch sources found no
      `TODO`/`FIXME`/stub copy, so what is left is behavioral empty-state
      handling, which needs an interactive pass rather than a text search.
- [ ] **`ACIMDailyMinute/Resources/Workbook365Bodies.json` is still the 3-byte
      `[]` placeholder,** so lessons with no published body fall back to a
      YouTube embed. Content supply, not code — Larry drops the real
      365-lesson file when convenient.
