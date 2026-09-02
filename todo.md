# ACIM Daily Minute — open items

> **Role:** open-items ledger — what is open, blocked, or next. · **Status:** authoritative · **Verified:** 2026-09-02
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

## ⏸ PARKED — one consolidated test pass, at the very end

⛔⛔ **DO NOT ASK HIM TO CHECK ANY OF THIS UNTIL EVERYTHING BELOW IS SPEC'D, PLANNED AND
IMPLEMENTED.** His words: "otherwise, I will just repeat myself on things that simply have not been
done yet." This block only grows; it is handed over once, whole, when the build is complete. Keep
adding to it — an unverifiable thing still gets written down — but never surface it as a request.

Everything here is built and on his phone. Verify what can be verified without him first: `swiftc`
harnesses against real data, `./build.sh`, the arm64 device build, install + launch, process-alive
checks, real feed payloads. His eyes are the last resort, not the first.

- [ ] **B4/B5 — Listen rows.** No `01:00` chips anywhere. Tapping an episode leaves a check mark and
      `Listened <date>`; swipe offers "Mark unplayed" and it clears. Lesson rows carry their length under
      the title. An unlistened row shows no date at all.
- [ ] **B6 — Saved tab.** Tapping a saved lesson opens that lesson and a saved minute opens its archive
      day. Swiping either direction deletes. ⚠ Both edges full-swipe, so any horizontal flick removes a
      bookmark — say so if the leading edge should require a tap on Delete instead.
- [ ] **B7 — watched phrases.** The counter reads `1 of 10` immediately after adding a phrase. Then set a
      phrase to a word in today's minute, force-quit, wait past the 60s debounce, relaunch, and confirm
      the notification arrives. Permission is requested at launch, so a reader who leaves the daily
      reminder switched off is still asked — which is what makes a phrase alert reach anyone at all.
- [ ] **Lesson bodies.** Open a lesson the feed has not published yet — anything in 1-80. Expected:
      the full lesson text in flowing paragraphs, with no YouTube frame standing in for missing words.
      All 365 bodies are bundled now. Note that choosing a lesson that *has* a video still opens that
      video full screen first by design; dismissing it lands on the text.
- [ ] **An unrecorded lesson answers the tap.** Tap Lesson 90 — dimmed, with `Available yyyy-MM-dd`
      under its title. Expected: it opens, and above the text a clock line says `Not recorded yet.
      Audio and video available <the same date>`. The two dates must agree.
- [ ] **A day with no Daily Minute says when.** Archive tab, calendar. Pick **2026-09-10** — the row
      under the calendar reads "The Daily Minute for this day will be available on 2026-09-10." and
      tapping through shows the same sentence. Pick **2026-05-31** — "No reading was published on this
      day. Missed days are filled in one a night; expect this one on <tomorrow>." Pick **2026-03-01** —
      "The Daily Minute began on 2026-03-20. There is nothing before it." ⛔ The missed-day date rests
      on the publisher's own rule, one catch-up per night oldest first; if the nightly run ever
      changes that, `MinuteSchedule` is where the app's promise lives.
- [ ] **One notification for a new day, not three.** With New Daily Minute, New Daily Lesson and
      Watched phrases all on, the morning after a publish should bring ONE notification —
      "Today's reading is ready" naming the lesson — not "New Daily Minute" followed by "Lesson N".
      A phrase match rides in the same notification and its tap still opens the phrase editor.
- [ ] **Share on the Mac.** The Share glyph on the Daily Minute, Lesson and Archive cards draws bare,
      like the phone — no bordered well the height of the header beside Save.
- [ ] **The corpus floor.** Airplane mode, delete and reinstall, cold launch. Expected: Today shows a
      complete reading from the bundle with no network, no spinner and no empty state. It is a plain
      card with no save, share or Listen control, because that passage was never published.
- [ ] **Downloads are live now, and nobody has drawn them.** The feeds carry an archive.org
      `audio_url` on every episode that has an MP3 (158 of 165 minutes, all 85 lessons), so the
      Today card's **Listen** control and the Listen row's swipe **Download** are live. Swipe a Listen row: expected **Mark listened** and **Download** side by
      side, then **Remove download** in its place once fetched, and a downloaded row plays from
      disk in airplane mode. ⛔ Look at the swipe at 375pt — the labels are system-drawn and
      collapse to icons when narrow, but no one has seen them do it on this phone. The seven
      March minutes with no recording show no Download, by design.
