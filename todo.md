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

## Awaiting Larry's decision
- [ ] **Push regenerated feeds?** The rebuilt `github_push.py` emits
      `audio_url: ""` and omits `<enclosure>` where no audio is published.
      Pushing now removes the 404-ing enclosures from the public podcast feeds
      and makes the app stop showing a failing Listen button. Real enclosures
      return automatically after the backfill.

## Uncommitted
- [ ] **Pipeline repo** (`/Volumes/MacLive/Users/larryseyer/acim-daily-minute`):
      `archive_upload.py`, `migrate_db_audio_url.py`,
      `backfill_archive_audio.py` (new) and `github_push.py` (modified) are
      written, tested, and unstaged. `lessons.py` also shows as modified — not
      my change, left alone. Migration has already been applied to the DB.

## Known defects, not yet fixed
- [ ] **`build.sh` watchOS step is broken on this machine.** It pins
      `Apple Watch Series 10 (46mm)` with no runtime, so `OS:latest` resolves to
      26.5 where no such sim exists (installed: 11.2 and 26.2). Needs the same
      UUID resolution `resolve_ipad_sim_uuid` already does. Worked around by
      building against a UUID directly.
- [ ] **`bu.sh` backup zip fails** when a commit message contains `/` — it
      builds the filename with `sed 's/ /_/g'` and the slash becomes a path
      separator. Needs a `/` strip.
