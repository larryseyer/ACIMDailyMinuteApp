# ACIM Daily Minute — open items

> **Role:** open-items ledger — what is open, blocked, or next. · **Status:** authoritative · **Verified:** 2026-08-30
> **Forward state:** [continue.md](continue.md)
>
> ⛔⛔ **FORWARD-ONLY, AND THAT IS AN OPERATOR RULE, NOT A STYLE.** Nothing here records what was done,
> when, or by whom — and no history lessons. An item is here because it is OPEN, BLOCKED or NEXT, and it
> **LEAVES the file the moment it is resolved.** History lives in `git log`.

---

## ⏸ BLOCKED — Archive.org (external; operator is choosing to wait)

- [ ] **Create the two items** `acim-daily-minute` and `acim-daily-lessons` (mediatype: audio) by hand at
      https://archive.org/upload. Blocked: the spam flag refuses item *creation*. Adding files to an item
      that already exists returns 200.
- [ ] **Run the backfill** once they exist, on MacLive:
      `venv/bin/python3 backfill_archive_audio.py --dry-run` then for real.
      239 MP3s sit in `audio/` on MacLive; a few older minutes have no local MP3 and are skipped with a
      warning. No app release needed — everything is feed-driven.
- Re-check cheaply: `curl -s https://archive.org/metadata/acim-daily-minute` → `{}` means still blocked.
- ⛔ Gating more than the backfill: the Today card's **Listen** button is already built and is invisible
      only because `audioURL` is empty. Do not re-open the hosting decision unprompted.

## ▶ NEXT — confirm the seven fixes on the phone

Built and installed on the phone and the iPad sim. B1, B2 and the notification-permission half of B7 are
confirmed by screenshot on the sim; the rest need eyes and a finger, since the sim has no bookmarks and
the Listen tab has no deep link.

- [ ] **B3** — Listen: the card shows our artwork clean under a red play button, no channel avatar and no
      title bar, on both Minute and Lessons. Tapping it plays.
- [ ] **B4/B5** — no `01:00` chips anywhere; tapping an episode leaves a check mark and
      `Listened <date>`; swipe gives "Mark unplayed" and it clears. Lesson rows carry their length under
      the title.
- [ ] **B6** — a saved lesson opens that lesson; a saved minute opens its archive day. Swiping either
      direction deletes.
- [ ] **B7** — the counter reads `1 of 10` right after adding a phrase. Then set a phrase to a word in
      today's minute, force-quit, wait past the 60s debounce, relaunch, and confirm the notification
      arrives.

## ▶ NEXT — pre-submission sweep

- [ ] Walk **Archive, Saved, Lessons, deep links, widget, watch** for surfaces that display data they do
      not have. No `TODO`/`FIXME`/stub copy exists in any view/widget/watch source, so what remains is
      behavioural empty-state handling — needs an interactive pass on the device, not a text search.

## ▶ WATCHING — nightly catch-up

- [ ] Five gaps remain: **2026-04-08, 04-29, 05-16, 05-31, 08-14**. One per night by design
      (`CATCH_UP_MAX_PER_RUN = 1`); ~five nights to clear. Confirm with `./catchup.sh list`.
- [ ] Next reach is **2026-04-08** at the 02:00 run. Fails soft; retries the next night.

## ▶ OPEN — content supply (operator's call)

- [ ] **`ACIMDailyMinute/Resources/Workbook365Bodies.json` is still the 3-byte `[]` placeholder.** Most
      lessons therefore render as MetadataOnly/Absent and fall back to a YouTube embed.
- [ ] **Lesson bodies render as one block.** The `lessons` table has no indented source to recover
      paragraph structure from.

## ▶ OPEN — pipeline side

- [ ] **`"YOURS.You"` is missing a space** in the published minute text, on every device. Source data, not
      the app. Look at the extractor's sentence-boundary handling.

## ▶ OPEN — small, unscheduled

- [ ] **No deep-link route for the Listen tab.** `DeepLinkRoute` covers today / lesson / archive / saved.
      Not a defect, but it makes that tab unverifiable without hand-tapping.
- [ ] **Today-tab and Archive-tab minute bookmarks do not alias.** Today keys on `DailyMinute.segmentHash`,
      Archive on `ArchivedReading.lineHash`, so the same passage saved from both places lands twice.
      Documented in `ArchivedReadingCard.swift`.
