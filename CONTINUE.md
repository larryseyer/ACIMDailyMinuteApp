# Continuation Prompt — ACIM Daily Minute App

Paste into a fresh Claude Code session started in `/Users/larryseyer/ACIMDailyMinuteApp` to resume where we left off.

---

## TL;DR

Phases 1 (audit), 2 (architecture), 3.1 (scaffolding), 3.2 (SwiftData schema), 3.3 (service layer), 3.4 (Today tab + app wiring + 5-tab shell), 3.5-pre (pbxproj repair + build.sh hardening), and **3.5a (Lessons tab spine — synthetic 1–365 list + row + metadata merge)** are complete and pushed to `https://github.com/larryseyer/ACIMDailyMinuteApp` (`main @ 9058ee5`). The iOS main-app target compiles clean against iPad 10th gen / iOS 18.1 (0 errors in main-target files; 8 pre-existing Widget errors are expected and deferred to Phase 3.9). The Widget target and Watch UI files still use the old schema and remain broken **by design** — they are Phase 3.9 and 3.10 scope.

Resume at **Phase 3.5b — `LessonDetailView`** with the three render states (Full / Metadata-only / Absent) + `.navigationDestination(for: Int.self)` wired on `LessonsView`. The full Phase 3.5 plan is approved and saved at `/Users/larryseyer/.claude/plans/abundant-herding-rabin.md`.

## Required reading (this order)

1. `/Users/larryseyer/.claude/plans/gentle-gathering-pearl.md` — Phase 1 audit
2. `/Users/larryseyer/.claude/plans/piped-wandering-lobster.md` — Phase 2 architecture (authoritative)
3. `/Users/larryseyer/.claude/plans/harmonic-gliding-wilkes.md` — Phase 3.2 schema execution
4. `/Users/larryseyer/.claude/plans/snuggly-greeting-manatee.md` — Phase 3.3 service execution
5. `/Users/larryseyer/.claude/plans/fuzzy-booping-scone.md` — Phase 3.4 execution (Today tab)
6. `/Users/larryseyer/.claude/plans/abundant-herding-rabin.md` — **Phase 3.5 plan (APPROVED, next to execute)**
7. `/Users/larryseyer/ACIMDailyMinuteApp/README.md` — current feature overview

## Persistent memory

At `/Users/larryseyer/.claude/projects/-Users-larryseyer-ACIMDailyMinuteApp/memory/`. Start with `MEMORY.md` (the index). Key rules live there — read them before writing code or docs.

## Decisions already locked (do not re-ask)

