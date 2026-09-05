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

- [ ] **Light on the phone, and the reminders — what no harness can see.** Settings > Appearance >
      **Light** on the phone at 375pt: every card, chip and gold word reads on the white ground, the
      number badge on the Read list is legible, the introduction stays on its black ground by
      design, and the five cards' line breaks land where he set them without a stray wrap. Then
      Settings > Practice reminders > **Follow the lesson's practice**, with the day set to bracket
      the next hour: the **Today** row names the lesson and its cadence, and one reminder arrives
      on the phone at that hour — and on the watch, mirrored — naming the lesson, and its tap opens
      that lesson. The Daily Minute and Daily Lesson reminders each fire at their own time; a tap on
      the first opens Today and on the second the Read tab. Nothing arrives during a Focus.
- [ ] **B4/B5 — Listen rows.** No `01:00` chips anywhere. Tapping an episode leaves a check mark and
      `Listened <date>`; swipe offers "Mark unplayed" and it clears. Lesson rows carry their length under
      the title. An unlistened row shows no date at all.
- [ ] **B6 — Saved tab.** Tapping a saved lesson opens that lesson and a saved minute opens **the
      passage itself** — see the Saved-tap item below. Swiping either direction deletes. ⚠ Both edges
      full-swipe, so any horizontal flick removes a bookmark — say so if the leading edge should
      require a tap on Delete instead.

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
- [ ] **A reading should scroll to its place on macOS too.** Today it opens at the top there, on
      purpose: an `NSTextView` asked to bring a line into view moves its own bounds inside its frame
      and draws the body over its own title. The scroll has to come from the SwiftUI side, where the
      `ScrollView` itself can be told — SwiftUI has no scroll-to-offset, so it means the representable
      reporting the target's y and the screen driving a `ScrollViewReader` against an anchor. It
      costs macOS a convenience and nothing else: the right passage opens, the spotlight still paints.
      ⛔ The same rule governs a search hit, so both move together.

- [ ] **The ribbon, on the phone.** Read tab > Text. Open a section, scroll a screen or two in,
      leave it. Expected: `Continue reading` above the chapter list naming that section, and
      tapping it puts the passage you stopped at back at the top of the screen. The same for a
      Workbook lesson. ⛔ **The reading is the durable part and the offset is the refinement**: if
      the sample ever fails the row still names the right reading and opens it at its top, which
      is what the app did before there was a ribbon — so what to watch for is a row naming the
      *wrong* reading, not a scroll that lands high.
      It runs correctly end to end on the Mac; nobody has seen it at 375pt.
- [ ] **A search hit two screens down.** Search the Course, then open a hit that is deep in a long
      Text section rather than near its start. Expected: the blue words are on screen when it
      opens. They were not before — TextKit 2 lays out only what is visible, so the rectangle for a
      passage below the fold came back empty and the scroll silently did nothing.
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
      records reached iCloud, and off → on → off leaves the work intact. **Mac → phone carries a
      highlight.** What is left is the return trip, and the deletion: make a mark on the *phone* and
      confirm it reaches the Mac, then **delete one on either device and confirm it goes from both** —
      that is the real difference from a file restore, which only ever adds.
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