- [ ] **The companion note.** Settings > About > "A note about using this app". Three places depart
      from the wording he supplied, each to keep it in harmony with the Course, and each is his to
      veto: the prescribed order of study is gone (the Manual says some should read the Manual first,
      some begin with the Workbook, some start with the Text, and the Text's Introduction says free
      will "means only that you may elect what you want to take at a given time"); the Workbook's own
      "do not undertake more than one lesson a day" is stated; and the Workbook Introduction is quoted
      directly rather than paraphrased. Everything else is his wording verbatim.
- [ ] **The privacy policy is reachable now.** `PrivacyPolicyView` existed but nothing linked to it,
      so the one screen stating the app collects nothing could not be opened from inside the app. It
      sits under Settings > About beside the companion note. Confirm it reads correctly there.
- [ ] **Highlights and notes, end to end.** Long-press a passage in any reading; the menu offers
      **Highlight** and **Note** beside the system items. Highlight paints the passage yellow and it
      is still painted after leaving the screen and coming back. **Note** marks the passage and opens
      the editor. **Add note** under a reading writes a note about the whole reading; tapping an
      existing note reopens it for editing. Dictation is the system keyboard's microphone — there is
      no mic button and there must never be one, because `Info.plist` still carries zero
      `UsageDescription` keys and that is load-bearing.

- [ ] **Saved is three segments now** — Saved / Highlights / Notes, still one tab. Confirm each
      empty state reads correctly, both swipe edges delete, a highlight row opens its reading and a
      note row opens its reading. A Text or Manual row will not navigate: no reading UI exists for
      those yet, by design, and the row still shows and still exports.

- [ ] **Export.** The Export item in the Saved toolbar, and the one under each annotated reading,
      hand over plain text. Confirm the file reads as a document a stranger could follow, that it
      carries only the reader's own dates, and that a passage the publisher has since changed is
      marked "passage not found in the current text" rather than dropped. This is the only way a
      reader's words can ever leave the app — there is no server and no account.

- [ ] **Every reading surface now draws through a text view, not `Text`.** This is the one thing
      no harness can settle. Six surfaces changed renderer: the **Today Daily Minute card**, the
      **Today lesson card**, the **Today corpus card** (the offline floor), the **lesson detail
      body**, the **archived-lesson body**, and the **Introduction / lesson body in the archive
      reader**. Confirm on each: the serif body looks unchanged, line spacing is unchanged, the card
      still grows to fit the whole passage with no clipping and no inner scroll, and long-press
      selects text rather than starting a drag. On macOS the body is 13pt by design — that matches
      what `Text` did there before, so it is not a regression.
      A harness already proves the *string* is character-for-character what it was, for all 365
      lesson bodies, 1,983 corpus segments and 268 Text sections. Only the drawing is unverified.
      ⛔ On macOS the drawing is held by `tools/verify_text_measurement.sh` and has been compared
      against your screenshots; the phone is what is left to check.

- [ ] **The date sweep.** Publication dates are gone from Today, Lessons, lesson detail, Listen and all
      three widget sizes, and the privacy policy no longer carries a revision year. Confirm nothing dated
      survives where he can see it.

- [ ] **The Text is readable, and tab 1 is now Read.** It carries two segments, **Workbook** and
      **Text**. The Text opens on a table of contents — Preface, then Chapters 1-31 — then the
      sections of a chapter, then the reading. Confirm the Workbook still lands exactly where it
      did and still scrolls to the current lesson; that a widget or notification tap on a lesson
      still opens that lesson and never a chapter list; and that "After Lesson 365, the Text
      begins." switches to the Text.

- [ ] **The recovered paragraphing.** The Text arrived as raw page scans: paragraphs marked by
      indentation, blank lines that were page breaks, and 351 running heads and page numbers sitting
      inside sentences. It is recovered into 2,911 paragraphs at export, verified to break no
      sentence. Whether it reads correctly to someone who knows the book is his call. Chapter 1's
      "Principles of Miracles" is the section to check first — it should be 53 numbered paragraphs,
      1 through 53, with nothing between them.

