# ACIM Daily Minute — open items

One sentence per item, two at the most. Current and future only. Git is history.

---

## PARKED — one test pass, at the end, on his phone

Do not ask him to check any of this until everything below is built. His words: otherwise he will just repeat himself on things that have not been done yet.

- [ ] A reading reaches its last sentence on the phone: Chapter 1 Distortions, a Workbook lesson, the Workbook introduction, a Manual segment; then say whether Chapter 1 Principles of Miracles still scrolls without stutter.
- [ ] Light appearance at 375pt, and the reminders: Follow the lesson's practice names today's lesson; a tap opens it; Daily Minute and Daily Lesson fire at their own times; nothing arrives during Focus.
- [ ] The watch on a wrist: today's Daily Minute under **Today**, bundled fallback under **From the Course** with the phone off; place the complication in all three shapes.
- [ ] Listen rows: no `01:00` chips; tap leaves a check and `Listened <date>`; swipe offers Mark unplayed; unlistened rows show no date.
- [ ] Saved tab: a saved lesson opens the lesson, a saved minute opens the passage; swipe either direction deletes — say if the leading edge should require a tap on Delete instead.
- [ ] An unpublished lesson (1–80) shows the full bundled text, no YouTube stand-in.
- [ ] Lesson 90 opens; the clock line and the row agree on the same available date.
- [ ] Archive calendar: 2026-09-10 / 05-31 / 03-01 each show the sentence that belongs to that kind of empty day.
- [ ] Share on the Mac draws bare, like the phone.
- [ ] Airplane mode, delete and reinstall, cold launch: Today shows a bundled reading with no save, share, or Listen.
- [ ] Listen swipe Download, then Remove download; a downloaded row plays from disk in airplane mode; look at the swipe at 375pt.
- [ ] A reading should scroll to its place on macOS too (spotlight and ribbon).
- [ ] The ribbon on the phone at 375pt: Continue reading names the right section and opens it.
- [ ] A search hit two screens down is on screen, words tinted blue.
- [ ] Companion note under Settings > About: three wording departures are his to veto.
- [ ] Privacy policy is reachable from Settings > About.
- [ ] Highlights and notes end to end; there is no mic button.
- [ ] Saved is three segments: empty states, both swipe edges, a highlight or note row opens its reading.
- [ ] Export hands over plain text a stranger could follow, with only the reader's dates.
- [ ] Six surfaces now draw through a text view: serif, spacing, no clip, long-press selects. Phone is what is left.
- [ ] Publication dates are gone from Today, Lessons, Listen, widgets, and the privacy policy.
- [ ] Tab 1 is Read (Workbook / Text); a widget or notification tap on a lesson still opens that lesson.
- [ ] Chapter 1 Principles of Miracles is 53 numbered paragraphs.
- [ ] Chapter 1.2 (34,385 characters) scrolls without stutter on the phone.
- [ ] Previous and Next cross chapter boundaries; the first Preface section offers no Previous.
- [ ] Highlight and Note work in the Text; Saved rows open the passage; a Manual row still will not navigate, by design.
- [ ] Spacing repair reads as the book; today's minute on the phone and lock screen is clean.
- [ ] Part 1 Introduction above Lesson 1; Part 2 Introduction between 180 and 181.
- [ ] Citations are `T-5.3` Arabic, not the widely-cited edition — that judgement is his to overturn.
- [ ] The two Workbook Part Introductions are not named Lesson 0 or Lesson 500 in Saved or export.
- [ ] Chapter 16 opens on recovered prose, not True Empathy; today's `T-16.1` is `T-16.2`.
- [ ] Card header: title on its own line, Listen leading, Share and Save trailing; tap Save does not shift the layout.
- [ ] Tap Save, leave, come back, tap again: it saves then un-saves every time.
- [ ] Backup & Restore produces a file that reads as a document.
- [ ] Restoring merges rather than duplicates; a second restore of the same file adds nothing; conflicting notes keep both versions.
- [ ] Import summary wording is his to keep or change.
- [ ] Introduction last page is Continue, then the companion note, then Get Started; check at 375pt.
- [ ] Saving, then deleting from the Saved tab, goes through BookmarkStore.
- [ ] Highlights and notes survived the store split on the phone; Archive refilled.
- [ ] iCloud: a mark on the phone reaches the Mac; deleting on either device removes it from both.
- [ ] Privacy policy describes iCloud; read it as a whole.
- [ ] Before any release build: deploy the CloudKit schema from Development to Production.
- [ ] Folder copy: a chosen Dropbox or iCloud Drive folder gets a per-device file; nothing is ever read from it.
- [ ] Search the Course: hits in book order with citation and snippet; a lesson opened this way does not open its video first.
- [ ] A Manual highlight, note, or saved row opens its passage.
- [ ] Cross-reference links: tap `[67]` on a review lesson; Daily Minute footer is tappable; Back returns.
- [ ] One reading shape everywhere: Share and Save together on the trailing edge; Save gone from the nav bar.
- [ ] Daily Minute passage screen (a Saved row): Share and not Save; tappable footer `W-290.3` lands in the Workbook.

