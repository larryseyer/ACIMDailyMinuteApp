# Continuation Prompt — ACIM Daily Minute App

Paste everything below into a fresh Claude Code session started in `/Users/larryseyer/ACIMDailyMinuteApp` to resume where we left off.

---

## Context

I'm building a new Apple-platform app called **ACIM Daily Minute** that mirrors the capabilities of my existing JTFNews reference app, repointed at the ACIM content stream. We completed **Phase 1 (Audit & Discovery)** in a prior session. The audit report is saved at:

`/Users/larryseyer/.claude/plans/gentle-gathering-pearl.md`

**Read that file first.** It contains:
- Full inventory of the JTFNews reference app (`/Users/larryseyer/jtfnewsapp`) — 3 targets, unified SwiftUI, zero dependencies, SwiftData + App Group + SQLite FTS5, local notifications only.
- Full inventory of the ACIM backend (`/Volumes/MacLive/Users/larryseyer/acim-daily-minute`) — Python pipeline that publishes static JSON/XML to GitHub Pages at `https://www.acimdailyminute.org`. No HTTP API.
- Feed endpoints the app will consume (`daily-minute.json`, `daily-lesson.json`, `feed.xml`, `podcast-minute.xml`, `podcast-lessons.xml`).
- Design tokens (dark purple `#1a1025`, gold `#d4af37`, Georgia serif) and 38 brand images at `/Volumes/MacLive/Users/larryseyer/acim-daily-minute/images/`.
- JTFNews → ACIM model mapping (two channels: `daily-minute` and `daily-lesson`).
- Confirmed project identity:
  - Name: `ACIM Daily Minute`
  - Bundle ID prefix: `com.larryseyer.acimdailyminute`
  - 3 targets (app unified for iOS/iPadOS/macOS, widget, watch) — **match JTFNews, not the 5-target structure in the original brief**
  - App Group: `group.com.larryseyer.acimdailyminute`
  - Min deploy: iOS 17 / iPadOS 17 / macOS 14 / watchOS 10

The original project brief is at `/Users/larryseyer/ACIMDailyMinuteApp/ACIM_DailyMinute_App_Brief.md` — reference it but treat the audit report as the source of truth where they conflict (specifically: 3 targets, not 5).

## What I want you to do

Resume with **Phase 2 — Architecture Plan**, then continue sequentially through Phases 3–5. Work in plan mode for each phase before writing code.

### Phase 2 — Architecture
Produce a detailed architecture plan covering:
- Xcode project structure (3 targets, schemes, build settings, signing team — ask me for my Apple Developer Team ID before finalizing)
- Shared Swift Package(s) for models, networking, persistence (or in-target folders — recommend whichever matches JTFNews)
- App Group identifier layout for data sharing
- Data layer: two SwiftData channels (`DailyMinute`, `DailyLesson`), fetch/cache strategy mirroring `JTFNews/Services/DataService.swift`, FTS5 archive indexing
- Content model field-by-field mapping from the JSON/RSS feeds to SwiftData entities
- Background refresh strategy (scenePhase-driven, matching `BackgroundRefreshManager.swift`)
- Widget families and Live Activity shape
- Watch companion architecture
- Notifications (local only, opt-in, default daily reminder time — ask me)
- Open items from the Phase 1 report that must be resolved before coding:
  1. Apple Developer Team ID
  2. Daily reminder default time
  3. Keep or drop watched-phrases feature
  4. Allow "jump to lesson N" or strict daily delivery
  5. Audio playback in v1 or v1.1
  6. App icon source

### Phase 3 — Build All Targets
Build incrementally in this order, verifying each before moving on:
1. `ACIMDailyMinute` (iOS 17+ / iPadOS / macOS 14+ unified)
2. `ACIMDailyMinuteWidget` (WidgetKit, iOS + macOS families + Live Activity)
3. `ACIMDailyMinuteWatch` (watchOS 10+ with complications)

### Phase 4 — Feature Parity Checklist
For every feature in JTFNews, verify an ACIM equivalent is implemented: feed/list with pull-to-refresh, detail/reader, bookmarks, local notifications (daily reminder), share sheet, offline cache, widgets (all sizes/platforms), watch complication + glance, settings, accessibility (VoiceOver, Dynamic Type, Reduce Motion).

### Phase 5 — Branding & Assets
Replace JTFNews branding with ACIM Daily Minute branding. Pull colors from `/Volumes/MacLive/Users/larryseyer/ACIMDailyMinute/docs/style.css`. Seed asset catalogs from `/Volumes/MacLive/Users/larryseyer/acim-daily-minute/images/`. Generate app icons and widget previews for all targets.

## Rules

- **Swift & SwiftUI only.** No UIKit unless JTFNews already uses it for a specific component.
- **No placeholder data.** All content from the live `acimdailyminute.org` feeds, with a documented offline fallback.
- **Read before writing.** Inspect every relevant source file in `/Users/larryseyer/jtfnewsapp` before generating an equivalent for the new app.
- **Zero dependencies.** Native Apple frameworks only (matches JTFNews).
- **Incremental commits.** After each phase, summarize what was done and what comes next before proceeding.
- **Follow JTFNews's CLAUDE.md conventions** (`/Users/larryseyer/jtfnewsapp/CLAUDE.md`): Swift 6 strict concurrency, calm dark-mode minimalism, no analytics, no accounts.
- **Ask before assuming.** Use AskUserQuestion for any ambiguous decision — particularly the open items listed under Phase 2 above.

## Starting point

1. Read `/Users/larryseyer/.claude/plans/gentle-gathering-pearl.md` in full.
2. Skim the brief at `/Users/larryseyer/ACIMDailyMinuteApp/ACIM_DailyMinute_App_Brief.md`.
3. Enter plan mode for Phase 2 architecture.
4. Ask me the Phase 2 open items before writing the architecture plan.
5. After I approve the architecture plan, proceed to Phase 3 implementation.
