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

- [ ] **The Text is not readable in the app** — 31 chapters, ~669 pages, the largest part of the volume
      and the whole theoretical basis. All 268 sections are bundled in `ACIMTextSections.json` and
      exposed as `CorpusService.textSections`, with chapter and section numbers and titles. Nothing
      reads them yet: **Spec 2** is the reading UI — chapters, sections, navigation.
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
      and are not exported by `tools/export_corpus.py`. Spec 2 should place them, and the export
      needs a matching change.

## ▶ OPEN — content and pipeline

- [ ] **Sentences are run together where a period meets the next word** — `"YOURS.You"` in the
      published minute text, and the same defect throughout `lessons.text`: `"thus far.There"`,
      `"planned.We"`, `"thinking.The"` in lesson 20 alone. It is now bundled into the app, so a fix
      means re-running `tools/export_corpus.py` after the extractor's sentence-boundary handling is
      corrected. Source data, not the app.
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
