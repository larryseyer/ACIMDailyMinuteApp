# Continuation Prompt — ACIM Daily Minute App

Paste everything below into a fresh Claude Code session started in `/Users/larryseyer/ACIMDailyMinuteApp` to resume where we left off.

---

## TL;DR

Phases 1 (audit), 2 (architecture), 3.1 (scaffolding), 3.2 (SwiftData schema), and **3.3 (service layer)** are **complete and pushed to GitHub** at `https://github.com/larryseyer/ACIMDailyMinuteApp` (branch `main`, HEAD `206b87a`). `Models/`, `Services/`, `Utilities/`, and `ACIMDailyMinuteWatch/WatchDataService.swift` are ACIM-native and reference zero removed JTFNews types. Resume at **Phase 3.4 — rewrite the Views layer** against the new `DailyMinute` / `DailyLesson` / `ArchivedReading` / `Bookmark` models.

**Before any code, fix Xcode target membership** for the three new files added in 3.3 — they exist on disk but were never added to the Xcode project, so the phone target currently cannot resolve them:

| File | Target membership needed |
|---|---|
| `ACIMDailyMinute/Utilities/HashUtility.swift` | ACIMDailyMinute (iOS + macOS) + ACIMDailyMinuteWidget |
| `ACIMDailyMinute/Utilities/PhraseStorage.swift` | ACIMDailyMinute (iOS + macOS) |
| `ACIMDailyMinute/Services/PhraseMatcher.swift` | ACIMDailyMinute (iOS + macOS) |

Also the watch target's `WatchDataService.swift` references `DailyMinute` / `DailyLesson` — those model files need their Watch target membership ticked in Xcode. The old `WatchedTermMatcher.swift` was deleted and its pbxproj entries remain; on first Xcode launch it'll prompt to remove the dangling reference — accept.

The user will do these in Xcode (File Inspector → Target Membership). Ask before doing `./build.sh` runs — membership fixes have to land first.

## Required reading in this order

