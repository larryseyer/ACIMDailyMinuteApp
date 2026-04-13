# Continuation Prompt — ACIM Daily Minute App

Paste everything below into a fresh Claude Code session started in `/Users/larryseyer/ACIMDailyMinuteApp` to resume where we left off.

---

## TL;DR

Phases 1 (audit), 2 (architecture), and 3.1 (Xcode scaffolding) are **complete and pushed to GitHub** at `https://github.com/larryseyer/ACIMDailyMinuteApp` (branch `main`, commit `a590457`). Resume at **Phase 3.2 — rewrite the SwiftData schema** for ACIM's two-channel model. Do NOT regenerate the Xcode project — it exists and the structure is final.

## Required reading in this order

1. `/Users/larryseyer/.claude/plans/gentle-gathering-pearl.md` — Phase 1 audit (JTFNews ↔ ACIM mapping, feed endpoints, brand tokens)
2. `/Users/larryseyer/.claude/plans/piped-wandering-lobster.md` — Phase 2 architecture plan (approved, authoritative)
3. `/Users/larryseyer/ACIMDailyMinuteApp/README.md` — current-state feature overview
4. `/Users/larryseyer/jtfnewsapp/CLAUDE.md` — coding conventions inherited verbatim

## Decisions already locked (do not re-ask)

| Decision | Value |
|---|---|
| Apple Developer Team ID | `RR5DY39W4Q` (inherited from JTFNews) |
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
| Swift | 6.0 with strict concurrency |
| Dependencies | Zero — Apple frameworks only |
| Source text | **Sparkly Edition**, published by **Teddy Poppe (Theodore Poppe)**, CIMS/Endeavor Academy lineage, US public domain per *Penguin Books USA v. New Christian Church of Full Endeavor* (2003). **NOT the FIP edition** — this is load-bearing for the README/LICENSE language, do not let any docs slip back to "FIP" framing. |

## Project state (what's already on disk and pushed)

```
/Users/larryseyer/ACIMDailyMinuteApp/
├── .git/                              origin → github.com/larryseyer/ACIMDailyMinuteApp
├── .gitignore
├── README.md                          Sparkly Edition / Teddy Poppe / CIMS / 2003 Penguin case
├── LICENSE                            CC BY-SA 4.0 scoped to original works
├── CONTINUE.md                        this file
├── ACIM_DailyMinute_App_Brief.md      original brief (deprecated where it conflicts with audit)
├── ACIMDailyMinute.xcodeproj/         3 targets, Team RR5DY39W4Q, App Group wired
├── ACIMDailyMinute.entitlements
├── ACIMDailyMinute/                   main app target (transitional JTFNews internals)
├── ACIMDailyMinuteWidget/             widget extension
├── ACIMDailyMinuteWatch/              watchOS companion
├── build.sh                           fast Debug build verification across 3 sims
├── clean.sh                           nuke build/ + DerivedData
├── both.sh                            clean Release + install on physical iPhone + iPad Sim
├── bu.sh                              git add/commit/push + Dropbox zip backup
├── run_ralph.sh + bash/               Ralph agentic loop (unused so far)
```

All identifiers are already renamed: `JTFNews` → `ACIMDailyMinute`, bundle IDs, URL scheme, font helpers `jtfBody` → `acimBody`, SQLite filename, app group, BG task.

## What's STILL in JTFNews form and needs rewriting

The scaffolding is a literal JTFNews clone with identifiers renamed. These files contain JTFNews domain logic that Phase 3.2–3.8 will rewrite:

- **Models** (`ACIMDailyMinute/Models/`) — still `Story.swift`, `Source.swift`, `Correction.swift`, `Bookmark.swift`, `ArchivedStory.swift`, `Channel.swift`, `ACIMActivityAttributes.swift` (renamed file, JTFNews-shaped contents)
- **Services** (`ACIMDailyMinute/Services/`) — DataService hits `/stories.json` (doesn't exist on acimdailyminute.org); FeedService still parses `jtf:source` XML namespace
- **Views** — TabView has Stories/Digest/Archive/Saved/Watched tabs; needs Today/Lessons/Listen/Archive/Saved (Watched moves into Settings)
- **Widget** — TimelineProvider reads news-story schema
- **App icons** — placeholder JTFNews icons

## Resume at Phase 3.2 — SwiftData schema rewrite

Per the approved architecture plan (`piped-wandering-lobster.md` §6), the new schema is:

| Model | Purpose | Unique key |
|---|---|---|
| `DailyMinute` | Maps `daily-minute.json` record | `segmentHash` |
| `DailyLesson` | Maps `daily-lesson.json` record | `lessonNumber` |
| `Bookmark` | Unified favorites across both streams | `itemKey` (composite `"minute:{hash}"` / `"lesson:{N}"`) |
| `ArchivedReading` | FTS5-searchable archive, both channels | `lineHash` |
| `Channel` | Parameterization (`daily-minute` / `daily-lesson`) | `id` |

`ACIMActivityAttributes.ContentState` shape: `{ channel: String, latestText: String, publishedDate: Date, lessonNumber: Int? }`

Field-by-field mapping of `DailyMinute` and `DailyLesson` is in the architecture plan. Drop `Story`, `Source`, `Correction`, `ArchivedStory` — those are JTFNews-only.

## Phase 3.2 concrete task list

1. **Replace model files** in `ACIMDailyMinute/Models/`:
   - Delete: `Story.swift`, `Source.swift`, `Correction.swift`, `ArchivedStory.swift`
   - Rewrite: `Bookmark.swift` (new schema), `Channel.swift` (for ACIM), `ACIMActivityAttributes.swift` (new ContentState)
   - Create: `DailyMinute.swift`, `DailyLesson.swift`, `ArchivedReading.swift`
2. **Update `Schema([...])` declarations**:
   - `ACIMDailyMinute/App/ACIMDailyMinuteApp.swift`
   - `ACIMDailyMinuteWatch/ACIMDailyMinuteWatchApp.swift`
   - `ACIMDailyMinuteWidget/SharedModelContainer.swift`
3. **Remove model files from Xcode target membership** — the `ACIMDailyMinute.xcodeproj/project.pbxproj` still references the deleted Story/Source/Correction/ArchivedStory files. Update PBXFileReference / PBXBuildFile entries, or delete the groups and re-add the new files. Careful: editing pbxproj by hand is fragile — a safer path is to use the XcodeProj gem, XcodeGen, or just edit in Xcode. The user verifies builds in Xcode.
4. **Expect Xcode compile errors in Phase 3.2 end state** — views and services still reference `Story`/`Source`/etc. That's fine; Phase 3.3 rewrites services, Phase 3.4+ rewrites views. The architecture plan explicitly calls out this transitional broken state.

## Ground rules

- **Swift & SwiftUI only.** No UIKit except where JTFNews already uses it (WKWebView for YouTube). No third-party SDKs.
- **No `xcodebuild` runs from Claude.** The user verifies builds in Xcode. If they want a quick sim check, they run `./build.sh`.
- **Read JTFNews source before writing ACIM equivalents.** `/Users/larryseyer/jtfnewsapp/JTFNews/` is the pattern library. The audit report enumerates every file.
- **Commit per sub-phase** using the existing `./bu.sh "message"` script (runs git add/commit/push + Dropbox backup), or manual `git` commands. The Dropbox backup folder may not exist yet — first run of `bu.sh` may fail on the zip step, that's fine.
- **Zero placeholder data.** All content comes from `https://www.acimdailyminute.org/*` endpoints with a documented offline fallback.
- **Sparkly Edition source text language is non-negotiable** — never let the docs drift back to "FIP" framing. If editing README or LICENSE, preserve the Teddy Poppe / CIMS / Penguin 2003 provenance chain verbatim.

## Source-of-truth references

**JTFNews reference app (read-only, replicate shape):**
- `/Users/larryseyer/jtfnewsapp/JTFNews/App/JTFNewsApp.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/App/ContentView.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/DataService.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/BackgroundRefreshManager.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/NotificationManager.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/ArchiveService.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/AudioManager.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNews/Services/LiveActivityManager.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNewsWidget/JTFNewsTimelineProvider.swift`
- `/Users/larryseyer/jtfnewsapp/JTFNewsWatch/JTFNewsWatchApp.swift`
- `/Users/larryseyer/jtfnewsapp/CLAUDE.md`

**ACIM backend (endpoints to consume, field contracts):**
- Live JSON: `https://www.acimdailyminute.org/daily-minute.json`, `.../daily-lesson.json`
- Live XML: `.../feed.xml`, `.../podcast-minute.xml`, `.../podcast-lessons.xml`
- Publisher: `/Volumes/MacLive/Users/larryseyer/acim-daily-minute/github_push.py` (authoritative field shapes)

**Brand assets (Phase 5 seeding):**
- CSS tokens: `/Volumes/MacLive/Users/larryseyer/ACIMDailyMinute/docs/style.css`
- 38 brand images: `/Volumes/MacLive/Users/larryseyer/acim-daily-minute/images/`

## Phase 3 roadmap (remaining)

| Sub-phase | Goal |
|---|---|
| 3.2 | SwiftData models + SharedModelContainer for new schema |
| 3.3 | Rewrite all 11 services (DataService, FeedService, PodcastService, ArchiveService, AudioManager, NotificationManager, BackgroundRefreshManager, ConnectivityManager, PhraseMatcher, LiveActivityManager, FetchCooldown) |
| 3.4 | Today tab (DailyMinute + DailyLesson cards, pull-to-refresh, offline cache) |
| 3.5 | Lessons tab (workbook browser + "Jump to Lesson N") |
| 3.6 | Listen tab (podcast feed parse, AVFoundation playback, MiniPlayer, YouTube embed) |
| 3.7 | Archive tab (calendar + FTS5 search) |
| 3.8 | Saved + Settings (incl. Watched Phrases) + Onboarding |
| 3.9 | Widget target (3 families + Live Activity) |
| 3.10 | Watch companion + 3 complications |
| 4 | Feature parity checklist verification |
| 5 | Branding + asset catalog + app icons |

## First move for the new session

1. Read the three required-reading files above.
2. Enter plan mode for Phase 3.2 design (SwiftData models + pbxproj membership strategy).
3. Present the plan for approval via ExitPlanMode.
4. On approval, execute Phase 3.2.
5. Commit with `./bu.sh "Phase 3.2: SwiftData schema for ACIM channels"` or manual git commit + push.

Do not skip the plan mode step — the architecture plan authorized the *overall* approach, but how to handle pbxproj target membership when deleting model files is a real implementation choice that deserves a short plan.