- [ ] **Search, the book's index.** Read tab, the one search field, prompt "Search the Course".
      Type `holy instant`: a Headings group if any title matches, then every occurrence in book
      order under its section, lesson or Manual heading, each row a snippet with the match in bold
      and its address (`T-15.1.3`, `W-45.2`) beneath. Tap a Text hit, a lesson hit, an Introduction
      hit and a Manual hit: each opens with the matched words tinted blue and scrolled into view.
      A lesson opened this way does NOT open its video first. Type `45`: Lesson 45 leads the
      Headings group. Type `the`: the list ends with "Showing the first 1,000 matches." Type
      `God's` with a straight apostrophe: it finds the Course's `God’s`. Then clear the field: the
      Workbook and Text shelves are exactly as they were, and the Text's chapter list no longer has
      a search field of its own. The Jump button is absent while a query is typed, by design —
      typing the number is the jump.
      ⛔ Check the spotlight scroll at 375pt on a long section (Chapter 1.2): the scroll happens
      once, on arrival, and never fights the reader afterwards. The tint is `systemBlue` at 0.22 —
      chosen because the app's accent is gold and a highlight is yellow; if it reads wrong on the
      dark ground, `SelectableReadingText.spotlightColor` is the one place it lives.
      ⛔ At your Dynamic Type (about xxLarge) a snippet row is capped at three lines, and a long
      `…before` fragment can push the bolded match itself off the row. Search `forgiveness`, look
      at the rows: if the bold words are clipped anywhere, that cap is the thing to change. A
      single letter typed shows an empty list, not "No Results", by design; a single digit is a
      lesson number and shows that lesson.
- [ ] **The Manual opens now.** A Manual highlight, note or saved row in Saved opens its passage on
      a screen titled Manual, with Save in the toolbar and annotation working. No Previous or Next,
      no contents, by design — structuring the Manual is its own item.
- [ ] **Cross-reference links.** Open a review lesson — 84 is today's, or any of 51-60, 81-90,
      111-120, 141-150, 171-180, 201-220 — and the bracketed numbers, `[67]`, draw in the accent
      colour. Tap one: Lesson 67 opens to read, with NO video first, and Back returns to the
      review. A long press on the number shows no link preview. Highlight across one and the
      yellow paints behind it while it stays tappable. Then Today: the Daily Minute's footer
      (`T-5.3.7`, `W-45.2`) is in the accent colour; tap it and the Text section or lesson opens
      with that whole paragraph tinted blue and scrolled into view, Back returns to Today, and the
      tab has not changed. A `Pref.N` footer opens the Preface at its head with nothing painted,
      by design. The offline corpus card's footer does the same. On the Mac all of it is a click.
      ⛔ Check `[67]` at 375pt and xxLarge: the tint must not make the number look like a button
      the words around it are not.
- [ ] **One reading shape everywhere.** Open a lesson from the Read list, a Text section, the
      Workbook Introduction, a Manual passage, the Today cards and an Archive day. On every one:
      the eyebrow is centred above the controls, the play control is on the leading edge when it
      exists at all, and **Share and Save are together on the trailing edge and in the same place
      on all of them**. Save must be gone from the nav bar on all four pushed screens. The nav bar
      now names the BOOK — Text, Workbook, Manual for Teachers — and the eyebrow names the place.
      A Text section shows its chapter title above its section title, and its address at the foot
      where it is printed but not tappable; the Today footers stay tappable. Read time reads
      sensibly at both ends: Lesson 1 says "less than a minute", the longest Text section says
      "about 29 min", and no reading anywhere says "about 0 min". The Introduction and the Manual
      offer Share for the first time.
      ⛔ Check the eyebrow at 375pt and xxLarge on every screen — `WORKBOOK FOR STUDENTS` is the
      longest string and the band breaks its words rather than wrapping.

- [ ] **Two calls on the Daily Minute passage screen — the one a Saved row opens.**
      1. **It offers Share and NOT Save.** A minute saved from Today keys one way and the same
         minute saved from the Archive keys another — two addresses for one passage already — and a
         Save there would make a third. Say the word if you want it anyway and the third key gets
         designed properly first.
      2. **Its address at the foot — `W-290.3` — is tappable**, and it is the only pushed reading
         where that is true. Everywhere else the address names the passage already on screen and a
         link there would teach you links are broken; here it names where the passage begins in the
         book, with the pages around it. ⛔ **No eye has seen this tap** — check it lands in the
         Workbook at that paragraph and that Back returns you to the passage.

## ⏸ PAUSED — the standardized reading layout (piece A built; D is next)

