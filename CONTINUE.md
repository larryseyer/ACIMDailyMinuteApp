# Continuation Prompt — ACIM Daily Minute App

Paste everything below into a fresh Claude Code session started in `/Users/larryseyer/ACIMDailyMinuteApp` to resume where we left off.

---

## TL;DR

Phases 1 (audit), 2 (architecture), 3.1 (scaffolding), and **3.2 (SwiftData schema)** are **complete and pushed to GitHub** at `https://github.com/larryseyer/ACIMDailyMinuteApp` (branch `main`, HEAD near `a6c5547`). Resume at **Phase 3.3 — rewrite the 11 services** to consume the new `DailyMinute` / `DailyLesson` / `ArchivedReading` / `Bookmark` / `Channel` models. Do NOT regenerate the Xcode project or the SwiftData schema — both are final.

## Required reading in this order

1. `/Users/larryseyer/.claude/plans/gentle-gathering-pearl.md` — Phase 1 audit (JTFNews ↔ ACIM mapping, feed endpoints, brand tokens)
2. `/Users/larryseyer/.claude/plans/piped-wandering-lobster.md` — Phase 2 architecture plan (approved, authoritative)
3. `/Users/larryseyer/.claude/plans/harmonic-gliding-wilkes.md` — Phase 3.2 execution plan (just completed; contains UUID map and schema details)
4. `/Users/larryseyer/ACIMDailyMinuteApp/README.md` — current-state feature overview
5. `/Users/larryseyer/jtfnewsapp/CLAUDE.md` — coding conventions inherited from the reference app

## Persistent memory for this project

A memory system exists at `/Users/larryseyer/.claude/projects/-Users-larryseyer-ACIMDailyMinuteApp/memory/`. Current entries:

- **feedback_model_and_effort.md** — user wants smartest model + max effort; flag `/fast` mode or Sonnet/Haiku fallback at session start.
- **project_test_targets.md** — current dev-testing target is **iPad Simulator running iOS 18.1**. Physical **iPhone 11** testing only when user signals "we're close". Min deployment target is still iOS 17 (architecture plan); iPad 18.1 is just the *current* dev device.
- **feedback_no_jtfnews_mentions.md** — JTFNews is the reference example this app is modeled on. Backend / dev-docs mentions are fine. **User-facing** mentions (README, LICENSE, any in-app text, App Store copy) must be scrubbed. Don't over-scrub backend code or handoff docs.

Read `MEMORY.md` in that folder first; it's the index.

## Decisions already locked (do not re-ask)

| Decision | Value |
|---|---|
| Apple Developer Team ID | `RR5DY39W4Q` (inherited from JTFNews reference) |
| Bundle ID prefix | `com.larryseyer.acimdailyminute` |
| App Group | `group.com.larryseyer.acimdailyminute` |
| BG task identifier | `com.larryseyer.acimdailyminute.refresh` |
| SwiftData store filename | `ACIMDailyMinute.sqlite` |
| URL scheme | `acimdailyminute://` |
| Daily reminder default | 7:00 AM local (opt-in) |
| Watched phrases feature | Keep, rebranded "Watched Phrases" |
| Lesson navigation | Allow jump to any lesson 1–365 |
| Audio playback | v1 (AVFoundation + MPNowPlayingInfoCenter) |
| App icon source | Extract from `/Volumes/MacLive/Users/larryseyer/acim-daily-minute/images/` in Phase 5 |
| Min deployment | iOS 17 / iPadOS 17 / macOS 14 / watchOS 10 |
| Current dev test target | **iPad Simulator, iOS 18.1** |
| Swift | 6.0 with strict concurrency |
| Dependencies | Zero — Apple frameworks only |
| Source text | **Sparkly Edition**, published by **Teddy Poppe (Theodore Poppe)**, CIMS/Endeavor Academy lineage, US public domain per *Penguin Books USA v. New Christian Church of Full Endeavor* (2003). **NOT the FIP edition** — this is load-bearing for the README/LICENSE language, do not let any docs slip back to "FIP" framing. |

## Project state (what's on disk and pushed)

