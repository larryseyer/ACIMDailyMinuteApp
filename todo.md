# ACIM Daily Minute — open items

> **Role:** open-items ledger — what is open, blocked, or next. · **Status:** authoritative · **Verified:** 2026-08-30
> **Forward state:** [continue.md](continue.md)
>
> ⛔⛔ **FORWARD-ONLY, AND THAT IS AN OPERATOR RULE, NOT A STYLE.** Nothing here records what was done,
> when, or by whom — and no history lessons. An item is here because it is OPEN, BLOCKED or NEXT, and it
> **LEAVES the file the moment it is resolved.** History lives in `git log`.
>
> ⛔ **The durability rule governs every item below.** ACIM is timeless; YouTube, archive.org and every
> feed are rented and will end. Bundled content is permanent, the feed lasts decades with maintenance,
> YouTube and archive.org are certain to end. The app must be wholly usable on bundled content alone,
> every higher tier purely additive, and its absence invisible rather than broken. The app itself is not
> permanent either — bundled data stays human-readable JSON, and reader-created content must export as
> plain text.
>
> ⛔ **The server owns Daily Minute selection, and the app can never compute it.** The pipeline picks a
> **random** unused segment each day — all 158 observed transitions in `segments.used_date` jump — and it
> must be the server anyway, because the run then builds the ElevenLabs narration and the YouTube render.
> `daily-minute.json` is the sole authority for the whole remaining publishing run. A bundled corpus is a
> *floor* for when the feed is stale or unreachable, never a replacement, and a corpus reading is never
> persisted as a `DailyMinute` row. Lessons are the exception: their selection **is** sequential, so
> day-of-year → Lesson N is valid for lessons once publishing completes.
>
> ⛔ **Dates the app shows follow the same rule.** Forward-looking dates are fine ("Available
> 2026-08-31"), and so is when the *reader* read or listened to something. When a reading was published
> is the app's own bookkeeping and must not appear on any surface. The Archive tab is the one exemption —
> its dates are the index, not a stamp.

---

## ▶ NEXT — execute the Timeless Corpus plan

⛔ The spec and plan are **not in git** — `.gitignore:54` keeps `docs/` local on purpose. They exist only
on this Mac at `docs/superpowers/specs/2026-08-30-timeless-corpus-design.md` and
`docs/superpowers/plans/2026-08-30-timeless-corpus.md`. Approved; five tasks; not started.

- [ ] **Task 1 — export the corpus.** `tools/export_corpus.py` reads `data/acim.db` on MacLive and writes
      four JSON resources. ⭐ **Do this one first even if nothing else follows**: it fills
      `Workbook365Bodies.json` (a 3-byte `[]` today) and every lesson body then renders with no code
      change, because `WorkbookBodiesCatalog.body(for:)` is already consumed at `LessonDetailView:227`
      and `:313`. All 365 bodies are in the database and always were — this was never a content-supply
      problem.
- [ ] **Task 2 — `CorpusService`** over the bundled files, with a `swiftc` integrity harness asserting
      1,983 segments / 268 Text sections / 105 Manual segments / 365 lesson bodies, none empty.
- [ ] **Task 3 — retain `segmentId → youtubeID / audioURL`** in a `SegmentMedia` model that does not age
      out, so the rolling archive stops discarding the only link between the permanent corpus and the
      recordings made for it. Must be added to the `Schema` in **both** `ACIMDailyMinuteApp.swift` and
      `ACIMDailyMinuteWidget/SharedModelContainer.swift` — a mismatch crashes the shared container at
      launch.
- [ ] **Task 4 — a corpus floor under Today** when the feed is stale or unreachable. Never persisted as a
      `DailyMinute` row (it would collide on the date key). Verified in airplane mode after a fresh install.
- [ ] **Task 5 — MP3 download.** Inert until archive.org hosting exists, then works with no further app
      change. ⛔ **Video download is ruled out, not deferred** — it breaches YouTube's terms regardless of
      who owns the upload, fails App Store review, and at 42.8 MB against audio's 2.00 MB is impractical.

## ▶ NEXT — his confirmation on four fixes already on his phone

Built and installed at `8cb09f9`. B1, B2 and B3 are confirmed and retired.

- [ ] **B4/B5 — Listen rows.** No `01:00` chips anywhere. Tapping an episode leaves a check mark and
      `Listened <date>`; swipe offers "Mark unplayed" and it clears. Lesson rows carry their length under
      the title. An unlistened row shows no date at all.
- [ ] **B6 — Saved tab.** Tapping a saved lesson opens that lesson and a saved minute opens its archive
      day. Swiping either direction deletes. ⚠ Both edges full-swipe, so any horizontal flick removes a
      bookmark — say so if the leading edge should require a tap on Delete instead.
- [ ] **B7 — watched phrases.** The counter reads `1 of 10` immediately after adding a phrase. Then set a
      phrase to a word in today's minute, force-quit, wait past the 60s debounce, relaunch, and confirm
      the notification arrives. Notification permission is now requested at launch; it used to be reached
      only by switching the daily reminder on, so anyone who left that off was never asked and every
      alert was discarded unasked-for.
- [ ] **The date sweep.** Publication dates are gone from Today, Lessons, lesson detail, Listen and all
      three widget sizes, and the privacy policy no longer carries a revision year. Confirm nothing dated
      survives where he can see it.

## ▶ DESIGN — reader annotations (highlights + notes)

Decisions are made and need writing into a spec; no further questions are outstanding.

- [ ] Dictation is the **system keyboard mic** (Fn Fn on macOS). No permissions, no Speech framework, no
      change to the `Data Not Collected` label. Info.plist carries **zero** usage descriptions today and
      should keep carrying zero.
- [ ] Both live in the **Saved tab as segments** (Saved / Highlights / Notes), keeping five tabs — a sixth
      collapses into iOS's "More" list and buries Saved with it.
- [ ] Notes attach to **any reading**, not lessons only, and there may be **many per reading** — review
      periods send readers back to the same lesson and they should find what they wrote last time.
- [ ] **Highlights need a `UITextView`/`NSTextView` representable.** SwiftUI `Text` cannot do this:
      `.textSelection(.enabled)` exposes no selected range and accepts no custom menu item. Use
      `textView(_:editMenuForTextIn:suggestedActions:)` on iOS and the delegate menu hook on macOS. The
      same component paints stored highlights back via `NSAttributedString`.
- [ ] ⛔ **Anchor by reading identity plus offset plus the quoted text — never by a hash of the quote.**
      Store `channel|date` / `lesson:N`, the character range, and the quote. If the publisher edits the
      text the range drifts: re-find by quote, and if that fails keep the highlight and mark it orphaned
      rather than dropping it silently.
- [ ] ⛔ **Export as plain text from the start.** No accounts and no analytics means no cloud fallback, so
      a lifetime of annotation would live in one SwiftData file and die with the device. Retrofitting
      export onto existing data is harder than designing it in. CloudKit private database is the optional
      second route and does not touch the privacy posture.
- [ ] watchOS is out of scope for both.

## ⏸ BLOCKED — Archive.org (external; no reply received)

- [ ] **Create the two items** `acim-daily-minute` and `acim-daily-lessons` (mediatype: audio) by hand at
      https://archive.org/upload. Blocked: the spam flag refuses item *creation*. Adding files to an item
      that already exists returns 200. He has heard nothing back about the ban.
- [ ] **Run the backfill** once they exist, on MacLive:
      `venv/bin/python3 backfill_archive_audio.py --dry-run` then for real.
      239 MP3s (604 MB) sit in `audio/` on MacLive covering everything published so far; the rest are
      produced daily alongside publishing. No app release needed — everything is feed-driven.
- Re-check cheaply: `curl -s https://archive.org/metadata/acim-daily-minute` → `{}` means still blocked.
- ⛔ Do not re-open the hosting decision unprompted.

## ▶ WATCHING — nightly catch-up

- [ ] Five gaps remain: **2026-04-08, 04-29, 05-16, 05-31, 08-14**. One per night by design
      (`CATCH_UP_MAX_PER_RUN = 1`); ~five nights to clear. Confirm with `./catchup.sh list`.
- [ ] Next reach is **2026-04-08** at the 02:00 run. Fails soft; retries the next night.

## ▶ OPEN — physical-book parity gaps

What a physical *A Course in Miracles* gives a reader that this app does not. Ranked by how much each
blocks "this replaces my book". The corpus plan above puts the content in place; these are what turn it
into a book.

- [ ] **The Text is not readable in the app** — 31 chapters, ~669 pages, the largest part of the volume
      and the whole theoretical basis. The corpus plan bundles it; **Spec 2** is the reading UI: chapters,
      sections, navigation.
- [ ] ⛔ **Canonical citations** (`T-1.I.1:1` — Text, chapter, section, paragraph, sentence). Promoted
      from a study-group convenience to a **durability requirement**: citations are the interoperability
      layer that lets a reader move between this app, a paper book, and whatever comes after both.
      `sourceReference` today is loose prose, not a citation.
- [ ] **Search across the whole corpus**, not just the rolling archive window — the book's index.
- [ ] **Cross-reference links** — the Course refers to itself constantly; a citation should be tappable.
- [ ] **Resume where you stopped** — the ribbon. Meaningful once the Text is readable.
- [ ] **"Let it fall open"** — a random passage. A real practice with the physical book, nearly free once
      the corpus is bundled.
- [ ] **Workbook completion tracking** — which lessons the reader has *done*, distinct from listened.
- [ ] **Structure the Manual for Teachers** into its question-and-answer form. It is bundled as 105
      unstructured segments by decision; a searchable unstructured Manual beats no Manual.
- [ ] **The two Part Introductions** (lesson ids 0 and 500 in the database) are outside the 1–365 spine
      and are not exported by the corpus plan. Spec 2 should place them.

## ▶ OPEN — content and pipeline

- [ ] **`"YOURS.You"` is missing a space** in the published minute text, on every device. Source data, not
      the app. Look at the extractor's sentence-boundary handling.
- [ ] **Lesson bodies render as one block.** The `lessons` table has no indented source to recover
      paragraph structure from. Distinct from the bodies being absent, which Task 1 fixes.

## ▶ OPEN — small, unscheduled

- [ ] **The Listen tab has no defined behaviour when YouTube fails.** `LiteYouTubeCard` needs a
      `WKNavigationDelegate` failure path so a dead video source degrades to what it has rather than a
      dead frame. Called out in the corpus plan's self-review as the one spec requirement no task covers;
      it belongs with Listen work, not corpus work.
- [ ] **No deep-link route for the Listen tab.** `DeepLinkRoute` covers today / lesson / archive / saved.
      Not a defect, but it makes that tab unverifiable without hand-tapping.
- [ ] **Today-tab and Archive-tab minute bookmarks do not alias.** Today keys on `DailyMinute.segmentHash`,
      Archive on `ArchivedReading.lineHash`, so the same passage saved from both places lands twice.
      Documented in `ArchivedReadingCard.swift`.
- [ ] **Pre-submission sweep.** Walk Archive, Saved, Lessons, deep links, widget and watch for surfaces
      that display data they do not have. No `TODO`/`FIXME`/stub copy remains in any view, widget or watch
      source, so what is left is behavioural empty-state handling — an interactive pass on the device.
