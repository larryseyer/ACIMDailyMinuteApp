# Continuation Prompt — ACIM Daily Minute App

Paste into a fresh Claude Code session started in `/Users/larryseyer/ACIMDailyMinuteApp` to resume where we left off.

---

## TL;DR

Phases 1 (audit), 2 (architecture), 3.1 (scaffolding), 3.2 (SwiftData schema), 3.3 (service layer), 3.4 (Today tab + app wiring + 5-tab shell), 3.5-pre (pbxproj repair + build.sh hardening), 3.5a (Lessons tab spine — 1–365 list + row + metadata merge), 3.5b (`LessonDetailView` with Full / Metadata-only / Absent states + `.navigationDestination(for: Int.self)`), 3.5c (Lessons `.searchable` filter + Jump-to-N sheet with 1–365 validation), 3.6 (Listen tab — segmented Minute/Lessons podcast feed + YouTube embed card + MiniPlayer overlay wired through existing `AudioManager`), and **3.7 (Archive tab — graphical `DatePicker` on iOS / `MacCalendarView` on macOS + `.searchable` substring filter over `ArchivedReading.searchableText` + `NavigationStack(path:)` with `.navigationDestination(for: String.self)` to a per-date detail view rendering a shared `ArchivedReadingCard` for Minute + Lesson rows; pull-to-refresh re-invokes the daily fetches which top up the inline archive as a side effect)** are complete and pushed to `https://github.com/larryseyer/ACIMDailyMinuteApp` (`main @ a92d363`). The iOS main-app target compiles clean against iPad 10th gen / iOS 18.1 (0 errors, 0 warnings in main-target files; 8 pre-existing Widget errors are expected and deferred to Phase 3.9). The Widget target and Watch UI files still use the old schema and remain broken **by design** — they are Phase 3.9 and 3.10 scope.

Resume at **Phase 3.8 — Saved tab + Settings sheet + Onboarding reactivation** (Phrases editor, notification toggles, daily reminder opt-in, deep-link registration). No approved plan exists for 3.8 yet — **enter plan mode** at the start of that session to design it.

Phases 3.5 (a/b/c), 3.6, and 3.7 are now **complete and closed**.

**Correction vs. prior CONTINUE.md framing:** earlier versions said the archive uses "FTS5 via `searchableText`." That was aspirational and inaccurate. `ArchivedReading.searchableText` is a denormalized plain `String` column (concatenation of `text + " " + sourceReference` for minutes, `title` for lessons) — no FTS5 virtual table, no ranking. 3.7 implemented honest in-memory substring search via `localizedStandardContains`, mirroring the `FilteredLessonsList` pattern. Archive size is bounded (rolling ~30-day window × 2 channels × months of accumulation), so in-memory filtering is adequate and matches the rest of the app's `@Query` + Swift-filter style. No FTS5 migration is planned or needed.

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
10. `/Users/larryseyer/.claude/plans/eager-jumping-shell.md` — Phase 3.7 plan (Archive tab; completed at `a92d363`)
11. `/Users/larryseyer/ACIMDailyMinuteApp/README.md` — current feature overview

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
│   │   ├── ArchivedReading.swift            @unique lineHash; searchableText is a denormalized String (NOT FTS5)
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
│   │   ├── Archive/                         ✅ Phase 3.7
│   │   │   ├── ArchiveView.swift            NavigationStack(path:) + @Query all readings + calendar mode / search mode branch + .refreshable
│   │   │   ├── ArchiveDateDetailView.swift  parameterized @Query(dateString == N); renders ArchivedReadingCard per row
│   │   │   ├── ArchivedReadingCard.swift    shared Minute/Lesson card; dispatches on channel; bookmark + share + Listen
│   │   │   └── MacCalendarView.swift        macOS-only iOS-style calendar (unchanged from scaffolding)
│   │   ├── Saved/                           (stub — Phase 3.8)
│   │   ├── Settings/                        (stub sheet — Phase 3.8)
│   │   ├── Onboarding/                      (dead code; wired back in 3.8)
│   │   └── AboutView.swift                  macOS About sheet
│   ├── Shortcuts/
│   │   └── GetTodaysReadingIntent.swift       Siri Shortcut — fetches latest DailyMinute via SwiftData
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

