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
      the notification arrives. Notification permission is now requested at launch; it used to be reached
      only by switching the daily reminder on, so anyone who left that off was never asked and every
      alert was discarded unasked-for.
- [ ] **Lesson bodies.** Open a lesson the feed has not published yet — anything in 1-80. Expected:
      the full lesson text in flowing paragraphs, with no YouTube frame standing in for missing words.
      All 365 bodies are bundled now. Note that choosing a lesson that *has* a video still opens that
      video full screen first by design; dismissing it lands on the text.
- [ ] **The corpus floor.** Airplane mode, delete and reinstall, cold launch. Expected: Today shows a
      complete reading from the bundle with no network, no spinner and no empty state. It is a plain
      card with no save, share or Listen control, because that passage was never published.
- [ ] **Downloads stay invisible.** Swipe a Listen row. Expected: no Download action, because
      `audio_url` is empty on every episode and all 158 archive entries. It appears by itself once
      archive.org hosting exists — no app change.
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

- [ ] **The two Part Introductions.** "Part 1 Introduction" appears above Lesson 1 and "Part 2
      Introduction" between Lesson 180 and Lesson 181. Both read, annotate and save. Their titles
      come from the corpus rather than from literals, so the row and the screen cannot disagree.

## ▶ NEXT — canonical citations

`T-1.I.1:1` — Text, chapter, section, paragraph, sentence. A durability requirement rather than a
study-group convenience: citations are the interoperability layer that lets a reader move between
this app, a paper book, and whatever comes after both. `sourceReference` today is loose prose.

The Text's paragraphs are addressable now — 2,911 of them, recovered at export and stable, with
`ReadingText.displayString(from: body) == body` holding for all 268 sections — which is what makes
this tractable at all. Spec first, then plan, then execute.

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

- [ ] ⛔ **Canonical citations** (`T-1.I.1:1` — Text, chapter, section, paragraph, sentence). Promoted
      from a study-group convenience to a **durability requirement**: citations are the interoperability
      layer that lets a reader move between this app, a paper book, and whatever comes after both.
      `sourceReference` today is loose prose, not a citation.
- [ ] **Search across the whole corpus**, not just the rolling archive window — the book's index.
- [ ] **Cross-reference links** — the Course refers to itself constantly; a citation should be tappable.
- [ ] **Resume where you stopped** — the ribbon. Unblocked now that the Text is readable, and it is
      what a 669-page book needs most: `ReadingKey.textSection` already names the place.
- [ ] **"Let it fall open"** — a random passage. A real practice with the physical book, nearly free once
      the corpus is bundled.
- [ ] **Workbook completion tracking** — which lessons the reader has *done*, distinct from listened.
- [ ] **Structure the Manual for Teachers** into its question-and-answer form. It is bundled as 105
      unstructured segments by decision; a searchable unstructured Manual beats no Manual.

## ▶ OPEN — content and pipeline

- [ ] **Sentences are run together where a period meets the next word** — `"YOURS.You"` in the
      published minute text, and the same defect throughout `lessons.text`: `"thus far.There"`,
      `"planned.We"`, `"thinking.The"` in lesson 20 alone, and `"Source,Which"` and `"also.This"`
      throughout the Text, where it is now the most visible defect on any reading surface. It is
      bundled into the app, so a fix means re-running `tools/export_corpus.py` after the extractor's
      sentence-boundary handling is corrected. Source data, not the app — and one defect across
      three corpora, so it is fixed in the extractor, never in one export branch.
- [ ] **186 of 365 lesson bodies are one paragraph.** Not a rendering bug — `ReadingTextView` now
      draws these, and it recovers real paragraph structure for the other 179. Those 186 carry no
      blank line in `lessons.text` at all, so there is nothing in the source to split on. Fixing it
      means recovering structure in the extractor, on the pipeline side.

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
- [ ] **Pre-submission sweep.** Walk Archive, Saved, Lessons, deep links, widget and watch for surfaces
      that display data they do not have. No `TODO`/`FIXME`/stub copy remains in any view, widget or watch
      source, so what is left is behavioural empty-state handling — an interactive pass on the device.