Piece A, the scaffold, is built: `Views/ReadingScaffold.swift` owns the band order and all ten render
sites pass slots. Spec and plan:
`docs/superpowers/specs/2026-09-02-standardized-reading-layout-design.md` and
`docs/superpowers/plans/2026-09-02-standardized-reading-layout.md`. The four remaining pieces are
below, and these decisions of his govern them:

- **`Add note` stays at the bottom.** His call, and it belongs with the citation, not the actions.
- **One play control, audio-first.** Tap plays narration and the reader keeps reading; video is
  deliberate (long-press / menu), because video takes the screen and is the most perishable tier.
  It sits leftmost so Save and Share never shift position between passages.
- **The tab bar becomes Today | Read | Listen | Video | Saved.** `Archive` becomes `Video` — all 158
  published entries already carry a `youtube_id`, so it is a recast rather than a build, and it
  retires the last exemption to the no-publication-dates rule. Label items by citation, not date.
- **Listen becomes activity, not a catalogue** — now playing, part-finished, downloaded, finished.
  The Course stays organized exactly once, in Read.

**Four pieces remain, in this order: D → E → B → C.**
- **D — Archive → Video.** App-only; the data exists today. **Next.**
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
Apple-platform design. Two of his calls are already made: **tvOS is a player — listen and watch
first, reading secondary**, and **Windows and Linux are reached by one web reader over the same
JSON**, not by porting Swift.

⛔ **The durability rule decides more of this than any platform API.** The app must be wholly usable
on bundled content alone. That is what makes tvOS tractable and it is what the watch fails today.

### Phase 1 — iOS and iPadOS certification, first

⛔ **Do NOT add SE / Pro Max / iPad Pro simulator legs to `build.sh`.** It was measured:
`xcodebuild -showBuildSettings` is byte-identical across simulator device models — same `ARCHS`,
same `SDK_NAME`, same deployment target, same device family. A simulator destination's device model
never reaches the compiler, so those legs would compile the same binary three more times and catch
nothing. The layout regression net is `tools/verify_card_header_dynamic_type.sh`, which measures
real iOS metrics; the only compile that genuinely differs is the arm64 `iphoneos` device build,
which `both.sh` already drives. ⛔ There are still **zero test targets** — the shared scheme's
`TestAction` has no testables, so `xcodebuild test` tests nothing. The eighteen `swiftc`/`simctl`
harnesses are the suite.

- [ ] **Prove the settled padding at a real Slide Over width.** Every `ScrollView` screen edge is
      20pt now and the `List`-based surfaces keep system row insets, which are not comparable and
      were deliberately left alone. What has not been seen is an iPad running a compact slice, where
      `ReadableContentWidth` stops clamping by design. Needs an iPad simulator or his iPad — ⛔ not
      the iPad sim `58B7D31D-…`, which he has asked not be driven.