- [ ] **The longest section on the phone.** Chapter 1.2 is 37,222 characters in one non-scrolling
      text view. Every other section is a fifth of that or less. Confirm it scrolls without stutter.

- [ ] **Reading straight through.** Previous and Next at the foot of a section cross chapter
      boundaries by design. Confirm the last section of a chapter leads into the next chapter's
      first, and that the first section of the Preface offers no Previous.

- [ ] **Annotation in the Text.** Highlight and Note work in a Text section exactly as in a lesson,
      and the Saved tab's Highlights and Notes rows now open the passage instead of sitting inert.
      A saved Text section shows as "Chapter N" with its section title. A Manual row still will not
      navigate, by design.

- [ ] **The spacing repair.** 6,221 missing spaces are back across all five bundled files —
      `their Source,Which is` now reads `their Source, Which is`. Confirm a repaired passage reads as
      the book does, and that nothing was joined that should not have been. Chapter 1's "Principles
      of Miracles" and any lesson body are the quickest look. The rule inserts a space and never
      removes or changes a character, so no word the publisher narrated has moved; what his eyes
      settle is whether the result reads right. Feed text and the widget are repaired at render, so
      today's minute on the phone and on the lock screen should both be clean.

- [ ] **The two Part Introductions.** "Part 1 Introduction" appears above Lesson 1 and "Part 2
      Introduction" between Lesson 180 and Lesson 181. Both read, annotate and save. Their titles
      come from the corpus rather than from literals, so the row and the screen cannot disagree.

- [ ] **Citations.** Four surfaces now name a place in the book instead of the pipeline's own
      name for the source PDF (`github_push.py:402` writes `source_pdf` straight through, so a
      reader saw `Text Part A`). The Today Daily
      Minute card shows the stem `T-5.3`; the offline corpus card shows the full `T-5.3.7`; a
      Text section carries its stem beside the chapter title; and share text and the
      plain-text export carry the full citation, with the export naming the edition in its
      header. A Saved row and an export heading read `Text, Chapter 5 — The Mind of the
      Atonement (T-5.3)`.
      ⛔ **These are NOT the citations of the widely-cited edition, deliberately.** Ours is a
      different book, and that is measured: our Chapter 1 is "INTRODUCTION TO MIRACLES" with
      **53** numbered miracle principles rather than 50, and a chapter's Introduction occupies
      section 1. Arabic section numbers (`T-5.3.7`, never `T-5.III.7`) are the signal. Emitting
      the familiar form would have pointed a reader holding the other edition at the wrong
      words, permanently, in an export meant to outlive the app. **This is the one judgement
      here that is yours to overturn.**
      There is no sentence number: two defensible splitters disagree on 644 of 3,564
      paragraphs, so a `:1` would be a number this app invented.
      ⛔ **The Archive card is the exception — it shows a book name, not an address**, so
      `Text` rather than `Text Part A`. An archived row carries no segment id, because the
      feed's inline archive entries have none. Resolving it by matching the passage's text at
      runtime was rejected: the locator belongs at export, and keying a row by its content is
      the bug this project keeps rediscovering. Giving the Archive a real citation means
      adding `segment_id` to the pipeline's archive entries first.
      118 of 1,983 passages carry no citation and show their book name instead: all 105 Manual
      segments, plus 13 that did not resolve uniquely. Nothing is guessed.

- [ ] **The two Workbook Part Introductions name themselves from the corpus.** They are keyed
      `.lesson(0)` and `.lesson(500)`, which made every Saved row and export heading call them
      "Lesson 0" and "Lesson 500". Confirm both read correctly in Saved and in an export.

- [ ] **The Text's missing chapter openings are back.** About 12,000 characters that were
      never in the bundle: nine chapter openings and the publisher's front matter. The
      extractor cut each chapter at its first *section* heading and dropped the opening prose
      glued to the wrapped chapter title. Recovered at export from the segments, which are a
      continuous cut of the same PDFs — nothing re-extracted, nothing read from a PDF, nothing
      written to the database. **272 sections now, not 268.**
      ⛔ **Addresses moved in three chapters, permanently.** Chapters 13, 16 and 20 had no
      Introduction at all, so the recovered opening became section 1 and everything after it
      shifted: **today's `T-16.1 True Empathy` is `T-16.2`.** That matches the 28 chapters
      where the Introduction already was section 1. It was safe to do only because nothing has
      shipped and the annotation store was empty — 0 highlights, 0 notes, 0 bookmarks, verified
      before the change and again after. The same move made later would strand real marks.
      Confirm the four recovered openings read correctly, and that Chapter 16 now opens on
      `To empathize does not mean to join in SUFFERING` rather than on `True Empathy`.