```
/Users/larryseyer/ACIMDailyMinuteApp/
├── .git/                                    origin → github.com/larryseyer/ACIMDailyMinuteApp
├── README.md                                Sparkly Edition / Teddy Poppe / CIMS / 2003 Penguin case
├── LICENSE                                  CC BY-SA 4.0 scoped to original works
├── CONTINUE.md                              this file
├── ACIMDailyMinute.xcodeproj/               3 targets, Team RR5DY39W4Q, App Group wired
├── ACIMDailyMinute.entitlements
├── ACIMDailyMinute/
│   ├── App/                                 (transitional JTFNews-derived internals, compiles broken)
│   ├── Models/                              ✅ PHASE 3.2 DONE — ACIM schema final
│   │   ├── DailyMinute.swift                NEW — @Attribute(.unique) segmentHash
│   │   ├── DailyLesson.swift                NEW — @Attribute(.unique) lessonNumber
│   │   ├── ArchivedReading.swift            NEW — @Attribute(.unique) lineHash, FTS5 via searchableText
│   │   ├── Bookmark.swift                   REWRITTEN — composite itemKey "minute:{hash}"/"lesson:{N}"
│   │   ├── Channel.swift                    (untouched — shape was already correct)
│   │   └── ACIMActivityAttributes.swift     REWRITTEN — new ContentState { channel, latestText, publishedDate, lessonNumber? }
│   ├── Services/                            ⏳ PHASE 3.3 REWRITE TARGET (still JTFNews-shaped)
│   ├── Views/                               ⏳ PHASE 3.4+ REWRITE TARGET (still JTFNews-shaped)
│   └── Utilities/, Resources/, Assets.xcassets
├── ACIMDailyMinuteWidget/                   widget extension (Schema updated, rest transitional)
├── ACIMDailyMinuteWatch/                    watchOS companion (Schema updated, rest transitional)
├── build.sh                                 ⚠ currently targets iPhone 16 sim — update to iPad sim iOS 18.1 to match current dev target
├── clean.sh, both.sh
├── bu.sh                                    git add/commit/push + Dropbox zip backup
│                                            NOTE: Dropbox folder doesn't exist yet; zip step fails harmlessly
│                                            Fix: mkdir -p "/Users/larryseyer/Dropbox/Automagic Art/Source Backup/ACIM Daily Minute Backups"
└── run_ralph.sh + bash/                     Ralph agentic loop (unused so far)
```

## Current transitional state (expected — not a bug)

End-of-Phase-3.2 state is **deliberately non-compiling**. The Models folder + Schema declarations are final, but `Views/` and `Services/` still reference removed types (`Story`, `Source`, `Correction`, `ArchivedStory`). LSP reports ~15 "Cannot find X in scope" errors across `ContentView`, `StoriesView`, `DataService`, etc. Phase 3.3 (services) resolves the `Services/` errors; Phase 3.4+ (views) resolves the `Views/` errors. Do not try to "fix" these errors ahead of their phase — the rewrite path is the fix.

## Resume at Phase 3.3 — service layer rewrite

Per the architecture plan (`piped-wandering-lobster.md` §7), rewrite these 11 services + 1 container, mirroring the JTFNews reference app's public API shape so Phase 3.4+ view-layer patterns port directly.