- [ ] ⛔ **At submission, switch visionOS availability on in App Store Connect.** The app already
      qualifies for "Designed for iPad" on Vision Pro unchanged: device family `1,2`, all four iPad
      orientations, and no `UIRequiredDeviceCapabilities`. It is an availability toggle on the
      existing iPad build and needs no code, no target and no build setting.
      ⛔ **It is NOT done by lifting `SUPPORTED_PLATFORMS`, and that claim was wrong.** Measured on a
      visionOS 26.5 simulator: `os(iOS)` is **false** there, `os(visionOS)` is true, and
      `canImport(AppKit)` is **false**. The app's 48 `#if os(iOS)` sites pair with `#elseif
      os(macOS)`, so visionOS falls through both branches and `PlatformFont`, `PlatformColor`,
      `TextViewRepresentable`, `MacBottomTabBar` and `pageChevron` are all undefined. A **native**
      visionOS target is the same porting job tvOS is — see Phase 3 — and belongs beside it, not
      here.

### Phase 2 — Apple Watch, which is a build and not a fix ⭐ NEXT

⭐ **He has cued this one: it is what to pick up next.**

⛔ **The watch does not work today, and the first item is why nothing else about it matters.**
It already compiles — `build.sh` has driven a watch leg all along — so a green build says nothing
here. The gap is that the app cannot reach a wrist, carries none of the corpus, and has no
complication target. ⛔ Do not read the passing build leg as progress on any of that.

⛔ **The tvOS port just established the pattern this phase should follow**, and it is worth reusing:
drive `swiftc -typecheck` against the platform SDK over the whole source list, fix what it names, and
only then touch the project. It found the real surface in minutes and proved this file's estimate for
tvOS wrong by a wide margin — this file's watch estimate deserves the same scepticism before anyone
plans around it.

- [ ] ⛔ **The watch app is not embedded in the iOS app and therefore cannot reach a wrist.** The one
      `PBXCopyFilesBuildPhase` in the project embeds the widget extension; the iOS target declares no
      dependency on the watch target and has no "Embed Watch Content" phase. Add both. Also check in
      the watch scheme — `build.sh:133` drives a scheme that is not shared.
- [ ] ⛔ **The watch carries none of the bundled corpus**, so it is not usable on bundled content
      alone and breaks the durability rule outright. Its Resources phase holds only
      `Assets.xcassets`; its entire content is a **four-key `WCSession` payload** — text, publishedAt,
      date, segmentHash. Add the corpus JSON and `CorpusService`. That also retires the dead
      `WatchDataService.fetchDailyContent()` and the "Lesson N" caption, which can never populate
      because nothing on the watch writes a `DailyLesson`.
- [ ] **The complications cannot appear on a watch face.** `ACIMDailyMinuteWatchWidget` compiles into
      the watch app but there is **no watchOS widget-extension target** and the struct is in no
      `WidgetBundle`. Add the target. ⛔ `PARITY.md` marks this "Pass" — **that document is dated
      2026-04-14 and is wrong here; re-derive it or delete it, do not trust it.**
- [ ] **Smaller watch truths, all in `WatchDataService.swift`.** `fetchTodaysMinute()` sorts by
      `publishedAt` and takes the newest row, so a week-old minute renders under "Today"; the
      receiver inserts and never updates; and nothing redraws when a payload lands — no `@Query`, no
      observation.
- [ ] ⛔ **`WCSession` has never been proved end to end.** The watch simulator `build.sh` drives is
      unpaired, and a session cannot activate unpaired. A paired phone+watch simulator pair is the
      only way to see the transport work.

### Phase 3 — Apple TV: the target is built, the interface is not

⛔ **The `ACIMDailyMinuteTV` target exists, compiles, installs and runs on the Apple TV simulator,
and `build.sh` is now four legs.** It compiles the **same source list as the app** — every platform
difference is a fence inside a file, so there is no second membership list to drift. Its entitlements
carry the App Group and **no iCloud**, and its device family is `3`.

⛔ **The port was much smaller than this file claimed** — "fifteen classes of compile error" across
"79 directives at 43 sites" was wrong. One substitution, `#if os(iOS)` → `#if os(iOS) || os(tvOS)`,
dissolved the whole mis-partitioning class; the rest was framework fences in about a dozen files.
⛔ **The two idioms are `#if !os(tvOS)` and `#if os(iOS) || os(tvOS)`; a bare `#else` pair is what
created the problem** and `Utilities/ReadableContentWidth.swift` is the file that always had it right.

⛔ **Three fences are iOS-only for a REASON, not an API**, and widening them would compile and be
wrong: `OrientationController` (a television does not rotate), `BackgroundRefreshManager` (its whole
job is keeping practice reminders current) and the `LiveActivityManager` call sites.

**What tvOS does not have, and therefore what the TV build does not show:** sharing, swipe actions,
pull-to-refresh, the segmented picker *style* (the pickers themselves are there), reminders of any
kind, note editing, text selection, and both backup tiers — there is no document picker on tvOS, so
a reader's words cannot be carried off it.