- [ ] **The card header, now that a play control is on it every day.** Two bands on every card and
      every screen size: the title centred on its own line, then **Listen on the leading edge, Share
      and Save on the trailing edge**. Check the Daily Minute card, a Lesson card and an Archive
      card. Expected: no `DAILY / MINUTE` split and no `Lis-`/`ten` hyphen anywhere; Share and Save
      in the same place on a passage that has audio and one that does not; and **tap Save** —
      `Saved` is wider than `Save`, so that tap is the one that can shift the layout under your
      finger. ⛔ Most readings have no audio, so the usual state is the control band holding only
      Share and Save. `tools/verify_card_header.sh` proves the words never break and the two
      controls never move; whether the two-band arrangement reads well is yours.

- [ ] **Saving a passage, twice.** Tap Save on any reading, leave the screen, come back, tap Save
      again. Expected: it saves, then un-saves, every time. Every write now decides against a fetch
      rather than the view's own `@Query` snapshot, which is what makes a row written by the watch or
      by an import in the same tick visible to it. ⛔ There is no unique index behind this any more —
      `BookmarkStore` is the whole guarantee. The rule is proved by 381 cases in
      `tools/verify_bookmark_identity.sh`; only the tap needs a hand.

- [ ] **Backup & Restore, end to end.** Settings > Your Work > Backup & Restore. **Save a backup**
      should open a real Save dialog on the Mac and the Files sheet on the phone, and produce
      `ACIM Daily Minute backup <date>.json`. Open that file in any text editor: it should read as a
      document — the edition named at the top, then every mark with the passage it belongs to, its
      address in the book, and the words. Confirm it makes sense to someone who has never run the
      app, because that is the whole point of the format.

- [ ] **Restoring merges rather than duplicates.** Make a highlight and a note on the Mac, back up,
      restore that file on the phone, and confirm both arrive once. Restore the SAME file a second
      time and confirm nothing is added and the summary says so. Then edit the same note differently
      on both machines, back up from one, restore onto the other, and confirm the note holds **both**
      versions with the separator line between them rather than only the newer one. Nothing anywhere
      can re-send a reader what they wrote, so this is the behaviour that matters most.

- [ ] **The import summary reads the way you want it to.** After a restore it reports what was
      added, how many notes were written in two places, and that nothing was removed. Say if the
      wording is wrong — it is the only thing telling a reader what just happened to their work.

- [ ] **The companion note now closes the introduction.** Launch fresh (or Settings > Onboarding >
      **Replay introduction**) and page through to the end. Expected: the last carousel page's button
      now reads **Continue** rather than Get Started; tapping it shows "A Note About Using ACIM Daily
      Minute" in full, scrollable, on the introduction's black ground; and its **Get Started** button
      is what finally dismisses the introduction. Confirm the same note still reads correctly under
      Settings > About, because both screens render one view and the words exist in only one place.
      ⛔ Check it at 375pt: the note is long and it is the first thing a new reader meets.

- [ ] **Saving, then deleting from the Saved tab.** Tap Save on a reading, leave, come back,
      tap again — it must save then un-save, every time. Then delete a saved row from the Saved tab by
      swiping. Nothing in the database prevents duplicate bookmarks any more; `BookmarkStore` does, and
      the Saved tab's delete was rerouted through it in this change. 381 cases hold the rule, but the
      tap needs a hand.

- [ ] **Your highlights and notes survived the store split.** The app now keeps the reader's work in
      `reader.store` and the feed caches in `cache.store`, and lifts the old rows across once on first
      launch. Proved on the Mac against real data — 2 highlights and 2 notes moved, the old file kept
      its copy, and a second launch added nothing — but the phone's own store has only ever been
      migrated by the phone. Open Saved and confirm every highlight and note is still there, and that
      the Archive tab refilled itself.

