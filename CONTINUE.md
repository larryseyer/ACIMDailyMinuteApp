# Continuation Prompt — ACIM Daily Minute App

Paste into a fresh Claude Code session started in `/Users/larryseyer/ACIMDailyMinuteApp` to resume where we left off.

---

## TL;DR

Phases 1 (audit), 2 (architecture), 3.1 (scaffolding), 3.2 (SwiftData schema), 3.3 (service layer), 3.4 (Today tab + app wiring + 5-tab shell), 3.5-pre (pbxproj repair + build.sh hardening), 3.5a (Lessons tab spine — 1–365 list + row + metadata merge), 3.5b (`LessonDetailView` with Full / Metadata-only / Absent states + `.navigationDestination(for: Int.self)`), 3.5c (Lessons `.searchable` filter + Jump-to-N sheet with 1–365 validation), and **3.6 (Listen tab — segmented Minute/Lessons podcast feed + YouTube embed card + MiniPlayer overlay wired through existing `AudioManager`)** are complete and pushed to `https://github.com/larryseyer/ACIMDailyMinuteApp` (`main @ 475846c`). The iOS main-app target compiles clean against iPad 10th gen / iOS 18.1 (0 errors, 0 warnings in main-target files; 8 pre-existing Widget errors are expected and deferred to Phase 3.9). The Widget target and Watch UI files still use the old schema and remain broken **by design** — they are Phase 3.9 and 3.10 scope.

Resume at **Phase 3.7 — Archive tab (calendar + FTS5 search over `ArchivedReading.searchableText`)**. No approved plan exists for 3.7 yet — **enter plan mode** at the start of that session to design it. `ArchiveService` and the `ArchivedReading` SwiftData model (with `@unique lineHash` + FTS5 via `searchableText`) are already built; scope is the Archive tab UI — calendar date picker, per-date reading rendering, and full-text search across the archive.

Phases 3.5 (a/b/c) and 3.6 are now **complete and closed**.

## Required reading (this order)