- [ ] ⛔ **HIS CALL — the player-first interface.** His decision is recorded: *tvOS is a player,
      listen and watch first, reading secondary.* What runs today is the **phone's** five-tab layout,
      which tvOS renders as a top tab bar; it works, but it is not the design he asked for. The
      readable column is also 672pt on a 3840pt screen, which is right on a phone and thin on a
      television. ⛔ Do not invent this alone — it stopped being a compile problem and became a
      design one.
- [ ] ⛔ **A reader must not be invited to annotate on the TV.** The container there is *purgeable*
      and no document picker exists, so a highlight made on a television has no route off it.
      `SharedModelContainer.groupURL` no longer force-unwraps, so a missing group no longer crashes
      at launch — but not crashing is not the same as being durable. Either give the TV target
      CloudKit or keep the reading surfaces read-only there.
- [ ] **Brand assets.** The tvOS build warns: no "App Icon & Top Shelf Image" collection. Needs a
      tvOS layered icon and a Top Shelf image before it could ship.
- [ ] ⛔ **HIS CALL — video on the TV, unchanged and still not urgent.** tvOS has no WebKit, so the
      `WKWebView` YouTube embed has no port, and **the feed carries no direct video URL an `AVPlayer`
      could open** — so audio-only is not a preference, it is the only reachable option. The
      archive.org MP3s stream to an Apple TV exactly as they do to a phone. An MP4 URL beside the
      MP3s is a pipeline question, separate and not blocking.

### Phase 4 — Windows and Linux: one web reader over the same JSON

Explicitly last. Nothing starts here while any Apple platform is unfinished.

- [ ] **A static reader served from acimdailyminute.org**, over the **same** bundled JSON the app
      ships — `ACIMSegments.json`, `ACIMTextSections.json`, `Workbook365Bodies.json`,
      `ACIMManual.json`, `WorkbookIntroductions.json`, about 5.6 MB — which the site already
      publishes. Installable as a PWA, so Windows, Linux, Android and ChromeOS are all reached by one
      codebase with no store, no signing and no review.
- [ ] ⛔ **It must read and write the same backup `.json`.** That file was designed for exactly this:
      plain UTF-8, no private extension, no private UTI, with a human name and citation on every mark
      so it reads as a document. Import stays strictly additive there as it is in the app — a
      snapshot carries no deletions, and `MergePlan` has no field that can express one.
- [ ] **The rules are ported, never re-invented.** The punctuation-spacing repair, the citation
      format and its paragraph rule, the anchor and quote re-resolution and the merge algebra are
      already written as portable specifications, and several have Python twins in `tools/` that the
      Swift harnesses are proved against. Those twins are the reference implementation for a web
      port — a second implementation that disagrees is the bug this whole project is built to avoid.

## ▶ OPEN — physical-book parity gaps

What a physical *A Course in Miracles* gives a reader that this app does not. Ranked by how much each
blocks "this replaces my book". The content is now bundled and reachable through `CorpusService` —
1,983 segments, 272 Text sections, 105 Manual segments, 365 lesson bodies. These are what turn it into
a book.

- [ ] **An empty Archive day should offer a way onward.** His proposal, and the shape is decided:
      under the sentence that says why a day is empty, list **the nearest few days before it that do
      have a reading** — a handful, enough to fill the space, not a second archive. Both surfaces
      show the same emptiness: the row under the calendar and the pushed day screen.
      Counting back from the **selected** day rather than from today, so browsing April offers April.
      Nothing when the selected day has a reading — there is no space to fill. The rows the calendar
      already draws its dots from are the same rows this needs, so no new query.
      ⛔ The Archive is the one place dates are the index rather than a publication stamp, so a row
      here names its **date** and its book — that exemption does not extend anywhere else.

