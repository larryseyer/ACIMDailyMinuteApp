# ACIM Daily Minute — open items

> **Role:** open-items ledger — what is open, blocked, or next. · **Status:** authoritative · **Verified:** 2026-08-30
> **Forward state:** [continue.md](continue.md)
>
> ⛔⛔ **FORWARD-ONLY, AND THAT IS AN OPERATOR RULE, NOT A STYLE.** Nothing here records what was done,
> when, or by whom — and no history lessons. An item is here because it is OPEN, BLOCKED or NEXT, and it
> **LEAVES the file the moment it is resolved.** History lives in `git log`.
>
> ⛔ **Dates the app shows follow the same rule.** Forward-looking dates are fine ("Available
> 2026-08-31"), and so is when the *reader* read or listened to something. When a reading was published
> is the app's own bookkeeping: it must not appear on any surface. The Archive tab is the one exemption —
> its dates are the index, not a stamp.

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

- [ ] **B4/B5** — no `01:00` chips anywhere; tapping an episode leaves a check mark and
      `Listened <date>`; swipe gives "Mark unplayed" and it clears. Lesson rows carry their length under
      the title. An *unlistened* row shows no date at all.
- [ ] **B8 — no publication dates anywhere.** Confirm none survives on Today, Lessons, lesson detail,
      Listen or the widget. The Archive tab is exempt by decision: dates there are the index you browse
      by, not a stamp on a reading.
- [ ] **B6** — a saved lesson opens that lesson; a saved minute opens its archive day. Swiping either
      direction deletes.
- [ ] **B7** — the counter reads `1 of 10` right after adding a phrase. Then set a phrase to a word in
      today's minute, force-quit, wait past the 60s debounce, relaunch, and confirm the notification
      arrives.

## ▶ NEXT — pre-submission sweep

- [ ] Walk **Archive, Saved, Lessons, deep links, widget, watch** for surfaces that display data they do
      not have. No `TODO`/`FIXME`/stub copy exists in any view/widget/watch source, so what remains is
      behavioural empty-state handling — needs an interactive pass on the device, not a text search.

## ▶ DESIGN — Timeless Today (corpus cycling)

- [ ] **When publishing ends, Today keeps serving the last-published minute forever.** A reader opening
      the app years later lands on a stale "today". Hiding dates does not fix this — the tab is called
      Today and the content would not be today's. Same for the widget, the Live Activity, and the
      "new Daily Minute" notification, which would simply never fire again.
- [ ] Corpus is small enough to ship with the app: **1,983 minute segments (2.4 MB) + 367 lessons
      (0.8 MB)**, ~3.2 MB total, measured from `data/acim.db` on MacLive. So the app can be made
      self-sufficient — no network, no pipeline, works forever.
- [ ] Direction to design: prefer the live feed while it is fresh, fall back to a deterministic
      date-keyed pick over the bundled corpus when it is not. Nothing changes while publishing runs;
      the takeover is automatic. The Workbook has a canonical mapping already — lesson N on day N of the
      year, which is how the book is meant to be used.
- [ ] The pick must be identical on phone, widget and watch for a given day, so it has to be a pure
      function of the date against a fixed epoch — not a random or install-relative choice.

## ▶ DESIGN — Reader annotations (highlights + notes)

Decisions already taken: dictation is the **system keyboard mic** (no permissions, no Speech framework,
`Data Not Collected` untouched); both live in the **Saved tab as segments** (Saved / Highlights / Notes),
keeping five tabs; notes attach to **any reading**, not lessons only.

- [ ] **Highlights.** Select words or phrases in a Daily Minute, Lesson or Archive reading and keep them.
      SwiftUI `Text` cannot do this — `.textSelection(.enabled)` exposes no selected range and takes no
      custom menu item — so it needs a `UITextView`/`NSTextView` representable with a "Highlight" entry in
      the edit menu. The same component paints stored highlights back via `NSAttributedString`.
- [ ] **Notes**, many per reading. Review periods send readers back to the same lesson, and they should
      find what they wrote last time alongside what they write now.
- [ ] ⛔ **Anchor them by reading identity plus offset plus the quoted text — never by a hash of the
      quoted text.** Store `channel|date` / `lesson:N`, the character range, and the quote itself. If the
      publisher edits the text the range drifts, so re-find by quote; if that fails, keep the highlight
      and mark it orphaned rather than dropping it silently.
- [ ] Both are real user content: SwiftData, which means adding to the `Schema` in **both**
      `ACIMDailyMinuteApp.swift` and `ACIMDailyMinuteWidget/SharedModelContainer.swift`, and to
      `project.pbxproj` for both targets. A schema mismatch between app and widget fails the shared
      container at launch.
- [ ] watchOS is out of scope for both.

## ▶ OPEN — physical-book parity gaps

What a physical *A Course in Miracles* gives a reader that this app does not yet. Ranked by how much
each one blocks "this replaces my book".

- [ ] **The Text is missing entirely** — 31 chapters, ~669 pages, the largest part of the volume and the
      whole theoretical basis. The app carries Daily Minute excerpts *drawn from* it but has no way to
      read it. Without this the app cannot claim to replace the book.
- [ ] **Manual for Teachers** (29 questions) and **Clarification of Terms** are also absent.
- [ ] **Canonical citations** (`T-1.I.1:1` — Text, chapter, section, paragraph, sentence). This is how
      the Course is quoted, taught and cross-referenced; study groups cannot use an app that cannot cite.
      `sourceReference` today is loose prose, not a citation.
- [ ] **Search across the whole corpus**, not just the rolling archive window — the book's index.
- [ ] **Cross-reference links** — the Course refers to itself constantly; tapping a citation should go there.
- [ ] **Resume where you stopped** — the ribbon in a physical book. Meaningful once the Text exists.
- [ ] **"Let it fall open"** — a random passage. A real practice with the physical book, trivial to offer.
- [ ] **Workbook completion tracking** — which lessons the reader has *done*, distinct from listened.
- [ ] ⛔ **Export / backup of highlights and notes.** No accounts and no analytics means no cloud
      fallback, so a lifetime of margin notes lives in one SwiftData file and dies with the device. A
      physical book's annotations survive; these would not. Export, or CloudKit private-database sync
      (the reader's own iCloud, which does not touch the `Data Not Collected` posture), or both.
- [ ] ⛔ **`Workbook365Bodies.json` is still `[]`, so most lesson bodies do not render at all.** Parity
      with the Workbook is blocked on content supply before any of the above matters.

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