| # | File | JTFNews reference path | New behavior |
|---|---|---|---|
| 1 | `DataService.swift` | `/Users/larryseyer/jtfnewsapp/JTFNews/Services/DataService.swift` | Two-phase fetch+persist. `fetchDailyMinute()` + `fetchDailyLesson()` returning DTO arrays; `@MainActor persistMinutes/persistLessons` upsert by `segmentHash` / `lessonNumber`. Endpoints: `/daily-minute.json`, `/daily-lesson.json`. |
| 2 | `FetchCooldown.swift` | `jtfnewsapp/JTFNews/Services/FetchCooldown.swift` | Copy verbatim. Keys `dailyMinute`, `dailyLesson`, `feed`, `archive`. |
| 3 | `BackgroundRefreshManager.swift` | `jtfnewsapp/JTFNews/Services/BackgroundRefreshManager.swift` | Task ID `com.larryseyer.acimdailyminute.refresh`; 60s foreground debounce. |
| 4 | `NotificationManager.swift` | `jtfnewsapp/JTFNews/Services/NotificationManager.swift` | Daily reminder default **7:00 AM local** (opt-in). Custom sound `ACIMChime.caf` (Phase 5 asset; fall back to default). |
| 5 | `ArchiveService.swift` | `jtfnewsapp/JTFNews/Services/ArchiveService.swift` | Parse rolling `archive[]` from each channel JSON; insert `ArchivedReading` rows deduplicated by `lineHash`. |
| 6 | `FeedService.swift` | `jtfnewsapp/JTFNews/Services/FeedService.swift` | Parse `/feed.xml` (combined RSS); `acim:*` extensions. The current ACIM `FeedService.swift` still parses the JTFNews `jtf:source` schema — fully rewrite it. |
| 7 | `PodcastService.swift` | `jtfnewsapp/JTFNews/Services/PodcastService.swift` | Parse `/podcast-minute.xml` + `/podcast-lessons.xml`. |
| 8 | `AudioManager.swift` | `jtfnewsapp/JTFNews/Services/AudioManager.swift` | `@Observable @MainActor` AVPlayer wrapper. Resolve relative `audio_url` against `https://www.acimdailyminute.org/`. |
| 9 | `LiveActivityManager.swift` | `jtfnewsapp/JTFNews/Services/LiveActivityManager.swift` | Uses the new `ACIMActivityAttributes.ContentState { channel, latestText, publishedDate, lessonNumber? }`. 5-min auto-dismiss. Gated by UserDefaults `notifyLiveActivities`. |
| 10 | `ConnectivityManager.swift` | `jtfnewsapp/JTFNews/Services/ConnectivityManager.swift` | Copy verbatim. `NWPathMonitor` wrapper. |
| 11 | `PhraseMatcher.swift` | `jtfnewsapp/JTFNews/Services/WatchedTermMatcher.swift` | Rename `WatchedTermMatcher` → `PhraseMatcher`. Match against `DailyMinute.text` and `DailyLesson.text`; fire local notification on match. |
| container | `SharedModelContainer.swift` (widget) | `jtfnewsapp/JTFNewsWidget/SharedModelContainer.swift` | Already updated to new Schema in Phase 3.2. Re-check after other service rewrites to confirm no drift. |

Drop these JTFNews-only files (no ACIM analogue):
- `ArchiveLineParser.swift` — parsed JTFNews's pipe-delimited archive text format; ACIM archives come as structured JSON arrays.

The watch target's `WatchDataService.swift` (currently JTFNews-shaped) needs its own rewrite in Phase 3.3 to match the new `DataService` contract.

**Rename as you port.** The current ACIM code still contains JTFNews domain names (`StoryCard`, `storyHash`, `factText`, `Source`, `Correction`, etc.). These are not just brand issues — they're domain-inaccurate for ACIM. Rename to the ACIM-native equivalents as you go (`MinuteCard` / `LessonCard`, `segmentHash`, `text`). Type renames will cascade compile errors; let them — Phase 3.4+ cleans up the view side.

### Endpoint contract (source of truth)

Base URL: `https://www.acimdailyminute.org`

| Service call | Path | Live-tested field shape (as of 2026-04-13) |
|---|---|---|
| Daily Minute JSON | `/daily-minute.json` | `{segment_id, date, text, source_pdf, source_reference, word_count, audio_url, youtube_url, youtube_id, tiktok_url, archive: [{date, text, source_reference, audio_url}]}` |
| Daily Lesson JSON | `/daily-lesson.json` | `{lesson_id, date, title, text, word_count, audio_url, youtube_url, youtube_id, total_lessons, archive: [{lesson_id, title, date, audio_url}]}` |
| Combined RSS | `/feed.xml` | RSS + `acim:*` extensions |
| Minute podcast | `/podcast-minute.xml` | iTunes-namespaced RSS |
| Lessons podcast | `/podcast-lessons.xml` | iTunes-namespaced RSS |