- [ ] **"Let it fall open"** — a random passage. A real practice with the physical book. His
      proposal, not yet built: a random *published* Daily Minute from the archive rather than a
      random corpus passage, so it arrives with narration and video; fall back to a random bundled
      segment when the archive cache is empty. Draws from ~165 entries instead of the whole book,
      so it repeats sooner; that is the trade he chose.
- [ ] **Workbook completion tracking** — which lessons the reader has *done*, distinct from listened.
- [ ] **Structure the Manual for Teachers** into its question-and-answer form. It is bundled as 105
      unstructured segments by decision, searchable and readable one passage at a time through
      `ManualSegmentView`; a browsable structure is what is missing.

## ▶ OPEN — content and pipeline

- [ ] **Every Workbook introduction is glued to the foot of the lesson before it.** In
      `Workbook365Bodies.json` the Review I introduction ends Lesson 50's body, Review II ends 80,
      Review III 110, Review IV 140, Review V 170, the "Introduction to Lessons 181-200" ends 180,
      Review VI ends 200, the Part II introduction and "What is Forgiveness?" end 220, each later
      "What is …?" ends 230, 240 … 350, and "What am I?" with "Our final lessons" ends 360. A reader
      opening Lesson 50 reads Review I's instructions at its foot, and the review lessons themselves
      (51-60, 81-90, 141-150, 171-180, 201-220) are bare ideas with their instructions a lesson
      away. Found while reading every lesson for its practice cadence; the cadence data was authored
      from those tails, so it is right, but the reading surface is not. Each belongs as its own
      reading, keyed like the two Part Introductions, and the segments are the identity so the
      repair is at export and at render, never a re-extraction.
- [ ] **`WorkbookIntroductions.json` entry 500 is two paragraphs short.** The Part II Introduction
      stops at "…safely home, where He would have us be." and lacks the closing paragraphs — the
      only place the Course says how the "What is …?" sections are to be used ("slowly read and
      thought about a little while, preceding one of the holy and blessed instants in the day").
      They are in Lesson 220's body tail and the PDF.

- [ ] ⛔ **`Pref.N` names two paragraphs.** The Preface ships as two sections — `0.1 Publisher's
      Note`, 17 paragraphs, and `0.2 The Use of Terms`, 42 — but the citation format carries no
      section number, so `Pref.10` is paragraph 10 of either, and 21 shipped segments carry the
      form (`Pref.1` … `Pref.40`). A tap on one opens the Preface at its head rather than guess.
      Fixing it means a `Pref.S.N` form, which changes a citation already printed into exports;
      his call.
      `Citation.swift`'s `preface` case and `tools/citations.py`'s `text_citation` are the two
      places the format lives.

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

- [ ] **The archive minute is the last reading that cannot be marked.** `ArchivedReadingCard`
      draws its minute body as plain `Text`, so it alone offers no selection, no highlight, no
      note and no export. Every other reading goes through `AnnotatableReadingText`. Left out of
      the scaffold work deliberately — it is a renderer change, not a layout one — and it lands on
      a surface whose bookmark key already does not alias with Today's.

- [ ] **The eyebrow cannot hold at accessibility text sizes.** `CardHeaderRow`'s label is
      `lineLimit(1)` with `fixedSize`, so at AX sizes it breaks its words rather than wrapping or
      shrinking. True before the scaffold and unchanged by it. Fixing it means letting the eyebrow
      wrap, which changes the header's height on every reading — his layout call, not a defect to
      quietly patch.

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
- [ ] **One defaults key is dead.** `lastArchiveFetch` is declared at
      `Services/FetchCooldown.swift:44` and never used. Found while deciding what a backup carries.
      It does not travel.

- [ ] **Pre-submission sweep.** Walk Archive, Saved, Lessons, deep links, widget and watch for surfaces
      that display data they do not have. No `TODO`/`FIXME`/stub copy remains in any view, widget or watch
      source, so what is left is behavioural empty-state handling — an interactive pass on the device.