- [ ] **iCloud sync, the part no harness can reach: two devices.** Settings > Your Work > **Sync with
      iCloud**, on the Mac and on the phone, then reopen each — the switch deliberately takes effect at
      next launch, and the footer says so. Expected: a highlight made on one appears on the other, and
      **deleting one on either device removes it from both** — that is the real difference from a file
      restore, which only ever adds. ⛔ Proved so far only on the Mac alone: the container builds, 4
      records reached iCloud, and off → on → off leaves the work intact. Device-to-device is yours.
      ⛔ Expect one `badContainer` failure on a device's very first sync; the next launch fixes it.
- [ ] **The privacy policy now describes iCloud, and three of its claims changed.** Settings > About >
      Privacy Policy. Read it against what the app now does: "never leaves your device" and "no data is
      sent to any server" and "no push notification server is used" were all falsified by CloudKit and
      were rewritten in the same change. There is a new **iCloud Sync** section. The App Store label
      stays "Data Not Collected". ⛔ This is the one screen in the app where a wrong sentence is a
      promise broken rather than a bug, so it is worth reading as a whole rather than skimmed.
- [ ] ⛔ **Before any release build: deploy the CloudKit schema from Development to Production** in the
      CloudKit Dashboard. Debug builds use Development; TestFlight and the App Store use Production, and
      no amount of local testing detects the gap. This is a release-gate step, not a test.
- [ ] **A folder of your own, end to end.** Settings > Your Work > Backup & Restore > **Keep a copy
      in a folder** > Choose a folder… Pick a Dropbox or iCloud Drive folder on the Mac. Expected:
      `ACIM Daily Minute backup (<this Mac's name>).json` appears in it at once and the screen shows
      the folder and "Last written". Then make a highlight and wait three seconds — the file's
      modification time moves; make one and immediately put the app in the background — it still
      moves. On the phone, choose the same folder through Files: its file is named `(iPhone)`, so
      the two devices never overwrite each other. Rename the folder in Finder and tap **Write now**
      — it must still land, since the bookmark follows the folder. Delete the folder and tap Write
      now — expected the red sentence "The folder can no longer be found. Choose it again." and
      nothing else changes. ⛔ Nothing is ever read from that folder: bringing the phone's file onto
      the Mac is still **Restore from a file…** by hand, and that is the design, not a gap. The
      Mac's `Host` name is what it is called on that machine; the phone says `iPhone` because iOS
      stopped giving apps the reader's own device name.

## ⏸ PAUSED — the standardized reading layout (design, not started)

He asked to standardize how the Text, Lessons and Manual are presented, then had to leave. **Nothing
is written down as a spec yet and no code exists.** The decisions he made are worth keeping:

- **One scaffold, three bands, for every reading surface:** header (`LABEL` + play + Save + Share) →
  title → body → `Add note` / Export → footer (citation + word count). Controls above, the reader's
  response below, the reading itself untouched between them.
- **`Add note` stays at the bottom.** His call, and it belongs with the citation, not the actions.
- **Save moves out of the nav toolbar into the header row on pushed screens**, so all surfaces are
  identical rather than each being locally idiomatic.
- **One play control, audio-first.** Tap plays narration and the reader keeps reading; video is
  deliberate (long-press / menu), because video takes the screen and is the most perishable tier.
  It sits leftmost so Save and Share never shift position between passages.
- **The tab bar becomes Today | Read | Listen | Video | Saved.** `Archive` becomes `Video` — all 158
  published entries already carry a `youtube_id`, so it is a recast rather than a build, and it
  retires the last exemption to the no-publication-dates rule. Label items by citation, not date.
- **Listen becomes activity, not a catalogue** — now playing, part-finished, downloaded, finished.
  The Course stays organized exactly once, in Read.

**The work decomposes into five pieces, in this order: A → D → E → B → C.**
- **A — the scaffold** across the five surfaces that already exist. App-only, no new data. Next.
- **D — Archive → Video.** App-only; the data exists today.
- **E — structure the Manual.** ⛔ **The Manual is NOT free.** Its 105 bundled rows are arbitrary
  ~1,300-character word-count cuts that begin mid-thought, with no titles and `citation: nil`. Its
  real Introduction / 29 questions / Clarification of Terms exist only in `4_ACIM_Manual.pdf`, so it
  needs a structure layer built at export, the way the Text's 272 sections were. Annotations key on
  `manual:<segmentId>`, **not** a section address, so structuring it cannot move a reader's marks —
  unlike the Text renumber that made `T-16.1` into `T-16.2`.