1. `/Users/larryseyer/.claude/plans/gentle-gathering-pearl.md` — Phase 1 audit (JTFNews ↔ ACIM mapping, feed endpoints, brand tokens)
2. `/Users/larryseyer/.claude/plans/piped-wandering-lobster.md` — Phase 2 architecture plan (authoritative)
3. `/Users/larryseyer/.claude/plans/harmonic-gliding-wilkes.md` — Phase 3.2 schema execution plan
4. `/Users/larryseyer/.claude/plans/snuggly-greeting-manatee.md` — Phase 3.3 service execution plan (just completed; describes every service's new shape + DTO contract)
5. `/Users/larryseyer/ACIMDailyMinuteApp/README.md` — current-state feature overview
6. `/Users/larryseyer/jtfnewsapp/CLAUDE.md` — coding conventions inherited from the reference app

## Persistent memory for this project

A memory system exists at `/Users/larryseyer/.claude/projects/-Users-larryseyer-ACIMDailyMinuteApp/memory/`. Current entries:

- **feedback_model_and_effort.md** — user wants smartest model + max effort; flag `/fast` mode or Sonnet/Haiku fallback at session start.
- **project_test_targets.md** — current dev target is **iPad Simulator iOS 18.1** (and `build.sh` is now wired to `iPad (10th generation)` iOS 18.1). Physical **iPhone 11** testing only when user signals "we're close". Min deployment is still iOS 17.
- **feedback_no_jtfnews_mentions.md** — JTFNews is the reference example. Backend / dev-docs / code-comment mentions are fine (Services/ still cites "JTFNews reference architecture" in comments — that's intentional). **User-facing** mentions (README, LICENSE, in-app text, App Store copy) must be zero.

Read `MEMORY.md` in that folder first; it's the index.

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
| Phrases feature | Renamed "Phrases" (from JTFNews "Watched Terms"); matcher = `PhraseMatcher` |
| Lesson navigation | Allow jump to any lesson 1–365 |
| Audio playback | AVFoundation + MPNowPlayingInfoCenter; relative `audio_url` auto-prefixed with `https://www.acimdailyminute.org` |
| Min deployment | iOS 17 / iPadOS 17 / macOS 14 / watchOS 10 |
| Current dev test target | **iPad (10th generation), iOS 18.1** (wired in `build.sh`) |
| Swift | 6.0 with strict concurrency |
| Dependencies | Zero — Apple frameworks only |
| Watch networking | **Independent**, actor-based, mirrors phone DTOs (per user direction — "whatever JTFNews does"). Watch target reads its own JSON + writes to the shared App Group SwiftData store. |
| Feed RSS namespace | `acim:*` (publisher's `<acim:stream>` = `"minute"` or `"lesson"`; `<acim:source>` reserved, currently unemitted) |
| Podcast endpoints | Two: `/podcast-minute.xml` + `/podcast-lessons.xml` (no combined feed, no `monitor.json`) |
| Source text | **Sparkly Edition**, published by **Teddy Poppe (Theodore Poppe)**, CIMS/Endeavor Academy lineage, US public domain per *Penguin Books USA v. New Christian Church of Full Endeavor* (2003). **NOT the FIP edition** — load-bearing for README/LICENSE. |

## Project state (what's on disk and pushed)

```
/Users/larryseyer/ACIMDailyMinuteApp/
├── .git/                                    origin → github.com/larryseyer/ACIMDailyMinuteApp (main @ 206b87a)
├── README.md                                Sparkly Edition / Teddy Poppe / CIMS / 2003 Penguin case
├── LICENSE                                  CC BY-SA 4.0 scoped to original works
├── CONTINUE.md                              this file
├── ACIMDailyMinute.xcodeproj/               3 targets, Team RR5DY39W4Q, App Group wired
│                                            ⚠ 3 new files NOT yet added to any target:
│                                              Utilities/HashUtility.swift
│                                              Utilities/PhraseStorage.swift
│                                              Services/PhraseMatcher.swift
├── ACIMDailyMinute.entitlements
├── ACIMDailyMinute/
│   ├── App/                                 ⏳ PHASE 3.4 CONTEXT (ContentView still JTFNews-shaped)
│   ├── Models/                              ✅ ACIM schema final (Phase 3.2)
│   │   ├── DailyMinute.swift                @unique segmentHash
│   │   ├── DailyLesson.swift                @unique lessonNumber
│   │   ├── ArchivedReading.swift            @unique lineHash, FTS5 via searchableText
│   │   ├── Bookmark.swift                   composite itemKey "minute:{hash}" | "lesson:{N}"
│   │   ├── Channel.swift
│   │   └── ACIMActivityAttributes.swift     { channel, latestText, publishedDate, lessonNumber? }
│   ├── Services/                            ✅ ACIM service layer final (Phase 3.3)
│   │   ├── DataService.swift                struct + @MainActor persist; DTOs live here
│   │   ├── ArchiveService.swift             @MainActor final class; persists inline archive[]
│   │   ├── FeedService.swift                acim:* namespace parser; FeedItemDTO
│   │   ├── PodcastService.swift             actor; fetchMinuteEpisodes + fetchLessonEpisodes
│   │   ├── AudioManager.swift               @Observable @MainActor; Self.resolve(_:) for relative URLs
│   │   ├── NotificationManager.swift        actor; scheduleDailyReminder(hour:minute:); ACIMChime.caf runtime check
│   │   ├── BackgroundRefreshManager.swift   enum (iOS); checkForNewMinute/Lesson + checkForPhraseMatches
│   │   ├── LiveActivityManager.swift        enum (iOS); startOrUpdate(channel:latestText:publishedDate:lessonNumber:)
│   │   ├── PhraseMatcher.swift              findNewMatches(inMinute:)/(inLesson:); itemKey dedup
│   │   ├── FetchCooldown.swift              dailyMinute/dailyLesson/feed/archive keys
│   │   └── ConnectivityManager.swift        verbatim NWPathMonitor wrapper
│   ├── Views/                               ⏳ PHASE 3.4+ REWRITE TARGET (JTFNews-shaped; compiles broken)
│   ├── Shortcuts/                           ⏳ still JTFNews-shaped
│   ├── Utilities/
│   │   ├── HashUtility.swift                NEW — SHA-256 truncated hex
│   │   ├── PhraseStorage.swift              NEW — UserDefaults-backed phrases + notifiedItemKeys
│   │   ├── PlatformTypography.swift
│   │   ├── ShareTextBuilder.swift
│   │   └── TermExtractor.swift
│   ├── Resources/
│   └── Assets.xcassets
├── ACIMDailyMinuteWidget/                   widget extension
│   └── SharedModelContainer.swift           ✅ schema already final (Phase 3.2)
│                                            ⏳ TimelineProvider + view files still JTFNews-shaped (Phase 3.9)
├── ACIMDailyMinuteWatch/                    watchOS companion
│   ├── WatchDataService.swift               ✅ ACIM-native (Phase 3.3); actor; mirrors phone DTOs
│   ├── WatchContentView.swift               ⏳ JTFNews-shaped (Phase 3.10)
│   ├── WatchStoryRow.swift                  ⏳ JTFNews-shaped (Phase 3.10)
│   └── ACIMDailyMinuteWatchWidget.swift     ⏳ JTFNews-shaped (Phase 3.10)
├── build.sh                                 ✅ iPad (10th generation) iOS 18.1
├── clean.sh, both.sh
├── bu.sh                                    git add/commit/push + Dropbox zip backup
│                                            Dropbox folder missing; zip step fails harmlessly
│                                            Fix: mkdir -p "/Users/larryseyer/Dropbox/Automagic Art/Source Backup/ACIM Daily Minute Backups"
└── run_ralph.sh + bash/                     Ralph agentic loop (unused)
```

## Current transitional state (expected — not a bug)

End-of-Phase-3.3 state: **the service layer compiles on its own** (after the Xcode target-membership fixes above). `Views/`, `Shortcuts/`, `App/ContentView.swift`, and the watch UI files still reference removed JTFNews types (`Story`, `Source`, `Correction`, `StoryCard`, `storyHash`, `factText`, etc.) and produce compile errors. That is the Phase 3.4+ rewrite surface — do not try to "fix" those ahead of their phase.

## Service-layer API surface (what Views will consume)

All signatures already written — see files for docs. Quick reference:

**`DataService` (struct, Sendable):**
- `func fetchDailyMinute(baseURL:) async throws -> DailyMinuteResponse?` — nil if cooldown blocks
- `func fetchDailyLesson(baseURL:) async throws -> DailyLessonResponse?` — nil if cooldown blocks
- `@MainActor static func persistMinute(_ dto:, in context:) throws -> DailyMinuteResponse` — upserts, saves, triggers WidgetCenter reload + LiveActivity when new
- `@MainActor static func persistLesson(_ dto:, in context:) throws -> DailyLessonResponse` — same shape
- `@MainActor static func parseISODate(_:) -> Date?` — shared date parser

**`FeedService` (struct, Sendable):** `fetchFeedItems(baseURL:)` → `[FeedItemDTO]?`; `@MainActor static persistFeed(_:in:)` records cooldown only.

**`PodcastService` (actor):** `fetchMinuteEpisodes(baseURL:force:)` + `fetchLessonEpisodes(...)` → `[PodcastEpisode]` (newest-first). `force:true` uses `.reloadRevalidatingCacheData` for pull-to-refresh.

**`AudioManager` (@Observable @MainActor):** `play(url:title:)` handles relative URLs via `Self.resolve(_:)`. Same `togglePlayback` / `skip(by:)` / `stop` as JTFNews.

**`NotificationManager` (actor, `shared`):** `sendNotification(title:body:identifier:userInfo:)`, `scheduleDailyReminder(hour:minute:)`, `cancelDailyReminder()`. Custom sound has runtime `Bundle.url(forResource:)` check; falls back to `.default` until Phase 5 ships `ACIMChime.caf`.

**`PhraseMatcher` (enum):** `findNewMatches(inMinute:)` / `findNewMatches(inLesson:)` → `[Match]`; `markAllNotified(itemKeys:)`. Dedup via `PhraseStorage.notifiedItemKeys`.

**`LiveActivityManager` (enum, iOS):** `startOrUpdate(channel:latestText:publishedDate:lessonNumber:)` — only call when a genuinely new segment arrives (persist layer already gates this). `endAllActivities()` uses `"Today's reading complete"` final text.

**`BackgroundRefreshManager` (enum, iOS):** `register()`, `scheduleRefresh()`, `performForegroundCheck()` (60s debounced). Reads UserDefaults `notifyNewMinute` / `notifyNewLesson` / `notifyPhraseMatches`.

**UserDefaults keys introduced by Phase 3.3** (Views will wire settings toggles to these):
- `notifyNewMinute`, `notifyNewLesson`, `notifyPhraseMatches` (Bool)
- `notifyLiveActivities` (Bool)
- `useCustomNotificationSound` (Bool)
- `watchedPhrases` (data — PhraseStorage)
- `phraseNotifiedItemKeys` (data — PhraseStorage)
- `phraseMatchBadge` (Int — badge count for tab)
- `lastMinuteSegmentId`, `lastMinuteDate`, `lastLessonId` (seeding baselines)
- `lastFetch` / `lastForegroundCheck` (cooldown internals)

**New `Notification.Name` constants:** `.phrasesTapped`, `.forceMinuteRefresh`, `.forceLessonRefresh`, `.openSettingsRequested`, `.openAboutRequested`. Old `watchedTermsTapped` / `forceStoriesRefresh` are gone.

## Phase 3.4 scope — Views layer rewrite

Per the architecture plan (`piped-wandering-lobster.md` §8), Phase 3.4 stands up the **Today tab** — the first user-visible surface. That means:

1. `App/ContentView.swift` — switch from JTFNews 4-tab (Stories/Digest/Saved/Settings) to ACIM 5-tab (Today / Lessons / Listen / Archive / Saved). Settings via sheet.
2. `App/ACIMDailyMinuteApp.swift` — wire `DataService`, `FeedService`, `PodcastService`, `AudioManager`, `NotificationManager.shared.setupDelegate()`, `BackgroundRefreshManager.register()` into the App scene. Inject `AudioManager` as `@State` + `.environment(_:)` so MiniPlayer works across tabs.
3. **Today tab only for 3.4** — two cards (Daily Minute, Daily Lesson), pull-to-refresh, offline cache fallback, share button, bookmark button, inline audio chip. Lessons/Listen/Archive/Saved are empty placeholders until 3.5+.
4. Delete the 15+ JTFNews-shaped view files (`StoriesView.swift`, `StoryCard.swift`, `StoryDetailView.swift`, `SourceDetailView.swift`, `SourceCard.swift`, `WatchedView.swift`, `WatchedTermsView.swift`, etc.) as you replace them. Don't preserve dead code.

Grep pattern for removable view files:
```
Grep "Story|Source|Correction|WatchedTerm" ACIMDailyMinute/Views
```

Expect this phase to be **larger than 3.3** — Views are where user experience lives. Plan mode + multiple Explore passes warranted.

### Today-tab data flow

```
View.task {
    FetchCooldown.reset(FetchCooldownKey.dailyMinute, FetchCooldownKey.dailyLesson)  // cold-start force
    if let dto = try await dataService.fetchDailyMinute() {
        try DataService.persistMinute(dto, in: modelContext)
    }
    if let dto = try await dataService.fetchDailyLesson() {
        try DataService.persistLesson(dto, in: modelContext)
    }
}
@Query(sort: \DailyMinute.publishedAt, order: .reverse) var minutes: [DailyMinute]
@Query(sort: \DailyLesson.publishedAt, order: .reverse) var lessons: [DailyLesson]
// render minutes.first and lessons.first; fallback to "Offline — showing last cached" if both arrays empty after fetch failed
```

## Ground rules

- **Swift & SwiftUI only.** No UIKit except the existing WKWebView for YouTube embed. No third-party SDKs.
- **Swift 6 strict concurrency.** `@MainActor` on all SwiftData writes. Use `@Observable` for UI state, `actor` for networking services.
- **No `xcodebuild` runs from Claude.** User verifies in Xcode. For quick sim checks they run `./build.sh` (now iPad 10th-gen iOS 18.1).
- **Read JTFNews freely.** `/Users/larryseyer/jtfnewsapp/JTFNews/Views/` is the view pattern library. Especially:
  - `/Users/larryseyer/jtfnewsapp/JTFNews/Views/Stories/StoriesView.swift` (today-equivalent)
  - `/Users/larryseyer/jtfnewsapp/JTFNews/Views/MiniPlayer*.swift`
  - `/Users/larryseyer/jtfnewsapp/JTFNews/Views/Settings/SettingsView.swift`
- **User-facing JTFNews mentions are forbidden.** Before every commit, grep user-facing surfaces for `JTF|jtf|jtfnews`: `README.md`, `LICENSE`, all SwiftUI `Text(...)` strings, onboarding, about screens, App Store copy (Phase 5+). Zero matches required. Backend / code comments exempt.
- **Commit per logical chunk** via `./bu.sh "message"` (git add/commit/push + Dropbox zip). Dropbox folder missing; zip step fails harmlessly.
- **Zero placeholder data.** All content from `https://www.acimdailyminute.org/*`. Offline fallback = last-known-good cache in SwiftData.
- **Sparkly Edition language is non-negotiable** — never let docs drift to "FIP" framing.
- **Watch target uses its own networking** (Phase 3.3 decision, per user direction). The App Group SwiftData store is read+write from both phone and watch.
- **Confirm before actions with blast radius** — pushing, force-operations, deleting branches. Per-chunk commits via `./bu.sh` pre-authorized once confirmed in-session.

## Phase 3 roadmap (remaining)

| Sub-phase | Status | Goal |
|---|---|---|
| 3.1 | ✅ | Xcode project, 3 targets, entitlements, App Group |
| 3.2 | ✅ | SwiftData schema + 3 Schema declarations |
| 3.3 | ✅ | 11 services + WatchDataService rewritten for ACIM models |
| 3.4 | ⏭ NEXT | Today tab + App wiring + tab skeleton; delete dead JTFNews view files |
| 3.5 | | Lessons tab (workbook browser + "Jump to Lesson N") |
| 3.6 | | Listen tab (podcast feed, AVFoundation playback, MiniPlayer, YouTube embed) |
| 3.7 | | Archive tab (calendar + FTS5 search over `ArchivedReading.searchableText`) |
| 3.8 | | Saved + Settings (Phrases editor, notification toggles) + Onboarding |
| 3.9 | | Widget target (3 families + Live Activity UI) |
| 3.10 | | Watch companion UI + 3 complications |
| 4 | | Feature parity checklist verification |
| 5 | | Branding + asset catalog + app icons + ACIMChime.caf |

## First move for the new session

1. Read the 6 required-reading files above.
2. Read the memory entries at `/Users/larryseyer/.claude/projects/-Users-larryseyer-ACIMDailyMinuteApp/memory/MEMORY.md`.
3. Confirm active model is Claude Opus 4.6 and `/fast` is OFF. Flag either if not.
4. Ask the user to confirm they've added target membership in Xcode for the three new files (HashUtility.swift, PhraseStorage.swift, PhraseMatcher.swift) and ticked Watch target membership for the Models. **Do not run `./build.sh` until they confirm.** Once confirmed, a fresh `./build.sh` run verifies Services/ compiles before the Views rewrite begins.
5. Enter plan mode for Phase 3.4. Use parallel Explore agents:
   - JTFNews Views inventory (focus on `Views/Stories/`, `Views/MiniPlayer*`, `App/ContentView.swift`, `App/JTFNewsApp.swift`)
   - Current ACIM Views inventory (catalog the dead files to delete)
6. Launch Plan agent(s) to design: (a) App wiring, (b) 5-tab shell, (c) Today tab components (Minute card + Lesson card + MiniPlayer), (d) view-file deletion list.
7. Present plan via ExitPlanMode.
8. On approval, execute Phase 3.4 in 2–3 logical chunks, committing each via `./bu.sh "Phase 3.4{a,b,c}: <chunk>"`.

Do not skip plan mode — the Views layer touches every user-visible surface and has the biggest blast radius of any phase so far. Designing the tab shell + MiniPlayer + today-cards contract up-front prevents rework when Lessons/Listen/Archive lands in 3.5–3.7.