## What's live at end of Phase 3.7 (`a92d363`)

- Today tab: live Daily Minute + Daily Lesson fetched from `https://www.acimdailyminute.org/daily-minute.json` and `/daily-lesson.json`. Pull-to-refresh resets cooldowns and re-fetches. Offline → last cached reading renders with a banner.
- **Lessons tab: 1–365 spine renders + tap navigates to detail.** Two `@Query`s (`DailyLesson` + `ArchivedReading` where `channel == "daily-lesson"`) merged into `[Int: LessonMeta]` via `.reduce(into:)`. `DailyLesson` wins on conflict. Today's lesson shows real title + date; recent archive rows show title; everything else shows "Not yet read." Bookmark dot renders for any lesson whose `Bookmark.itemKey` starts with `lesson:`.
- **Lessons tab: `.searchable` filter + Jump-to-N sheet (3.5c).** Search is exact-match on integer queries (`"47"` → only lesson 47) and `localizedStandardContains` on title for any query with non-digits (`"trust"` → all lessons whose known title contains "trust"). Empty query returns the full 1–365 spine. Toolbar "Jump" button opens `JumpToLessonSheet`, a medium-detent sheet with a `numberPad`-keyboard `TextField`; Go is disabled while the trimmed input isn't a valid 1–365 integer; on submit it appends N to the root `NavigationPath` and dismisses. The filtered list is encapsulated in a private `FilteredLessonsList` subview so `@Query` re-evaluation stays isolated from `searchText` churn.
- **Lesson detail renders the right state for any N in 1–365.** `LessonDetailView` builds two parameterized `@Query`s in `init` (`DailyLesson.lessonNumber == n`; `ArchivedReading.channel == "daily-lesson" && lessonNumber == n`). Full state: ScrollView + detail-scale Georgia (24 title / 19 body) + bookmark + ShareLink + Listen chip. Metadata-only: lesson N + `archive.text`-as-title + dateString + audio chip if present + "Full text available once today's lesson fetches this entry." Absent: `ContentUnavailableView` + Refresh button that calls `DataService.fetchDailyLesson` / `persistLesson` (honest copy when today's lesson ≠ requested N or cooldown blocks).
- Bookmark toggle on each Today card → writes `Bookmark` row with `itemKey "minute:{hash}"` or `"lesson:{N}"`.
- ShareLink → `ShareTextBuilder.minuteShareText` / `.lessonShareText`.
- Listen chip on each card → calls `AudioManager.play(url:title:)`. MiniPlayer overlay in `ContentView` becomes visible once `audioManager.hasActiveAudio == true` (hidden on the Listen tab itself so the row's own waveform indicator is canonical there).
- **Archive tab (3.7): calendar + substring search + per-date detail.** Calendar mode (empty `.searchable` query): iOS renders `DatePicker(.graphical)` bounded by `earliestDate...today` (earliest computed from `@Query` min `timestamp` / parsed `dateString`; fallback = today−1yr), macOS renders the pre-existing `MacCalendarView`. Below the calendar: a tappable card showing the selected date's long-format string + a hint ("Open readings" vs. "No readings archived on this date"); tap appends the `YYYY-MM-DD` string to the `NavigationPath`. Search mode (non-empty query): `ArchiveSearchResultsList` (private subview, mirrors `FilteredLessonsList`) filters in memory — queries matching `^\d{4}-\d{2}-\d{2}$` → exact `dateString` match, else `searchableText.localizedStandardContains(query)`. Results sorted `dateString` DESC, then `channel` DESC (so `"daily-minute"` appears before `"daily-lesson"` within a date). Each row = label ("Daily Minute" / "Lesson N") + date + 120-char snippet (newlines collapsed). Tap appends that row's `dateString` to the path. `.navigationDestination(for: String.self)` lands on `ArchiveDateDetailView(dateString:)`, which uses a parameterized `@Query<ArchivedReading>` with `#Predicate { $0.dateString == dateString }` and renders one `ArchivedReadingCard` per row. The shared card dispatches on `reading.channel`: minute variant renders `reading.text` in Georgia 18 + italic `sourceReference`; lesson variant renders the title (stored in `reading.text` per `ArchiveService.persistInlineLessons`) in Georgia 20 semibold. Bookmark `itemKey` is `"minute:{lineHash}"` for archive minutes (**known aliasing gap vs. Today tab's `"minute:{segmentHash}"` — different hash schemes; reconciliation deferred to 3.8 Saved tab**) and `"lesson:{N}"` for archive lessons (aliases cleanly). Pull-to-refresh resets the daily-Minute and daily-Lesson cooldowns and re-fetches — the provider embeds the rolling archive inline with each daily JSON, so this tops up the archive as a side effect (no separate archive endpoint exists; `FetchCooldownKey.archive` remains unused scaffolding). Offline: cached rows still render + search still works; refresh fails silently.
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
| 3.7 | ✅ | Archive tab (calendar + substring search over `ArchivedReading.searchableText` + per-date detail + refresh) (`a92d363`) |
| 3.8 | ⏭ NEXT | Saved + Settings (Phrases editor, notification toggles) + Onboarding |
| 3.9 | | Widget target (3 families + Live Activity UI) |
| 3.10 | | Watch companion UI + 3 complications |
| 4 | | Feature parity checklist verification |
| 5 | | Branding + asset catalog + app icons + ACIMChime.caf |

## First move for the new session

1. Read the 10 required-reading files above. Plans traverse in **timeline order** starting at `gentle-gathering-pearl.md`; OTTO-prefixed plans in `~/.claude/plans/` belong to a separate app and are out of scope here.
2. Read the memory index at `/Users/larryseyer/.claude/projects/-Users-larryseyer-ACIMDailyMinuteApp/memory/MEMORY.md` and every file it points to. Load-bearing rules locked during 3.5c: (a) no TODOs/FIXMEs anywhere — pick a sensible default and fully implement; (b) planning is my job — enter plan mode for every code-producing sub-phase, even when a parent plan is pre-approved.
3. Confirm active model is Claude Opus 4.6 and `/fast` is OFF. Flag either if not.
4. Verify the iOS main target is still green at `475846c` (main-target-only check shown in **Build state** above, using the `id=<UUID>` destination form — the `name=` form is ambiguous because multiple iPad 10th-gen sims on iOS 18.1 are installed). Do NOT require the full `./build.sh` to pass — Widget + Watch targets are broken by design until Phases 3.9 / 3.10.
5. **Enter plan mode for Phase 3.8 — Saved tab + Settings sheet + Onboarding reactivation.** No approved plan exists yet. Scope:
   - **Saved tab** (tag 4 in `ContentView`; currently a stub). Renders every `Bookmark` row as a list. Resolve `itemKey` → content:
     - `"minute:{hash}"` — look up `DailyMinute` by `segmentHash`; if miss, look up `ArchivedReading` by `lineHash`. (Known aliasing gap locked into Phase 3.7: a minute bookmarked from Today and from Archive creates two rows; 3.8 should either (a) render them side-by-side with a de-dup hint, or (b) reconcile at bookmark-creation time by preferring `segmentHash` when available. Lock the decision in the plan.)
     - `"lesson:{N}"` — look up `DailyLesson` by `lessonNumber`; if miss, look up `ArchivedReading` where `channel == "daily-lesson" && lessonNumber == N`. Aliases cleanly between Today/Lessons/Archive.
     - Tap → push the appropriate detail view (`LessonDetailView(lessonNumber:)` for lessons; a new or reused minute-detail view for minutes). Swipe-to-delete removes the bookmark.
   - **Settings sheet** (`Views/Settings/SettingsView.swift` — stub exists per pbxproj `AA000001025`). Content:
     - Phrases editor: add/remove entries in `PhraseStorage.watchedPhrases` (`Utilities/PhraseStorage.swift`). Dedup, trim, validate non-empty. Scroll-to-add pattern.
     - Notification toggles (UserDefaults keys already registered in `ACIMDailyMinuteApp.init`): `notifyNewMinute`, `notifyNewLesson`, `notifyPhraseMatches`, `notifyLiveActivities`, `useCustomNotificationSound`.
     - Daily reminder: `DatePicker("Reminder time", selection: ..., displayedComponents: .hourAndMinute)` wired to `NotificationManager.scheduleDailyReminder(hour:minute:)` / `cancelDailyReminder()`.
     - "Test notification" button → `NotificationManager.sendNotification(...)` with fixed test copy.
   - **Onboarding** — reactivate the existing `Views/Onboarding/OnboardingView.swift` (pbxproj `AA000001041`, currently dead code). Show on first launch via a UserDefaults flag (`hasSeenOnboarding` — add to the init registry). One-screen intro: Sparkly Edition / Teddy Poppe / CIMS lineage framing + "Enable daily reminder?" → routes to Settings' reminder toggle. Sparkly Edition language is non-negotiable; do **not** drift to FIP.
   - **Deep links** — URL scheme `acimdailyminute://` already reserved. Wire `.onOpenURL { url in ... }` on the root to route:
     - `acimdailyminute://today` → select Today tab.
     - `acimdailyminute://lesson/47` → select Lessons tab + `path.append(47)`.
     - `acimdailyminute://archive/2026-04-10` → select Archive tab + `path.append("2026-04-10")`.
     - `acimdailyminute://saved` → select Saved tab.
     - Invalid URLs: no-op, log to console only.
   - **Shortcuts** — the `Shortcuts/GetTodaysReadingIntent.swift` stub needs a real implementation or a rename + new intent. Coming-soon dialog is a placeholder from scaffolding.
   - Files likely new: `Views/Saved/SavedView.swift` (may exist as stub per `AA000001058` — verify), `Views/Saved/BookmarkRow.swift`, `Views/Settings/PhrasesEditorView.swift`, possibly `Views/Settings/NotificationToggleRow.swift`. Modify `SettingsView.swift`, `OnboardingView.swift`, `ContentView.swift` (deep-link dispatch + onboarding sheet), `ACIMDailyMinuteApp.swift` (register `hasSeenOnboarding` default).
   - Pre-allocate pbxproj IDs in the plan. Next free range after 3.7: buildFiles `AA000001219+`, fileRefs `AA000002219+`. Saved PBXGroup and Settings PBXGroup likely already exist — verify first via grep.
   - Lock all design decisions in the plan — no TODOs allowed in committed code.
6. After 3.8 ships, proceed to **Phase 3.9 — Widget target** (3 families + Live Activity UI). That's a much bigger pbxproj pass because the Widget target itself uses the old schema right now.

## End-goal reminder

Phase 3.5 is **one of eleven** remaining sub-phases. Full parity remains the bar: Today + Lessons + Listen + Archive + Saved + Settings + Onboarding + Widget + Watch + Shortcuts/deep-links + branding + ACIMChime.caf, all with the Sparkly Edition / Teddy Poppe / CIMS lineage framing intact and zero JTFNews mentions anywhere in this repo. The roadmap table above is the scope contract. Do not expand it mid-phase; do not silently drop items from it either. If a new requirement surfaces, flag it against the roadmap explicitly before acting.

Phase 3.5 is closed. Every code-producing sub-phase from 3.6 forward needs its own plan-mode pass with an approved plan file — parent plans age out quickly. Use parallel Explore agents only when 3+ independent codebase areas need inventory before planning; otherwise plan directly.