- **B — media index + inline play control.** The only piece needing a pipeline change. Availability
  must be a feed-driven overlay keyed by `segment:<id>` / `lesson:<n>` — never bundled (stale the
  next day), never computed from a filename.
- **C — Listen as activity.** Needs playback progress, which does not exist yet.

⛔ **Audio and video are produced about one a day: ~1.5 years for the 365 lessons, ~7 years for the
1,983 minute segments.** So **most readings will have no media for the life of this app.** Absence is
the normal state: the play control is absent entirely rather than greyed out, and nothing shifts
position when one does appear.

## ▶ NEXT — corpus-wide search

The book's index. Search that reaches the whole bundled corpus, not just the rolling
archive window. Spec first, then plan, then execute.

**What exists today, verified rather than assumed:**

- **Search exists in three places and none of them searches a body.** `ArchiveView` filters
  `ArchivedReading.searchableText` through a SwiftData `#Predicate` with
  `localizedStandardContains` — the rolling archive window only. `LessonsView` matches a
  lesson number or title. `TextChaptersView` matches chapter and section titles.
- **The corpus a real search must cover is 5,137,927 characters over 2,727 records**:
  272 Text sections (1.64M), 365 lesson bodies (799K), 1,983 segments (2.55M), 105 Manual
  segments (137K), 2 Part Introductions (7K). All already in memory through `CorpusService`.
- **Every hit now has an address to show.** `CitationResolver.citation(for:characterOffset:)`
  turns a match position into `T-5.3.7`, so a result can name where it is.

**The questions the spec has to answer:**

1. **Segments overlap the Text and the Workbook.** The same passage is bundled twice — once
   as a Text section and once as a word-count cut. Searching both returns it twice. Does
   search cover the readable corpus (Text, lessons, Manual) and leave segments out, or
   deduplicate by citation?
2. **Raw body or display string?** Only `ReadingText.displayString` matches what the reader
   sees and what a highlight offset counts. Searching raw bodies would return offsets that
   point at nothing drawable.
3. **What is a result?** A citation plus a snippet, presumably — but a snippet has to be cut
   without breaking a grapheme, and the offset has to survive the jump into the reading.
4. **Where does it live?** A fourth `.searchable` surface, or one search that replaces the
   three narrow ones. The three disagree about what a query means today.

⛔ Same standing rules: never re-extract the corpus, never write to the pipeline database,
and whatever is added must survive the app.

## ▶ WATCHING — the nightly catch-up

The feeds carry the archive.org URLs now: `daily-minute.json` on 157 of 164 archive entries plus
today, `daily-lesson.json` on all 84 plus today, `podcast-minute.xml` 158 enclosures of 165 items,
`podcast-lessons.xml` 85 of 85. All 243 recorded MP3 URLs answer a ranged GET. The seven minutes
without one are 2026-03-20 … 03-26, which have no recording at all.

- [ ] Two catch-up gaps remain: **2026-05-31 and 08-14** — the two dates missing from the archive
      list between 03-20 and today. One per night by design (`CATCH_UP_MAX_PER_RUN = 1`); two
      nights to clear. Read it off the feed's archive dates; `./catchup.sh list` on MacLive says the
      same, when that machine is mounted.

## ▶ OPEN — platform expansion

Ranked by his instruction, and the ranking is a resource decision, not a design one: get it right on
the common Apple environment first, then expand. Do not let a non-Apple consideration shape an
Apple-platform design.

- [ ] **Apple TV (tvOS)** — a target he wants; **no tvOS target exists in the Xcode project yet**, so
      there is nothing to run and the simulator is not the blocker. Four tvOS runtimes are already
      installed (18.2, 18.4, 26.2, 26.5) with Apple TV 4K (3rd gen) devices ready, e.g.
      `FE7B1792-F47B-4271-AB54-8081D162EC55` on tvOS 26.2. The bundled corpus makes tvOS far more
      tractable: a TV has no paired phone to lean on, so it needs content that stands alone.
      ⛔ Real design work before any code: tvOS is a focus-engine, 10-foot, no-touch UI, and reading
      long passages on a television is a genuine question, not a port. It also has no `WCSession` and
      no home-screen widgets — Top Shelf is the nearest equivalent.