1. `/Users/larryseyer/.claude/plans/gentle-gathering-pearl.md` — Phase 1 audit
2. `/Users/larryseyer/.claude/plans/piped-wandering-lobster.md` — Phase 2 architecture (authoritative)
3. `/Users/larryseyer/.claude/plans/harmonic-gliding-wilkes.md` — Phase 3.2 schema execution
4. `/Users/larryseyer/.claude/plans/snuggly-greeting-manatee.md` — Phase 3.3 service execution
5. `/Users/larryseyer/.claude/plans/fuzzy-booping-scone.md` — Phase 3.4 execution (Today tab)
6. `/Users/larryseyer/.claude/plans/abundant-herding-rabin.md` — Phase 3.5 plan (completed across 3.5a/b/c; historical reference)
7. `/Users/larryseyer/.claude/plans/tranquil-drifting-flame.md` — Phase 3.5b execution plan (harness artifact; subset of abundant-herding-rabin)
8. `/Users/larryseyer/.claude/plans/squishy-bubbling-moonbeam.md` — Phase 3.5c execution plan (harness artifact; subset of abundant-herding-rabin)
9. `/Users/larryseyer/.claude/plans/starry-roaming-spring.md` — Phase 3.6 plan (Listen tab; completed at `475846c`)
10. `/Users/larryseyer/ACIMDailyMinuteApp/README.md` — current feature overview

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
│   │   ├── Lessons/                         ✅ Phases 3.5a + 3.5b + 3.5c
│   │   │   ├── LessonMeta.swift             view-layer value type ({N, title?, dateRead?, hasFullText})
│   │   │   ├── LessonRow.swift              gold capsule + Georgia title + bookmark dot; NavigationLink(value: Int)
│   │   │   ├── LessonsView.swift            NavigationStack(path:) + List(1...365) + 2-@Query merge + .searchable + Jump toolbar + FilteredLessonsList
│   │   │   ├── LessonDetailView.swift       3 render states (Full / Metadata-only / Absent) with parameterized @Query predicates
│   │   │   └── JumpToLessonSheet.swift      compact sheet; numberPad TextField; 1–365 validation; path.append(n) on submit
│   │   ├── Listen/                          ✅ Phase 3.6
│   │   │   ├── ListenView.swift             NavigationStack + List(.plain) + segmented Minute/Lessons picker + YouTube card + load states
│   │   │   ├── PodcastEpisodeRow.swift      whole-row Button → AudioManager.play; waveform symbol animates while active
│   │   │   ├── YouTubePlayerView.swift      unchanged from scaffolding; 16:9 WKWebView iframe embed
│   │   │   └── MiniPlayerView.swift         unchanged from scaffolding; bound to AudioManager in ContentView overlay
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
│                                            Backup folder `ACIM Daily Minute Backups/` created 2026-04-13; zips now land successfully.
└── run_ralph.sh + bash/                     Ralph agentic loop (unused)
```

## Build state

- **iOS main app target**: compiles clean (verified at `475846c` against iPad 10th gen / iOS 18.1 — **zero errors and zero warnings in main-target files**; 8 Widget errors expected + deferred).
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

## What's live at end of Phase 3.6 (`475846c`)

- Today tab: live Daily Minute + Daily Lesson fetched from `https://www.acimdailyminute.org/daily-minute.json` and `/daily-lesson.json`. Pull-to-refresh resets cooldowns and re-fetches. Offline → last cached reading renders with a banner.
- **Lessons tab: 1–365 spine renders + tap navigates to detail.** Two `@Query`s (`DailyLesson` + `ArchivedReading` where `channel == "daily-lesson"`) merged into `[Int: LessonMeta]` via `.reduce(into:)`. `DailyLesson` wins on conflict. Today's lesson shows real title + date; recent archive rows show title; everything else shows "Not yet read." Bookmark dot renders for any lesson whose `Bookmark.itemKey` starts with `lesson:`.
- **Lessons tab: `.searchable` filter + Jump-to-N sheet (3.5c).** Search is exact-match on integer queries (`"47"` → only lesson 47) and `localizedStandardContains` on title for any query with non-digits (`"trust"` → all lessons whose known title contains "trust"). Empty query returns the full 1–365 spine. Toolbar "Jump" button opens `JumpToLessonSheet`, a medium-detent sheet with a `numberPad`-keyboard `TextField`; Go is disabled while the trimmed input isn't a valid 1–365 integer; on submit it appends N to the root `NavigationPath` and dismisses. The filtered list is encapsulated in a private `FilteredLessonsList` subview so `@Query` re-evaluation stays isolated from `searchText` churn.
- **Lesson detail renders the right state for any N in 1–365.** `LessonDetailView` builds two parameterized `@Query`s in `init` (`DailyLesson.lessonNumber == n`; `ArchivedReading.channel == "daily-lesson" && lessonNumber == n`). Full state: ScrollView + detail-scale Georgia (24 title / 19 body) + bookmark + ShareLink + Listen chip. Metadata-only: lesson N + `archive.text`-as-title + dateString + audio chip if present + "Full text available once today's lesson fetches this entry." Absent: `ContentUnavailableView` + Refresh button that calls `DataService.fetchDailyLesson` / `persistLesson` (honest copy when today's lesson ≠ requested N or cooldown blocks).
- Bookmark toggle on each Today card → writes `Bookmark` row with `itemKey "minute:{hash}"` or `"lesson:{N}"`.
- ShareLink → `ShareTextBuilder.minuteShareText` / `.lessonShareText`.
- Listen chip on each card → calls `AudioManager.play(url:title:)`. MiniPlayer overlay in `ContentView` becomes visible once `audioManager.hasActiveAudio == true` (hidden on the Listen tab itself so the row's own waveform indicator is canonical there).
- **Listen tab (3.6): segmented Minute / Lessons picker + newest-first episode list.** Each feed fetches lazily on first visit via `PodcastService.fetch{Minute,Lesson}Episodes` and caches in view-local `@State` per feed for the session. Pull-to-refresh flips `force=true` to bypass URLSession cache. Row tap routes to `AudioManager.play(url:title:)`; the currently-playing row swaps `play.fill` → animated `waveform` in gold accent. When today's `DailyMinute.youtubeURL` is non-nil, the top of the list renders a 16:9 inline `YouTubePlayerView` card — the existing `WKWebView`-based embed (only UIKit permitted per ground rules). Load states: `.loading` → ProgressView; `.failed` → `ContentUnavailableView` with wifi-slash + "Pull to retry"; `.loaded` + empty → "No episodes yet."
- Settings sheet opens via toolbar button or ⌘, (macOS). Content is a "Phase 3.8" placeholder.
- 2 other tabs (Archive / Saved) render "coming soon" placeholders.
- macOS About sheet (⌘ menu → About) renders the custom AboutView.

## Phase 3.5 scope — Lessons tab (plan locked)

Full plan: `/Users/larryseyer/.claude/plans/abundant-herding-rabin.md` (approved).

**Data-source decision (already resolved):** drive the Lessons tab off a local synthetic `1...365` spine, merged at render time with a `[Int: LessonMeta]` overlay built from two `@Query`s — `DailyLesson` rows (authoritative full text) and `ArchivedReading` rows where `channel == "daily-lesson"` (title + date only). `DailyLesson` wins on conflict. Rows without either hit render "Lesson N — not yet read." No new endpoint, no pre-loading, zero new persistence. A `/lessons-index.json` fetch can be grafted in later without touching the view layer.

**Non-obvious wiring** uncovered during 3.5a execution: for `ArchivedReading` rows where `channel == "daily-lesson"`, the **lesson title is stored in `ArchivedReading.text`** (not a separate title field), because lesson-archive entries from the publisher don't ship a body — only `{lesson_id, title, date, audio_url}`. See `ArchiveService.persistInlineLessons` line 61 (`row.text = item.title`). `LessonsView.buildMetaIndex()` already reads this correctly; `LessonDetailView`'s Metadata-only render state must do the same.

**Execution chunks** (one `./bu.sh` commit each):

- **3.5a** ✅ `9058ee5` — spine only (`LessonsView` + `LessonRow` + `LessonMeta`), wired into `ContentView`, deleted placeholder + `Placeholders/` group. pbxproj surgery used IDs `AA000001210-1212` (buildFiles), `AA000002210-2212` (fileRefs), `AA000005022` (Lessons PBXGroup).
- **3.5b** ✅ `b526c5b` — `LessonDetailView` with three render states; `.navigationDestination(for: Int.self)` in `LessonsView`. pbxproj used `AA000001213` (buildFile) + `AA000002213` (fileRef), appended to `AA000005022` group and main-target Sources phase.
- **3.5c** ✅ `de318fa` — `.searchable` filter + Jump-to-N sheet with 1–365 validation. `JumpToLessonSheet.swift` added; `LessonsView` promoted to `NavigationStack(path:)`, filter extracted into private `FilteredLessonsList`. pbxproj used `AA000001214` (buildFile) + `AA000002214` (fileRef). Locked decisions: (a) integer queries exact-match, non-digit queries do `localizedStandardContains` title match; (b) Jump Go button disabled while input invalid, inline hint only when non-empty invalid; (c) empty search shows full 1–365 spine.

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
| 3.5b | ✅ | `LessonDetailView` (Full / Metadata-only / Absent) + `.navigationDestination(for: Int.self)` (`b526c5b`) |
| 3.5c | ✅ | Lessons `.searchable` filter + Jump-to-N sheet (1–365 validation) (`de318fa`) |
| 3.6 | ✅ | Listen tab (segmented podcast feed + YouTube embed + MiniPlayer wiring) (`475846c`) |
| 3.7 | ⏭ NEXT | Archive tab (calendar + FTS5 search over `ArchivedReading.searchableText`) |
| 3.8 | | Saved + Settings (Phrases editor, notification toggles) + Onboarding |
| 3.9 | | Widget target (3 families + Live Activity UI) |
| 3.10 | | Watch companion UI + 3 complications |
| 4 | | Feature parity checklist verification |
| 5 | | Branding + asset catalog + app icons + ACIMChime.caf |

## First move for the new session

1. Read the 10 required-reading files above. Plans traverse in **timeline order** starting at `gentle-gathering-pearl.md`; OTTO-prefixed plans in `~/.claude/plans/` belong to a separate app and are out of scope here.
2. Read the memory index at `/Users/larryseyer/.claude/projects/-Users-larryseyer-ACIMDailyMinuteApp/memory/MEMORY.md` and every file it points to. Load-bearing rules locked during 3.5c: (a) no TODOs/FIXMEs anywhere — pick a sensible default and fully implement; (b) planning is my job — enter plan mode for every code-producing sub-phase, even when a parent plan is pre-approved.
3. Confirm active model is Claude Opus 4.6 and `/fast` is OFF. Flag either if not.
4. Verify the iOS main target is still green at `475846c` (main-target-only check shown in **Build state** above, using the `id=<UUID>` destination form — the `name=` form is ambiguous because multiple iPad 10th-gen sims on iOS 18.1 are installed). Do NOT require the full `./build.sh` to pass — Widget + Watch targets are broken by design until Phases 3.9 / 3.10.
5. **Enter plan mode for Phase 3.7 — Archive tab.** No approved plan exists yet. Scope:
   - Archive tab view — calendar date picker (`DatePicker(.graphical)` or custom month grid) over available `ArchivedReading` rows.
   - Per-date rendering: when a date is selected, show the Daily Minute + Daily Lesson `ArchivedReading` rows (`channel == "daily-minute"` / `"daily-lesson"`) for that date with full text + bookmark + share.
   - Full-text search: `.searchable` across the archive, consuming `ArchivedReading.searchableText` via SwiftData's FTS5 hook (already wired in the schema). Highlight matches in results; tapping a result opens that date.
   - Infinite/pull-to-load older archive pages via `ArchiveService` if the local cache is thin (cooldown key `FetchCooldownKey.archive` already exists).
   - Services already built: `ArchiveService` (`@MainActor final class`; persists inline archive[] into `ArchivedReading` via `@unique lineHash`).
   - Files likely new: `Views/Archive/ArchiveView.swift`, `Views/Archive/ArchiveCalendarView.swift` (or reuse system `DatePicker`), `Views/Archive/ArchiveSearchResultsView.swift`, `Views/Archive/ArchiveDateDetailView.swift`.
   - Pre-allocate pbxproj IDs in the plan (suggest: buildFiles `AA000001220-1223`, fileRefs `AA000002220-2223`, possibly reuse group `AA000005011 /* Archive */` if it already exists — verify first).
   - Lock all design decisions in the plan itself — no TODOs allowed in committed code.
6. After 3.7 ships, proceed to **Phase 3.8 — Saved tab + Settings + Onboarding** (phrases editor, notification toggles, deep-link reactivation). Also needs a fresh plan.

## End-goal reminder

Phase 3.5 is **one of eleven** remaining sub-phases. Full parity remains the bar: Today + Lessons + Listen + Archive + Saved + Settings + Onboarding + Widget + Watch + Shortcuts/deep-links + branding + ACIMChime.caf, all with the Sparkly Edition / Teddy Poppe / CIMS lineage framing intact and zero JTFNews mentions anywhere in this repo. The roadmap table above is the scope contract. Do not expand it mid-phase; do not silently drop items from it either. If a new requirement surfaces, flag it against the roadmap explicitly before acting.

Phase 3.5 is closed. Every code-producing sub-phase from 3.6 forward needs its own plan-mode pass with an approved plan file — parent plans age out quickly. Use parallel Explore agents only when 3+ independent codebase areas need inventory before planning; otherwise plan directly.
