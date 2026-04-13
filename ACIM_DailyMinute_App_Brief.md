# Project Brief: ACIM Daily Minute App

**Reference App (model to follow):** `/Users/larryseyer/jtfnewsapp`
**New App Target Directory:** `/Users/larryseyer/ACIMDailyMinuteApp`
**Backend Server:** `/Volumes/MacLive/Users/larryseyer/acim-daily-minute`
**Website Source:** `/Volumes/MacLive/Users/larryseyer/ACIMDailyMinute`
**Live Website:** `https://www.acimdailyminute.org/`

---

## Objective

Audit the JTFNews reference app in full — its architecture, data flow, UI patterns, widget extensions, and watch targets — and replicate every capability as a new, standalone app called **ACIM Daily Minute**. Do not assume anything about either codebase; read all source files before writing a single line.

---

## Phase 1 — Audit & Discovery

1. Fully inventory `/Users/larryseyer/jtfnewsapp`: folder structure, Swift packages/dependencies, targets, entitlements, shared data groups, and any backend API calls.
2. Fully inventory `/Volumes/MacLive/Users/larryseyer/acim-daily-minute`: endpoints, data models, feed formats (RSS/JSON/API), and authentication if any.
3. Fetch and inspect `https://www.acimdailyminute.org/` to understand content types, categories, and any existing API routes.
4. Produce a written **Audit Report** comparing both sides — what data the new app will consume vs. what JTFNews consumed — before any code is generated.

You might want to video /Users/larryseyer/jtfnewsapp/CLAUDE.md and see if you need to use any of it's instructions for this project.

---

## Phase 2 — Architecture Plan

Based on the audit, produce a full architecture document covering:

- Xcode project structure (targets, schemes, build settings)
- Shared Swift Package(s) for models, networking, and persistence
- App Group identifiers for data sharing between app, widgets, and watch
- Data layer: how content is fetched, cached, and refreshed (background fetch / push / silent notifications)
- Content model mapping (JTFNews articles → ACIM daily lessons, minutes, quotes, etc.)

---

## Phase 3 — Build All Targets

Build each target in the following order, validating each before moving on:

| Target | Platform | Notes |
|---|---|---|
| `ACIMDailyMinute` | iOS 17+ (iPhone & iPad) | Adaptive layout, Dynamic Type |
| `ACIMDailyMinuteWidgets` | iOS WidgetKit | Small, medium, large, lock screen |
| `ACIMDailyMinuteWatch` | watchOS 10+ | Complications + standalone view |
| `ACIMDailyMinuteMac` | macOS 14+ (Mac Catalyst or native SwiftUI) | Menu bar item optional |
| `ACIMDailyMinuteMacWidgets` | macOS WidgetKit | Desktop widgets |

---

## Phase 4 — Feature Parity Checklist

For every feature found in JTFNews, implement an equivalent in ACIM Daily Minute:

- [ ] Content feed / list view with pull-to-refresh
- [ ] Detail / reader view
- [ ] Favorites / bookmarks (persisted via App Group)
- [ ] Push or local notifications (daily reminder)
- [ ] Share sheet integration
- [ ] Offline cache / graceful degradation
- [ ] Widgets (all sizes, all platforms)
- [ ] Watch complication + glance view
- [ ] Settings screen (notification time, appearance, etc.)
- [ ] Accessibility: VoiceOver, Dynamic Type, Reduce Motion

---

## Phase 5 — Branding & Assets

- Replace all JTFNews branding, colors, icons, and copy with ACIM Daily Minute equivalents.
- Pull brand colors and tone from `https://www.acimdailyminute.org/`.
- Generate required asset catalog entries for all targets (App Icons, accent colors, widget previews).

---

## Constraints & Rules

- **Swift & SwiftUI only** — no UIKit unless UIKit is already used in the reference app for a specific component.
- **No placeholder data** — all content must come from the live backend or a documented offline fallback.
- **Read before writing** — use file reading tools to inspect every relevant source file before generating code.
- **Incremental commits** — after each phase, summarize what was done and what comes next before proceeding.
- Use the same Xcode version and minimum deployment targets already established in `jtfnewsapp` unless a newer target is warranted.

---

## Open Questions (Answer Before Kickoff)

These answers will sharpen the plan and prevent surprises during the audit phase:

1. **What format does the ACIM backend serve content in?**
   (JSON REST API, RSS feed, GraphQL, static files?)

      I do not know.  But I'm fairly sure it is the same as JTFNews.. you will have ton investgate and find out for sure.

2. **Does the JTFNews app use push notifications, and if so, which service?**
   (APNs direct, Firebase, etc.)

         Yes, but I don't know what it uses..

3. **Is there an existing Apple Developer team/bundle ID prefix** you want to reuse for the new app?

      Yes, I have an apple developer account and it will use the same one.

4. **Any design direction already decided?**
   Should the new app closely mirror the JTFNews UI chrome, or start fresh visually while keeping the same feature set?

      Not at all... it has it's own unique look and feel... you can find out the direction looking at images in /Volumes/MacLive/Users/larryseyer/acim-daily-minute/images

      Also, the website already exists and looks pretty good.  https://www.acimdailyminute.org/

      However, the images actually convey the actual look and feel we want to present.