**DTO → model field mapping (important):**
- DTO `lesson_id` → model `DailyLesson.lessonNumber` (architecture plan calls it `lessonNumber` because that's what users see — "Lesson 47")
- DTO `title` → model `DailyLesson.lessonTitle`
- Daily Lesson JSON does **not** include `segment_id`, `source_pdf`, `source_reference`, or `tiktok_url` — leave those model fields at their `""` / `0` defaults on lesson rows. The parallel-schema choice is intentional: it simplifies `ArchivedReading` + cross-stream UI code in later phases.
- `segmentHash` on `DailyLesson` is non-unique (uniqueness is on `lessonNumber`) — compute it anyway for traceability: SHA-256 of `"lesson:\(lesson_id)|\(date)|\(text)"` truncated.
- `segmentHash` on `DailyMinute` IS unique: SHA-256 of `"minute:\(segment_id)|\(date)|\(text)"` truncated.
- `Bookmark.itemKey` composite: `"minute:\(segmentHash)"` for a Daily Minute, `"lesson:\(lessonNumber)"` for a Daily Lesson.
- `ArchivedReading.lineHash`: SHA-256 of `"\(channel)|\(dateString)|\(text)"` truncated.

Field authority if anything is ambiguous: `/Volumes/MacLive/Users/larryseyer/acim-daily-minute/github_push.py` publishes these files, so its serialization functions are the ground truth.

## Phase 3.3 recommended approach

This sub-phase is **larger than 3.2 and benefits from its own plan-mode pass** before implementation. Expected sequence:

1. Enter plan mode.
2. Launch Explore agent(s) against `/Users/larryseyer/jtfnewsapp/JTFNews/Services/` to inventory public APIs of each service (method signatures, `@Observable` state, async patterns, `@MainActor` boundaries). Parallel with an Explore pass over current `ACIMDailyMinute/Services/` to catalog what's on disk so the rewrite is a replacement, not a blind overwrite.
3. Launch Plan agent(s) to design the service-by-service rewrite strategy — probably grouped as (a) pure utilities (FetchCooldown, ConnectivityManager), (b) DTO + fetch layer (DataService, FeedService, PodcastService, ArchiveService), (c) user-facing (NotificationManager, PhraseMatcher, LiveActivityManager, AudioManager, BackgroundRefreshManager).
4. Commit Phase 3.3 in 2–3 logical chunks rather than one mega-commit so bisection stays useful. E.g. `Phase 3.3a: utilities + DataService`, `Phase 3.3b: feed/podcast/archive services`, `Phase 3.3c: notifications/audio/live activity/background refresh`.
5. After each commit, `Services/` should compile on its own. `Views/` will still be broken until Phase 3.4+.

## Ground rules

- **Swift & SwiftUI only.** No UIKit except the existing WKWebView for YouTube embed. No third-party SDKs.
- **Swift 6 strict concurrency.** `@MainActor` on all SwiftData writes. Mirror the JTFNews concurrency pattern.
- **No `xcodebuild` runs from Claude.** The user verifies builds in Xcode. If they want a quick sim check, they run `./build.sh` (currently targets iPhone 16 sim — offer to update to iPad sim iOS 18.1 to match the current dev target).
- **Read JTFNews freely.** `/Users/larryseyer/jtfnewsapp/JTFNews/Services/` is the pattern library. Name-checking JTFNews in handoff docs, plan files, memory, and dev tooling is fine.
- **User-facing JTFNews mentions are forbidden.** Before every commit, grep user-facing files for `JTF|jtf|jtfnews`: `README.md`, `LICENSE`, any SwiftUI text strings, in-app copy, onboarding, about screens, App Store copy (Phase 5+). Zero matches required there. Backend code / dev docs are exempt. See memory entry `feedback_no_jtfnews_mentions.md` for the full rule.
- **Commit per sub-phase / logical chunk** via `./bu.sh "message"` (git add/commit/push + Dropbox zip). Dropbox backup folder does not exist; zip step fails harmlessly unless the user creates it.
- **Zero placeholder data.** All content from `https://www.acimdailyminute.org/*`. Offline fallback = last-known-good cache in SwiftData.
- **Sparkly Edition source text language is non-negotiable** — never let docs drift back to "FIP" framing. Preserve the Teddy Poppe / CIMS / Penguin 2003 provenance chain verbatim if editing README or LICENSE.
- **Watch target is read-from-shared-container only** — no independent networking. iPhone populates the App Group store; watch reads it.
- **Confirm before actions with blast radius** — pushing, force-operations, deleting branches. Per-sub-phase commits via `./bu.sh` are pre-authorized once the user has confirmed once in the current session.

## Source-of-truth references

**JTFNews reference app (read-only, replicate shape — free to name in dev docs):**
- `/Users/larryseyer/jtfnewsapp/JTFNews/App/JTFNewsApp.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/App/ContentView.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/DataService.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/FetchCooldown.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/BackgroundRefreshManager.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/NotificationManager.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/ArchiveService.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/FeedService.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/PodcastService.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/AudioManager.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/LiveActivityManager.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/ConnectivityManager.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/WatchedTermMatcher.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNewsWidget/JTFNewsTimelineProvider.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNewsWatch/JTFNewsWatchApp.swift`
- `/Users/larryseyer/jtfnewsapp/CLAUDE.md` — coding conventions inherited verbatim

**ACIM backend (endpoints to consume, field contracts):**
- Live JSON: `https://www.acimdailyminute.org/daily-minute.json`, `.../daily-lesson.json`
- Live XML: `.../feed.xml`, `.../podcast-minute.xml`, `.../podcast-lessons.xml`
- Publisher: `/Volumes/MacLive/Users/larryseyer/acim-daily-minute/github_push.py` (authoritative field shapes)

**Brand assets (Phase 5 seeding):**
- CSS tokens: `/Volumes/MacLive/Users/larryseyer/ACIMDailyMinute/docs/style.css`
- 38 brand images: `/Volumes/MacLive/Users/larryseyer/acim-daily-minute/images/`

## Phase 3 roadmap (remaining)

| Sub-phase | Status | Goal |
|---|---|---|
| 3.1 | ✅ | Xcode project, 3 targets, entitlements, App Group |
| 3.2 | ✅ | SwiftData schema + 3 Schema declarations |
| 3.3 | ⏭ NEXT | Rewrite 11 services + WatchDataService for new models |
| 3.4 | | Today tab (DailyMinute + DailyLesson cards, pull-to-refresh, offline cache) |
| 3.5 | | Lessons tab (workbook browser + "Jump to Lesson N") |
| 3.6 | | Listen tab (podcast feed parse, AVFoundation playback, MiniPlayer, YouTube embed) |
| 3.7 | | Archive tab (calendar + FTS5 search over `ArchivedReading.searchableText`) |
| 3.8 | | Saved + Settings (incl. Watched Phrases) + Onboarding |
| 3.9 | | Widget target (3 families + Live Activity) |
| 3.10 | | Watch companion + 3 complications |
| 4 | | Feature parity checklist verification |
| 5 | | Branding + asset catalog + app icons |

## First move for the new session

1. Read the 5 required-reading files above.
2. Read the memory entries at `/Users/larryseyer/.claude/projects/-Users-larryseyer-ACIMDailyMinuteApp/memory/MEMORY.md` — in particular `feedback_no_jtfnews_mentions.md` (user-facing scrub rule only) and `project_test_targets.md`.
3. Confirm the active model is Claude Opus 4.6 (1M context) and that `/fast` is OFF. Flag either if not.
4. Enter plan mode for Phase 3.3 — use parallel Explore agents for JTFNews service inventory + current-ACIM services inventory, then a Plan agent for rewrite strategy.
5. Present the plan via ExitPlanMode.
6. On approval, execute Phase 3.3 in 2–3 logical chunks, committing each via `./bu.sh "Phase 3.3{a,b,c}: <chunk>"`.

Do not skip plan mode — 11 services is a big surface; designing the DTO layer, concurrency boundaries, and fetch-cooldown wiring up-front prevents rework.