## PAUSED — standardized reading layout (D is next)

His calls already made: Add note stays at the bottom; one play control, audio-first; tab bar becomes Today | Read | Listen | Video | Saved; Listen becomes activity, not a catalogue.

- [ ] D — Archive becomes Video. App-only; confirm the recast with him before building.
- [ ] E — Structure the Manual. Its 105 bundled rows are word-count cuts, not the book's questions.
- [ ] B — Media index + inline play control. Feed-driven overlay keyed by segment/lesson; needs a pipeline change.
- [ ] C — Listen as activity. Needs playback progress, which does not exist yet.

## WATCHING — nightly catch-up

- [ ] Two catch-up gaps remain: 2026-05-31 and 08-14. One per night.

## OPEN — platform expansion

Ranked by his instruction: get it right on the common Apple environment first. tvOS is a player; Windows and Linux are one web reader over the same JSON.

### Phase 1 — iOS and iPadOS

- [ ] At submission, switch visionOS availability on in App Store Connect. Compatible mode; no code.

### Phase 2 — Apple Watch (shape is his)

- [ ] HIS CALL — does the watch show the Daily Lesson as well as the Daily Minute?
- [ ] HIS CALL — whether plain-and-true is what a complication should say.
- [ ] HIS CALL — the wrist shows six lines and offers no way to reach the rest.
- [ ] `.accessoryCircular` and `.accessoryInline` have never been placed; a simulator cannot place them.
- [ ] HIS CALL — the watch app icon at grid size reads as a photograph.
- [ ] No Apple Watch is paired to this Mac; WCSession cannot be exercised unpaired.

### Phase 3 — Apple TV

The TV is a player, and it carries no annotation. Do not re-open either.

- [ ] The companion note still does not scroll. Get Started is focused; the body is a SwiftUI ScrollView of Text, so the reading's onKeyPress path does not reach it.
- [ ] Build the player-first interface. Spec is written at `docs/superpowers/specs/2026-09-05-apple-tv-player-design.md`, awaiting his review; no plan until then.
- [ ] Brand assets: tvOS needs layered parallax icons and a Top Shelf image.
- [ ] The reading column is the iPad's 672pt of 1920pt. Width and type size move together; his eyes decide the pair.

### Phase 4 — Windows and Linux (last)

- [ ] A static reader from acimdailyminute.org over the same bundled JSON, installable as a PWA.
- [ ] It must read and write the same backup `.json`.
- [ ] The rules are ported, never re-invented.

## OPEN — physical-book parity

- [ ] An empty Archive day lists the nearest few days before it that do have a reading.
- [ ] "Let it fall open" — a random published Daily Minute, falling back to a bundled segment.
- [ ] Workbook completion tracking — which lessons the reader has done, distinct from listened.
- [ ] Structure the Manual for Teachers into its question-and-answer form.

## OPEN — content and pipeline

- [ ] Every Workbook introduction is glued to the foot of the lesson before it.
- [ ] `WorkbookIntroductions.json` entry 500 is two paragraphs short.
- [ ] HIS CALL — `Pref.N` names two paragraphs; fixing it changes a citation already printed into exports.
- [ ] Letter-spaced headings still sit inside lesson, Manual, and segment text.
- [ ] Eleven running heads survive inside Chapter 11's prose.
- [ ] A stray space before a closing quote. Measure before writing a rule that removes a character.
- [ ] 186 of 365 lesson bodies are one paragraph; the breaks exist only in the Workbook PDF.

## OPEN — small

- [ ] The archive minute is the last reading that cannot be marked.
- [ ] HIS CALL — the eyebrow cannot hold at accessibility text sizes without wrapping, which changes header height.
- [ ] HIS CALL — `ACIMChime.caf` is duplicated in `assets/` and `Resources/`; copy step or one source.
- [ ] HIS CALL — `prd.json` names the forbidden string inside the rule that forbids it.
- [ ] The Listen tab has no defined behaviour when YouTube fails.
- [ ] No deep-link route for the Listen tab.
- [ ] Today-tab and Archive-tab minute bookmarks do not alias.
- [ ] `lastArchiveFetch` is declared and never used.
- [ ] Pre-submission sweep: walk surfaces that display data they do not have.