- [ ] **Windows**, then **Linux** — explicitly LAST. Nothing is to start here while any Apple
      platform is unfinished.
- ⛔ **`./build.sh` builds macOS with `CODE_SIGNING_ALLOWED=NO`**, so that binary carries no
      entitlements, cannot open the App Group, and its widget is invisible to the system. Testing
      the macOS widget needs a signed build:
      `xcodebuild -scheme ACIMDailyMinute -configuration Debug -destination "platform=macOS" -allowProvisioningUpdates DEVELOPMENT_TEAM=RR5DY39W4Q build`,
      then copy the app to `/Applications` and launch it once. Confirm with
      `pluginkit -mAv -p com.apple.widgetkit-extension | grep -i acim`.

## ▶ OPEN — physical-book parity gaps

What a physical *A Course in Miracles* gives a reader that this app does not. Ranked by how much each
blocks "this replaces my book". The content is now bundled and reachable through `CorpusService` —
1,983 segments, 268 Text sections, 105 Manual segments, 365 lesson bodies. These are what turn it into
a book.

- [ ] ⛔ **Search across the whole corpus** — promoted to the `▶ NEXT` block above.
- [ ] **Cross-reference links** — the Course refers to itself constantly; a citation should be
      tappable. Unblocked: `Citation(rawValue:)` parses an address back to a `ReadingKey` the app
      already navigates, so this is a view change and not a format change.
- [ ] **Resume where you stopped** — the ribbon. Unblocked now that the Text is readable, and it is
      what a 669-page book needs most: `ReadingKey.textSection` already names the place. There is no
      reading position anywhere in the app today — no `@SceneStorage`, no scroll offset. When one
      exists it is one more key in the backup file; older versions ignore what they do not
      recognise, and nothing is written as a placeholder for it now.
- [ ] **"Let it fall open"** — a random passage. A real practice with the physical book, nearly free once
      the corpus is bundled.
- [ ] **Workbook completion tracking** — which lessons the reader has *done*, distinct from listened.
- [ ] **Structure the Manual for Teachers** into its question-and-answer form. It is bundled as 105
      unstructured segments by decision; a searchable unstructured Manual beats no Manual.

## ▶ OPEN — content and pipeline

- [ ] ⛔ **Letter-spaced headings are still sitting inside reader-facing text.** Found while
      recovering the Text's chapter openings, and deliberately **not fixed** there — it is a
      different defect, in different files, with different decisions to make.
      The page sets some headings letter-spaced (`w h o a r e g o d ’s t e a c h e r s ?`), and
      they survive inline, glued to the front of the prose that follows them:
      **20 runs in 13 lesson bodies, 62 runs in 24 Manual records, 152 runs in 92 segments.**
      The Text is clean and now has a committed guard (`letter_spaced_headings` in
      `text_paragraphs.py`) that keeps it that way; the other three files have no such guard
      because they would fail it today.
      The open question is what a heading should BECOME — its own paragraph, a section title, or
      nothing — and for the Manual that is entangled with giving it a structure to browse at all.

- [ ] **Eleven running heads survive inside Chapter 11's prose.** `and you will not perceive God’s
      answer 11 GOD’S PLAN FOR SALVATION to YOU.` — in sections 11.2 through 11.10. The recovery in
      `tools/text_paragraphs.py` drops page furniture line by line, and these eleven landed *mid-line*
      where the line test cannot see them. Found while measuring the spacing repair; left alone
      deliberately, because a mid-line rule cuts into the delicate paragraph recovery and deserves
      its own measurement. Reproduce with
      `(?<=[a-z] )\d{1,3} [A-Z][A-Z’ ]{8,}(?= [a-z])` over `ACIMTextSections.json`.
- [ ] **A stray space before a closing quote.** `and He will abide with you. "The Holy Spirit` — the
      mirror of the spacing defect, far rarer. A rule that *removes* a character is more dangerous
      than one that inserts one, so it was left out of the repair rather than guessed at. Measure it
      before writing a rule.
