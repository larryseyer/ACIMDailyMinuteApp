# ACIM Daily Minute — Feature Parity Verification
Date: 2026-04-14
Branch: ralph/acim-3.9-to-5-finish-2026-04-14
Verified at commit: 14bc0eccf72a381eb85a53cfcd244c9ec639518a

| Surface | Required | Current state | Pass/Fail | Evidence (file:line or commit hash) |
|---|---|---|---|---|
| Today tab | DailyMinute card + refresh | Present; @Query fetches DailyMinute, DailyMinuteCard renders, pull-to-refresh calls DataService | Pass | Views/Today/TodayView.swift:4 |
| Lessons tab (spine + detail + search + Jump-to-N) | 365-lesson spine, detail view, searchable, jump sheet | Present; filteredLessonNumbers with text + numeric search, LessonDetailView with 3 render states | Pass | Views/Lessons/LessonsView.swift:21, LessonDetailView.swift:16, JumpToLessonSheet.swift:14 |
| Listen tab (podcast feed + YouTube embed + MiniPlayer) | Dual podcast feeds, YouTube player, MiniPlayer overlay | Present; segmented feed picker (minute/lesson), YouTubePlayerView 16:9 embed, AudioManager drives MiniPlayerView | Pass | Views/Listen/ListenView.swift:19, YouTubePlayerView.swift, MiniPlayerView.swift |
| Archive tab (calendar + search + per-date detail) | Calendar date picker, searchable, date detail view | Present; DatePicker .graphical (iOS), ArchiveSearchResultsList, ArchiveDateDetailView | Pass | Views/Archive/ArchiveView.swift:24, ArchiveDateDetailView.swift:14 |
| Saved tab (BookmarkRow + swipe-delete) | Bookmark list with swipe-to-delete | Present; BookmarkRow rendering, .onDelete(perform: delete) | Pass | Views/Saved/SavedView.swift:4, BookmarkRow.swift |
| Settings (notifications + reminder + phrases editor + replay onboarding + About) | All five sections | Present; Daily reminder toggle + DatePicker, PhrasesEditorView link, Replay introduction button, About with version + lineage | Pass | Views/Settings/SettingsView.swift:24-66 |
| Onboarding (5-page intro + lineage line) | 5 intro pages + Sparkly Edition lineage | Present; 5 pages (Minute, Lesson, Listen, Archive, Save), lineage footer on both iOS and macOS | Pass | Views/Onboarding/OnboardingView.swift:7-20, lineage at :44/:67 |
| Deep links (today / lesson/N / archive/YYYY-MM-DD / saved) | 4 URL routes via acimdailyminute:// scheme | Present; DeepLinkRoute enum with 4 cases, parse() from URL, onOpenURL in ContentView routes to tabs | Pass | Utilities/DeepLinkRoute.swift:3-7, App/ContentView.swift:30-47 |
| Shortcut (GetTodaysReadingIntent) | AppIntent + AppShortcut phrases | Present; GetTodaysReadingIntent with SwiftData fetch, ACIMDailyMinuteShortcuts provider | Pass | Shortcuts/GetTodaysReadingIntent.swift:5, Shortcuts/ACIMDailyMinuteShortcuts.swift:3 |
| Widget Small | systemSmall with minute excerpt + date | Present; relative date, minute text (4-line), lesson badge, deep link | Pass | ACIMDailyMinuteWidget/SmallWidgetView.swift:4 |
| Widget Medium | systemMedium with minute + lesson + CTA | Present; HStack layout, divider, lesson sidebar, CTA text, deep link | Pass | ACIMDailyMinuteWidget/MediumWidgetView.swift:11 |
| Widget Large | systemLarge with full text + bookmark indicator | Present; bookmark.fill icon, 12-line body, lesson footer, deep link | Pass | ACIMDailyMinuteWidget/LargeWidgetView.swift:11 |
| Live Activity UI | ActivityAttributes + Dynamic Island + Lock Screen | Present; ACIMDailyMinuteAttributes, Lock Screen VStack, expanded/compact/minimal Dynamic Island | Pass | ACIMDailyMinuteWidget/ACIMDailyMinuteLiveActivity.swift:6 |
| Watch Today view | DailyMinute display on wrist | Present; WatchContentView with Section("Today"), WatchStoryRow, WatchDataService singleton | Pass | ACIMDailyMinuteWatch/WatchContentView.swift:4, WatchStoryRow.swift |
| Watch complications x3 (circular, rectangular, inline) | WidgetKit accessory families | Present; accessoryCircular (L + number), accessoryRectangular (title + lesson + snippet), accessoryInline (text) | Pass | ACIMDailyMinuteWatch/ACIMDailyMinuteWatchWidget.swift:56/67/80 |
| Watch/phone sync (one-way) | WCSession phone→watch DailyMinute push | Present; PhoneWatchSyncService sends via sendMessage/updateApplicationContext, WatchDataService receives + upserts | Pass | Services/PhoneWatchSyncService.swift:15, ACIMDailyMinuteWatch/WatchDataService.swift |
| App icon set | 1024x1024 master + all sizes in both targets | Present; real PNGs in main app + watch AppIcon.appiconset (pre-staged iconset installed) | Pass | ACIMDailyMinute/Assets.xcassets/AppIcon.appiconset/ (10 PNGs), ACIMDailyMinuteWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png |
| Launch screen | UILaunchScreen in Info.plist | Not yet configured; no UILaunchScreen key in Info.plist | Phase 5 | Story ACIM-011 (5b) |
| Accent color | Warm gold #C9A961 in AccentColor.colorset | Default empty colorset; no color values set | Phase 5 | Story ACIM-011 (5b) |
| ACIMChime.caf custom sound wired | preferredSound() in NotificationManager + pbxproj membership | Present; ACIMChime.caf in Resources bundle (pbxproj AA000001079/AA000002066), preferredSound() helper at NotificationManager.swift:132, wired to all 3 notification sites | Pass | Services/NotificationManager.swift:132-139, project.pbxproj AA000001079 |
| App Store metadata artifact | APP_STORE_LISTING.md at repo root | Not yet created | Phase 5 | Story ACIM-013 (5d) |

## Phase 5 items pending

Three surfaces are marked "Phase 5" above. These are not gaps — they have explicit stories in the current PRD:

- **Launch screen + Accent color**: Story ACIM-011 (5b) configures UILaunchScreen and sets warm gold tint
- **App Store metadata**: Story ACIM-013 (5d) creates APP_STORE_LISTING.md

All Phase 3.x and 4.x functional surfaces pass. No unexpected gaps found. Phase 5 branding stories proceed as planned.
