# ACIM Daily Minute — open items

## Blocked on Archive.org (external)
- [ ] **Email `info@archive.org`** to clear the false spam flag on account
      `larryseyer@gmail.com`. Item *creation* is refused (S3 and web UI alike);
      adding files to existing items returns 200. Draft + full error text are in
      the 2026-08-29 session.
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

## Handoff — needs running on MacLive
- [ ] `launchctl load ~/Library/LaunchAgents/com.acim.dailyminute.plist`
      The agent file is installed and validated, but launchctl only acts on the
      session of the machine it runs from, so this cannot be done remotely.
      Until it is loaded (or the user next logs in) NOTHING is scheduled — the
      old resident scheduler was deliberately killed on 2026-08-29.
      Do NOT restart the old `main.py` scheduler: two schedulers competing for
      02:00 is the overlapping-run condition behind the 2026-05-31 YouTube 409.

## Known defects, not yet fixed
- [ ] **`build.sh` watchOS step is broken on this machine.** It pins
      `Apple Watch Series 10 (46mm)` with no runtime, so `OS:latest` resolves to
      26.5 where no such sim exists (installed: 11.2 and 26.2). Needs the same
      UUID resolution `resolve_ipad_sim_uuid` already does. Worked around by
      building against a UUID directly.
- [ ] **`bu.sh` backup zip fails** when a commit message contains `/` — it
      builds the filename with `sed 's/ /_/g'` and the slash becomes a path
      separator. Needs a `/` strip.
