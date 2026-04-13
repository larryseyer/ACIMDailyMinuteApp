# Continuation Prompt — ACIM Daily Minute App

Paste into a fresh Claude Code session started in `/Users/larryseyer/ACIMDailyMinuteApp` to resume where we left off.

---

## TL;DR

Phases 1 (audit), 2 (architecture), 3.1 (scaffolding), 3.2 (SwiftData schema), 3.3 (service layer), and **3.4 (Today tab + app wiring + 5-tab shell)** are complete and pushed to `https://github.com/larryseyer/ACIMDailyMinuteApp` (`main @ 74ff6ac`, end of Phase 3.4 scrub). The iOS target compiles clean. The Widget target and Watch UI files still use the old schema and remain broken by design — they are Phase 3.9 and 3.10 scope.

Resume at **Phase 3.5 — Lessons tab** (workbook browser with "Jump to Lesson N").

## Required reading (this order)

1. `/Users/larryseyer/.claude/plans/gentle-gathering-pearl.md` — Phase 1 audit
2. `/Users/larryseyer/.claude/plans/piped-wandering-lobster.md` — Phase 2 architecture (authoritative)
3. `/Users/larryseyer/.claude/plans/harmonic-gliding-wilkes.md` — Phase 3.2 schema execution
4. `/Users/larryseyer/.claude/plans/snuggly-greeting-manatee.md` — Phase 3.3 service execution
5. `/Users/larryseyer/.claude/plans/fuzzy-booping-scone.md` — Phase 3.4 execution (Today tab)
6. `/Users/larryseyer/ACIMDailyMinuteApp/README.md` — current feature overview

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
│   │   ├── Placeholders/                    ✅ Phase 3.4 stubs
│   │   │   └── LessonsPlaceholderView.swift
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

- **iOS main app target**: compiles clean.
- **macOS**: code-signing only (no provisioning profile in CI). Code compiles.
- **Widget + Watch UI files**: still use old schema. Broken by design until Phases 3.9 / 3.10. The iOS app scheme builds green independently.

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

## What's live at end of Phase 3.4

- Today tab: live Daily Minute + Daily Lesson fetched from `https://www.acimdailyminute.org/daily-minute.json` and `/daily-lesson.json`. Pull-to-refresh resets cooldowns and re-fetches. Offline → last cached reading renders with a banner.
- Bookmark toggle on each card → writes `Bookmark` row with `itemKey "minute:{hash}"` or `"lesson:{N}"`.
- ShareLink → `ShareTextBuilder.minuteShareText` / `.lessonShareText`.
- Listen chip on each card → calls `AudioManager.play(url:title:)`. MiniPlayer overlay is reserved in `ContentView` but hidden until audio starts.
- Settings sheet opens via toolbar button or ⌘, (macOS). Content is a "Phase 3.8" placeholder.
- 4 other tabs (Lessons / Listen / Archive / Saved) render "coming soon" placeholders.
- macOS About sheet (⌘ menu → About) renders the custom AboutView.

## Phase 3.5 scope — Lessons tab

Per `piped-wandering-lobster.md` §8:

1. `Views/Lessons/LessonsView.swift` (replaces `LessonsPlaceholderView`) — a browser for all 365 workbook lessons.
2. `Views/Lessons/LessonRow.swift` — compact row (lesson number + title + date when read + bookmark indicator).
3. "Jump to Lesson N" — toolbar or search-field affordance; navigates to a `LessonDetailView` reusing the `DailyLessonCard` chrome.
4. Data source: the rolling archive array embedded in `/daily-lesson.json` is only the most recent N; Phase 3.5 will need to decide whether to drive the browser off `ArchivedReading` rows persisted so far, or to add a full-index fetch. Check `DailyLessonResponse.total_lessons` and `DailyLessonResponse.archive[]` shape before designing.

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
| 3.5 | ⏭ NEXT | Lessons tab (workbook browser + "Jump to Lesson N") |
| 3.6 | | Listen tab (podcast feed, AVFoundation playback, MiniPlayer, YouTube embed) |
| 3.7 | | Archive tab (calendar + FTS5 search over `ArchivedReading.searchableText`) |
| 3.8 | | Saved + Settings (Phrases editor, notification toggles) + Onboarding |
| 3.9 | | Widget target (3 families + Live Activity UI) |
| 3.10 | | Watch companion UI + 3 complications |
| 4 | | Feature parity checklist verification |
| 5 | | Branding + asset catalog + app icons + ACIMChime.caf |

## First move for the new session

1. Read the 6 required-reading files above.
2. Read the memory index at `/Users/larryseyer/.claude/projects/-Users-larryseyer-ACIMDailyMinuteApp/memory/MEMORY.md` and every file it points to.
3. Confirm active model is Claude Opus 4.6 and `/fast` is OFF. Flag either if not.
4. Run `./build.sh` to verify the iOS target is still green before touching anything.
5. Enter plan mode for Phase 3.5. Use parallel Explore agents:
   - Current ACIM Models/Services inventory (for API surface the Lessons tab will consume)
   - Reference-app Views inventory (pattern research only — see `reference_app_path.md` memory entry)
6. Launch Plan agent(s) to design the Lessons browser and "Jump to Lesson N" flow.
7. Present plan via ExitPlanMode.
8. On approval, execute Phase 3.5 in 2–3 logical chunks, committing each via `./bu.sh "Phase 3.5{a,b,c}: <chunk>"`.

Do not skip plan mode — Phase 3.5 needs a designed decision about data source (inline archive vs. full index fetch) before any code.