- [ ] **186 of 365 lesson bodies are one paragraph.** Not a rendering bug — those 186 carry no blank
      line in `lessons.text` at all, so there is nothing in the row to split on. Unlike the spacing
      repair, this one **does** need the PDFs: the paragraph breaks exist only in the page layout of
      `/Users/larryseyer/Dropbox/ACIM PDF/3_ACIM_Workbook.pdf`, exactly as the Text's did. Read the
      PDF to find where paragraphs break and apply the breaks to the existing row — never replace the
      row's text with PDF text, which would reintroduce the page furniture and change words the
      publisher has already narrated. The spacing repair fixed the words *within* a paragraph; this
      is the paragraph boundaries themselves, and it is its own scope call.

## ▶ OPEN — how each Apple platform actually gets exercised

Both simulators he asked about are **already installed on this Mac**; neither is the obstacle.

- [ ] **watchOS — the sim proves compilation, not the sync.** `./build.sh` builds against
      "Apple Watch Series 10 (46mm)" (`32AC5279-DC44-4404-9F4B-53D3FEEB7AE8`), and there are two sims
      by that name across runtimes, so resolve by UUID rather than name. ⛔ **Neither Series 10 sim is
      paired with any iPhone sim**, and `WCSession` — the one-way phone-to-watch sync this app depends
      on — cannot activate unpaired. Xcode's auto-created pairs are all watchOS 26.5 (Series 11 46mm
      `D876968B…` with iPhone 17 Pro Max `CE9761A7…`, and others). Exercising the sync means running
      the watch app on a *paired* pair, booting **both** halves, and installing the iOS app on the
      phone half — or using his real Apple Watch, where the watch app installs through the paired
      iPhone. `xcrun simctl list pairs` shows the current pairs; `simctl pair` makes one.
- [ ] **tvOS** — nothing to run until a tvOS target exists. See platform expansion above.
- [ ] **macOS** — needs the signed build, not `./build.sh`. See platform expansion above.

## ▶ OPEN — small, unscheduled

- [ ] **`ACIMChime.caf` is duplicated and nothing syncs it.** `assets/ACIMChime.caf` is the source;
      `ACIMDailyMinute/Resources/ACIMChime.caf` is what the app bundles and the only one
      `NotificationManager.swift:128` can see. Updating `assets/` alone ships the old sound with a
      fully green build. It has already been missed twice. Two ways to end it, his call: add a copy
      step to `./build.sh`, or delete the `assets/` copy and make `Resources/` the single source.

- [ ] **`prd.json` names the forbidden string inside the rule that forbids it.** Ten lines across
      `prd.json` and `bash/archive/.../prd.json` contain the literal the absolute-clean rule bans, as
      part of the rule text itself. Pre-existing, and a self-reference rather than a leak, but it
      means a plain repo-wide grep can never come back empty. His call: reword the rule to describe
      the string without spelling it, or accept those lines as the one exemption.

- [ ] **The Listen tab has no defined behaviour when YouTube fails.** `LiteYouTubeCard` needs a
      `WKNavigationDelegate` failure path so a dead video source degrades to what it has rather than a
      dead frame. It belongs with Listen work rather than corpus work, which is why the corpus
      tasks left it standing.
- [ ] **No deep-link route for the Listen tab.** `DeepLinkRoute` covers today / lesson / archive / saved.
      Not a defect, but it makes that tab unverifiable without hand-tapping.
- [ ] **Today-tab and Archive-tab minute bookmarks do not alias.** Today keys on `DailyMinute.segmentHash`,
      Archive on `ArchivedReading.lineHash`, so the same passage saved from both places lands twice.
      Documented in `ArchivedReadingCard.swift`.
- [ ] **Three defaults keys are dead.** `useCustomNotificationSound` is registered at
      `App/ACIMDailyMinuteApp.swift:92` and never read anywhere; `phraseMatchBadge` is written at
      `Services/BackgroundRefreshManager.swift:174` and never read; `lastArchiveFetch` is declared at
      `Services/FetchCooldown.swift:44` and never used. Found while deciding what a backup carries.
      None of them travels.

- [ ] **Pre-submission sweep.** Walk Archive, Saved, Lessons, deep links, widget and watch for surfaces
      that display data they do not have. No `TODO`/`FIXME`/stub copy remains in any view, widget or watch
      source, so what is left is behavioural empty-state handling — an interactive pass on the device.