| Decision | Value |
|---|---|
| Apple Developer Team ID | `RR5DY39W4Q` |
| Bundle ID prefix | `com.larryseyer.acimdailyminute` |
| App Group | `group.com.larryseyer.acimdailyminute` |
| BG task identifier | `com.larryseyer.acimdailyminute.refresh` |
| SwiftData store filename | `ACIMDailyMinute.sqlite` |
| URL scheme | `acimdailyminute://` |
| Daily reminder default | 7:00 AM local (opt-in) |
| Phrases feature | Phrase-based watchlist; matcher = `PhraseMatcher` |
| Lesson navigation | Jump to any lesson 1–365 |
| Audio playback | AVFoundation + MPNowPlayingInfoCenter; relative `audio_url` auto-prefixed with `https://www.acimdailyminute.org` |
| Min deployment | iOS 17 / iPadOS 17 / macOS 14 / watchOS 10 |
| Current dev test target | **iPad (10th generation), iOS 18.1** (wired in `build.sh`) |
| Swift | 6.0 with strict concurrency |
| Dependencies | Zero — Apple frameworks only |
| Watch networking | Independent, actor-based, mirrors phone DTOs. Watch target reads its own JSON + writes to the shared App Group SwiftData store. |
| Feed RSS namespace | `acim:*` (publisher's `<acim:stream>` = `"minute"` or `"lesson"`; `<acim:source>` reserved) |
| Podcast endpoints | Two: `/podcast-minute.xml` + `/podcast-lessons.xml` |
| Source text | **Sparkly Edition**, published by **Teddy Poppe (Theodore Poppe)**, CIMS/Endeavor Academy lineage, US public domain per *Penguin Books USA v. New Christian Church of Full Endeavor* (2003). **NOT the FIP edition** — load-bearing for README/LICENSE. |

## Project state (on disk + pushed)

```
/Users/larryseyer/ACIMDailyMinuteApp/
├── .git/                                    origin → github.com/larryseyer/ACIMDailyMinuteApp (main)
├── README.md                                Sparkly Edition / Teddy Poppe / CIMS / 2003 Penguin case
├── LICENSE                                  CC BY-SA 4.0 scoped to original works
├── CONTINUE.md                              this file
├── ACIMDailyMinute.xcodeproj/               3 targets, Team RR5DY39W4Q, App Group wired
├── ACIMDailyMinute.entitlements
├── ACIMDailyMinute/
│   ├── App/                                 ✅ 5-tab shell + Settings sheet + About sheet (macOS)
│   │   ├── ACIMDailyMinuteApp.swift         registers BG task, notification delegate, UserDefaults defaults
│   │   └── ContentView.swift                TabView (iOS) + custom MacBottomTabBar (macOS); MiniPlayer overlay reserved
│   ├── Models/                              ✅ Phase 3.2
│   │   ├── DailyMinute.swift                @unique segmentHash
│   │   ├── DailyLesson.swift                @unique lessonNumber
│   │   ├── ArchivedReading.swift            @unique lineHash, FTS5 via searchableText
│   │   ├── Bookmark.swift                   composite itemKey "minute:{hash}" | "lesson:{N}"
│   │   ├── Channel.swift
│   │   └── ACIMActivityAttributes.swift
│   ├── Services/                            ✅ Phase 3.3
│   │   ├── DataService.swift                struct + @MainActor persist; DTOs live here
│   │   ├── ArchiveService.swift             @MainActor final class; persists inline archive[]
│   │   ├── FeedService.swift                acim:* namespace parser; FeedItemDTO
│   │   ├── PodcastService.swift             actor
│   │   ├── AudioManager.swift               @Observable @MainActor; Self.resolve(_:) for relative URLs
│   │   ├── NotificationManager.swift        actor; scheduleDailyReminder(hour:minute:)
│   │   ├── BackgroundRefreshManager.swift   enum (iOS)
│   │   ├── LiveActivityManager.swift        enum (iOS)
│   │   ├── PhraseMatcher.swift              findNewMatches(inMinute:)/(inLesson:); itemKey dedup
│   │   ├── FetchCooldown.swift              dailyMinute / dailyLesson / feed / archive keys
│   │   └── ConnectivityManager.swift        NWPathMonitor wrapper
│   ├── Views/
│   │   ├── Today/                           ✅ Phase 3.4
│   │   │   ├── TodayView.swift              @Query minutes+lessons; pull-to-refresh; offline banner
│   │   │   ├── DailyMinuteCard.swift        passage + bookmark + share + audio chip
│   │   │   └── DailyLessonCard.swift        lesson N + title + bookmark + share + audio chip
│   │   ├── Lessons/                         ✅ Phase 3.5a (spine only; detail/search/jump in 3.5b–c)
│   │   │   ├── LessonMeta.swift             view-layer value type ({N, title?, dateRead?, hasFullText})
│   │   │   ├── LessonRow.swift              gold capsule + Georgia title + bookmark dot; NavigationLink(value: Int)
│   │   │   └── LessonsView.swift            NavigationStack + List(1...365) + 2-@Query merge
│   │   ├── Digest/                          (stub — to become ListenView in 3.6)
│   │   ├── Archive/                         (stub — Phase 3.7)
│   │   ├── Saved/                           (stub — Phase 3.8)
│   │   ├── Settings/                        (stub sheet — Phase 3.8)
│   │   ├── Onboarding/                      (dead code; wired back in 3.8)
│   │   └── AboutView.swift                  macOS About sheet
│   ├── Shortcuts/
│   │   └── GetTodaysFactsIntent.swift       stubbed "coming soon" dialog (rename + real impl in 3.8)
│   ├── Utilities/
│   │   ├── HashUtility.swift                SHA-256 truncated hex (also in Widget target)
│   │   ├── PhraseStorage.swift              UserDefaults-backed phrases + notifiedItemKeys
│   │   ├── PlatformTypography.swift
│   │   ├── ShareTextBuilder.swift           minuteShareText / lessonShareText
│   │   └── TermExtractor.swift
│   ├── Resources/
│   └── Assets.xcassets
├── ACIMDailyMinuteWidget/                   ⏳ Phase 3.9
│   └── SharedModelContainer.swift           schema final
├── ACIMDailyMinuteWatch/                    ⏳ Phase 3.10 for UI
│   ├── WatchDataService.swift               ✅ ACIM-native (Phase 3.3)
│   ├── WatchContentView.swift               old schema; broken
│   ├── WatchStoryRow.swift                  old schema; broken
│   └── ACIMDailyMinuteWatchWidget.swift     old schema; broken
├── build.sh                                 iPad (10th generation) iOS 18.1
├── clean.sh, both.sh
├── bu.sh                                    git add/commit/push + Dropbox zip backup
│                                            Dropbox folder missing; zip step fails harmlessly
│                                            Fix: mkdir -p "/Users/larryseyer/Dropbox/Automagic Art/Source Backup/ACIM Daily Minute Backups"
└── run_ralph.sh + bash/                     Ralph agentic loop (unused)
```

## Build state

- **iOS main app target**: compiles clean (verified at `9058ee5` against iPad 10th gen / iOS 18.1 — **zero errors in main-target files**; 8 Widget errors expected + deferred).
- **macOS**: code-signing only (no provisioning profile in CI). Code compiles.
- **Widget + Watch UI files**: still use old schema. Broken by design until Phases 3.9 / 3.10 — 10 Widget compile errors are expected.
- **build.sh** now fails loudly. The old `| tail -5` pipe silently masked xcodebuild failures (which is how phantom-file pbxproj rot lingered undetected through Phase 3.4). The new `run_build` helper logs to `build/logs/{ios,macos,watchos}.log`, prints the last 80 lines on failure, and propagates exit codes via `set -o pipefail`. **Do not regress this** — running `build.sh` to its successful conclusion is meaningful again.
- To verify just the iOS main target (skipping known-broken Widget/Watch), run xcodebuild directly: `xcodebuild -scheme ACIMDailyMinute -destination "id=<iPad-10th-gen-UUID>" -configuration Debug -derivedDataPath ./build build > /tmp/ios.log 2>&1; grep "error:" /tmp/ios.log | grep -vE "(ACIMDailyMinuteWidget|WidgetExtension)" | wc -l` — expect `0`.
- **Heads-up**: multiple iPad (10th generation) simulators on iOS 18.1 exist, so the `name=` destination is ambiguous. Use `id=86F64729-D28D-44F7-BEB9-EF34AA7B7F28` (or any other UUID from `xcrun simctl list devices available | grep "iPad (10th generation)"`) when driving `xcodebuild` directly. `build.sh` uses the name form and will fail with `xcodebuild: error: Unable to find a device matching...` on the same ambiguity — fix is pending; for now, use the UUID form for manual iOS main-target compile checks.

## Service-layer API surface (Views consume)

**`DataService` (struct, Sendable):**
- `init(modelContainer:)`
- `func fetchDailyMinute(baseURL:) async throws -> DailyMinuteResponse?` — nil if cooldown blocks
- `func fetchDailyLesson(baseURL:) async throws -> DailyLessonResponse?`
- `@MainActor static func persistMinute(_ dto:, in context:) throws -> DailyMinuteResponse`
- `@MainActor static func persistLesson(_ dto:, in context:) throws -> DailyLessonResponse`
- `@MainActor static func parseISODate(_:) -> Date?`

**`FeedService`:** `fetchFeedItems(baseURL:)` → `[FeedItemDTO]?`; `@MainActor static persistFeed(_:in:)` records cooldown.

**`PodcastService` (actor):** `fetchMinuteEpisodes(baseURL:force:)` + `fetchLessonEpisodes(...)` → `[PodcastEpisode]` (newest-first).

**`AudioManager` (@Observable @MainActor):** `play(url:title:)`; `togglePlayback`; `skip(by:)`; `stop`.

**`NotificationManager` (actor, `shared`):** `sendNotification(title:body:identifier:userInfo:)`, `scheduleDailyReminder(hour:minute:)`, `cancelDailyReminder()`.

**`PhraseMatcher` (enum):** `findNewMatches(inMinute:)` / `findNewMatches(inLesson:)` → `[Match]`; `markAllNotified(itemKeys:)`.

**`LiveActivityManager` (enum, iOS):** `startOrUpdate(channel:latestText:publishedDate:lessonNumber:)`; `endAllActivities()`.

**`BackgroundRefreshManager` (enum, iOS):** `register()`, `scheduleRefresh()`, `performForegroundCheck()` (60s debounced).

**UserDefaults keys (registered in `ACIMDailyMinuteApp.init`):** `notifyNewMinute`, `notifyNewLesson`, `notifyPhraseMatches`, `notifyLiveActivities`, `useCustomNotificationSound`. Plus backend-only: `watchedPhrases`, `phraseNotifiedItemKeys`, `phraseMatchBadge`, `lastMinuteSegmentId`, `lastMinuteDate`, `lastLessonId`, `lastFetch`, `lastForegroundCheck`.

**`Notification.Name`:** `.phrasesTapped`, `.forceMinuteRefresh`, `.forceLessonRefresh`, `.openSettingsRequested`, `.openAboutRequested`.

## What's live at end of Phase 3.5a (`9058ee5`)

- Today tab: live Daily Minute + Daily Lesson fetched from `https://www.acimdailyminute.org/daily-minute.json` and `/daily-lesson.json`. Pull-to-refresh resets cooldowns and re-fetches. Offline → last cached reading renders with a banner.
- **Lessons tab: 1–365 spine renders.** Two `@Query`s (`DailyLesson` + `ArchivedReading` where `channel == "daily-lesson"`) merged into `[Int: LessonMeta]` via `.reduce(into:)`. `DailyLesson` wins on conflict. Today's lesson shows real title + date; recent archive rows show title; everything else shows "Not yet read." Bookmark dot renders for any lesson whose `Bookmark.itemKey` starts with `lesson:`. `NavigationLink(value: Int)` is wired on each row but **tap is inert until 3.5b adds `.navigationDestination(for: Int.self)`**.
- Bookmark toggle on each Today card → writes `Bookmark` row with `itemKey "minute:{hash}"` or `"lesson:{N}"`.
- ShareLink → `ShareTextBuilder.minuteShareText` / `.lessonShareText`.
- Listen chip on each card → calls `AudioManager.play(url:title:)`. MiniPlayer overlay is reserved in `ContentView` but hidden until audio starts.
- Settings sheet opens via toolbar button or ⌘, (macOS). Content is a "Phase 3.8" placeholder.
- 3 other tabs (Listen / Archive / Saved) render "coming soon" placeholders.
- macOS About sheet (⌘ menu → About) renders the custom AboutView.

## Phase 3.5 scope — Lessons tab (plan locked)

Full plan: `/Users/larryseyer/.claude/plans/abundant-herding-rabin.md` (approved).

**Data-source decision (already resolved):** drive the Lessons tab off a local synthetic `1...365` spine, merged at render time with a `[Int: LessonMeta]` overlay built from two `@Query`s — `DailyLesson` rows (authoritative full text) and `ArchivedReading` rows where `channel == "daily-lesson"` (title + date only). `DailyLesson` wins on conflict. Rows without either hit render "Lesson N — not yet read." No new endpoint, no pre-loading, zero new persistence. A `/lessons-index.json` fetch can be grafted in later without touching the view layer.

**Non-obvious wiring** uncovered during 3.5a execution: for `ArchivedReading` rows where `channel == "daily-lesson"`, the **lesson title is stored in `ArchivedReading.text`** (not a separate title field), because lesson-archive entries from the publisher don't ship a body — only `{lesson_id, title, date, audio_url}`. See `ArchiveService.persistInlineLessons` line 61 (`row.text = item.title`). `LessonsView.buildMetaIndex()` already reads this correctly; `LessonDetailView`'s Metadata-only render state must do the same.

**Execution chunks** (one `./bu.sh` commit each):

- **3.5a** ✅ `9058ee5` — spine only (`LessonsView` + `LessonRow` + `LessonMeta`), wired into `ContentView`, deleted placeholder + `Placeholders/` group. pbxproj surgery used IDs `AA000001210-1212` (buildFiles), `AA000002210-2212` (fileRefs), `AA000005022` (Lessons PBXGroup).
- **3.5b** ⏭ NEXT — `LessonDetailView` with all three render states (Full / Metadata-only / Absent) + `.navigationDestination(for: Int.self)` wired on `LessonsView`. Commit: `Phase 3.5b: LessonDetailView with full/metadata-only/absent states`.
- **3.5c** — `.searchable` filter + Jump-to-N sheet with 1–365 validation. Commit: `Phase 3.5c: Lessons search + Jump-to-N affordance`.

**Files still to create** (for 3.5b):

- `ACIMDailyMinute/Views/Lessons/LessonDetailView.swift` — three render states:
  - **Full**: `@Query` for `DailyLesson` where `lessonNumber == n` → render a detail-scale composition reusing primitives from `DailyLessonCard.swift` (header, word-count badge, body, bookmark, share, audio chip) at full width. **Do NOT embed `DailyLessonCard` wholesale** — it's a compact card; duplicate the primitives at full-width instead.
  - **Metadata-only**: no `DailyLesson` but `ArchivedReading` with `lessonNumber == n` exists → show lesson number + `archive.text` (the title) + `archive.dateString` + audio chip (if `archive.audioURL` present) + "Full text available once today's lesson fetches this entry."
  - **Absent**: neither exists → `ContentUnavailableView("Lesson N not yet cached", systemImage: "book.closed", description: "…")` + Refresh button that calls `DataService.fetchDailyLesson(baseURL:)` + `DataService.persistLesson(_:in:)`.
- Add `.navigationDestination(for: Int.self) { LessonDetailView(lessonNumber: $0) }` inside the `NavigationStack` in `LessonsView.swift`. (`LessonRow` already emits `NavigationLink(value: lessonNumber)` — no row changes needed.)

**pbxproj for 3.5b:** one new file → buildFile `AA000001213`, fileRef `AA000002213`. Add to `AA000005022 /* Lessons */` group children and to the main-target Sources build phase, adjacent to the existing `LessonsView.swift` entries.

**Non-goals (explicitly deferred):** no full-index fetch, no pre-loading 365 lessons, no FTS5 search (that's Phase 3.7 Archive), no swipe-to-bookmark rows, no `acimdailyminute://lesson/47` deep link (Phase 3.8).

## Ground rules

- **Swift & SwiftUI only.** No UIKit except the existing WKWebView for YouTube embed. No third-party SDKs.
- **Swift 6 strict concurrency.** `@MainActor` on all SwiftData writes. `@Observable` for UI state, `actor` for networking services.
- **No `xcodebuild` runs from Claude for physical-device builds.** Simulator builds via `./build.sh` are fine.
- **Reference app:** there is a SwiftUI pattern-library app on disk whose path lives in the memory system (`reference_app_path.md`). Read it freely for style and pattern references. **Never** copy text, identifiers, or comments from it. **Never** name it or cite it anywhere inside this repo. Describe techniques directly in your own words.
- **Commit per logical chunk** via `./bu.sh "message"` (git add/commit/push + Dropbox zip; zip fails harmlessly).
- **Zero placeholder data.** All content from `https://www.acimdailyminute.org/*`. Offline fallback = last-known-good cache in SwiftData.
- **Sparkly Edition language is non-negotiable.** Never let docs drift to "FIP" framing.
- **Confirm before actions with blast radius** — pushing, force-operations, deleting branches. Per-chunk `./bu.sh` commits pre-authorized once confirmed in-session.

## Phase 3 roadmap (remaining)

| Sub-phase | Status | Goal |
|---|---|---|
| 3.1 | ✅ | Xcode project, 3 targets, entitlements, App Group |
| 3.2 | ✅ | SwiftData schema |
| 3.3 | ✅ | Service layer for ACIM models |
| 3.4 | ✅ | Today tab + app wiring + 5-tab shell |
| 3.5-pre | ✅ | pbxproj repair + build.sh hardening (`ae93d5a`) |
| 3.5a | ✅ | Lessons tab spine — 1–365 list + row + metadata merge (`9058ee5`) |
| 3.5b | ⏭ NEXT | `LessonDetailView` (Full / Metadata-only / Absent) + `.navigationDestination(for: Int.self)` |
| 3.5c | | Lessons `.searchable` filter + Jump-to-N sheet (1–365 validation) |
| 3.6 | | Listen tab (podcast feed, AVFoundation playback, MiniPlayer, YouTube embed) |
| 3.7 | | Archive tab (calendar + FTS5 search over `ArchivedReading.searchableText`) |
| 3.8 | | Saved + Settings (Phrases editor, notification toggles) + Onboarding |
| 3.9 | | Widget target (3 families + Live Activity UI) |
| 3.10 | | Watch companion UI + 3 complications |
| 4 | | Feature parity checklist verification |
| 5 | | Branding + asset catalog + app icons + ACIMChime.caf |

## First move for the new session

1. Read the 7 required-reading files above (the Phase 3.5 plan `abundant-herding-rabin.md` remains authoritative).
2. Read the memory index at `/Users/larryseyer/.claude/projects/-Users-larryseyer-ACIMDailyMinuteApp/memory/MEMORY.md` and every file it points to.
3. Confirm active model is Claude Opus 4.6 and `/fast` is OFF. Flag either if not.
4. Verify the iOS main target is still green (main-target-only check shown in **Build state** above, using the `id=<UUID>` destination form — the `name=` form is ambiguous because multiple iPad 10th-gen sims on iOS 18.1 are installed). Do NOT require the full `./build.sh` to pass — Widget + Watch targets are broken by design until Phases 3.9 / 3.10.
5. **Skip plan mode for 3.5b** — the plan is already approved and locked in `abundant-herding-rabin.md`. Execute **Phase 3.5b** directly:
   - Create `ACIMDailyMinute/Views/Lessons/LessonDetailView.swift` with the three render states (Full / Metadata-only / Absent). **Do not embed `DailyLessonCard` wholesale** — duplicate its primitives at full width. For Metadata-only, remember `archive.text` IS the lesson title (see "Non-obvious wiring" note in Phase 3.5 scope above).
   - Wire `.navigationDestination(for: Int.self) { LessonDetailView(lessonNumber: $0) }` inside the `NavigationStack` in `LessonsView.swift`. `LessonRow` already emits `NavigationLink(value: lessonNumber)` — no row changes needed.
   - Register the new file in `project.pbxproj`: add buildFile `AA000001213`, fileRef `AA000002213`, place under the `AA000005022 /* Lessons */` group alongside the existing three entries, add to the main-target Sources build phase.
   - Run the main-target verification command from **Build state** to confirm 0 errors before committing.
   - Commit via `./bu.sh "Phase 3.5b: LessonDetailView with full/metadata-only/absent states"`.
6. Proceed to **3.5c** (`.searchable` + Jump-to-N sheet) per the plan, committing via `./bu.sh`.

Parallel Explore agents are not needed — the approved plan already captures the inventory work done last session. Re-enter plan mode only if an unforeseen architectural fork appears mid-execution.
