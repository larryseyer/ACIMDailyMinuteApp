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

## Follow-ups
- [ ] Six missed days (2026-03-27, 04-08, 04-29, 05-16, 05-31, 08-14) fill
      themselves one per night via the catch-up pass. Decided 2026-08-29 to let
      the nightly run absorb them rather than spend six days of ElevenLabs
      credits at once. Confirm with `main.py --list-missing` over the next week.
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

## Known defects, not yet fixed
- [ ] **`build.sh` watchOS step is broken on this machine.** It pins
      `Apple Watch Series 10 (46mm)` with no runtime, so `OS:latest` resolves to
      26.5 where no such sim exists (installed: 11.2 and 26.2). Needs the same
      UUID resolution `resolve_ipad_sim_uuid` already does. Worked around by
      building against a UUID directly.
- [ ] **`bu.sh` backup zip fails** when a commit message contains `/` — it
      builds the filename with `sed 's/ /_/g'` and the slash becomes a path
      separator. Needs a `/` strip.
