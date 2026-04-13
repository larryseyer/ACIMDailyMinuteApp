# ACIM Daily Minute

Native iOS, iPadOS, macOS, and watchOS app for [ACIM Daily Minute](https://www.acimdailyminute.org) — a contemplative daily reader for *A Course in Miracles*.

A unified Apple-platform surface for reading today's passage, following the 365-day Workbook lessons, listening to the audio episodes, searching the full archive, and keeping your own favorites and study phrases.

## Features

**Today** — Today's Daily Minute passage (7 days/week, randomly selected from the Text) and today's Daily Lesson (Mon–Fri, sequential through Workbook lessons 1–365). Passages rendered in Georgia serif against a calm dark-purple background.

**Lessons** — Full 365-lesson Workbook browser with "Jump to Lesson N" navigation, lesson titles, and per-lesson detail view. Today's lesson is featured; any past lesson is accessible at any time.

**Listen** — Audio episodes from both podcasts (`podcast-minute.xml`, `podcast-lessons.xml`). AVFoundation playback with lock screen / Control Center controls and a floating MiniPlayer across all tabs. YouTube embed for each segment's video version.

**Archive** — Calendar date browser + full-text search across all archived readings from both channels. Rolling archive prefetched on launch for instant offline access.

**Saved** — Bookmark any passage or lesson for later reading. Swipe-to-delete management.

**Watched Phrases** — Track phrases from the *Course* (up to 10 terms). When a new reading contains one of your phrases, a local notification appears. Useful for study practice — follow a theme like *forgiveness* or *holy instant* across daily passages.

**Notifications** — Local, on-device notifications only. Three opt-in categories:
- Daily reading ready (default 7:00 AM local, customizable)
- New Daily Lesson posted (Mon–Fri)
- Watched-phrase match (on every fetch)

All notifications off by default. Background refresh checks via scenePhase; custom notification sound.

**Live Activities & Dynamic Island** — When today's reading arrives, a Lock Screen banner and Dynamic Island presence show the passage and lesson number. Auto-dismisses after 5 minutes. Opt-in via Settings.

**Home Screen Widgets** — Small, medium, and large WidgetKit widgets showing today's passage at a glance. Small = Daily Minute; Medium = Minute + Lesson side-by-side; Large = full passage + lesson title.

**Share Sheet** — Polished share text with the passage, lesson reference, and a link to acimdailyminute.org. Context menu on every card.

**Apple Watch** — Companion watchOS app reading from the shared App Group store. Today's Minute + today's Lesson stacked on the wrist. Complications for watch faces:
- Circular — lesson number ("L47")
- Rectangular — lesson title + 2-line passage preview
- Inline — "Lesson 47 · Daily Minute ready"

**Offline First** — All content cached locally in the App Group SwiftData store. Works fully offline once today's readings have been fetched. No account, no login, no server dependency.

## Architecture

**Pure Static Consumer** — the app fetches existing static files from `acimdailyminute.org` (GitHub Pages). No backend server. No API. No push notification server. No accounts.

| Endpoint | Purpose |
|----------|---------|
| `daily-minute.json` | Today's Daily Minute + 7-day archive |
| `daily-lesson.json` | Today's Daily Lesson + 7-day archive |
| `feed.xml` | Combined RSS 2.0 feed with `acim:*` extensions |
| `podcast-minute.xml` | iTunes podcast RSS for Daily Minute audio |
| `podcast-lessons.xml` | iTunes podcast RSS for Daily Lesson audio |

Content is generated daily (2:00 AM local) by a separate Python pipeline that TTS-renders, publishes to YouTube + TikTok, and pushes metadata JSON/XML to GitHub Pages. The app is a pure consumer — it never writes back to the backend.

## Tech Stack

- **Language:** Swift 6 (strict concurrency)
- **UI:** SwiftUI (iOS 17+, iPadOS 17+, macOS 14+, watchOS 10+)
- **Persistence:** SwiftData (shared App Group SQLite store)
- **Search:** SwiftData `@Query` with `#Predicate` full-text matching
- **Networking:** URLSession with per-endpoint cooldowns (15 min live, 24 h near-static)
- **Audio:** AVFoundation + MPNowPlayingInfoCenter
- **Video:** WKWebView (YouTube embed)
- **Widgets:** WidgetKit (iOS home screen + macOS + watchOS complications)
- **Live Activities:** ActivityKit (iOS Lock Screen + Dynamic Island)
- **Dependencies:** Zero third-party SDKs — native Apple frameworks only
- **Minimum targets:** iOS 17 / iPadOS 17 / macOS 14 / watchOS 10

## Privacy

- Zero tracking. Zero analytics. Zero user data collected.
- No ads. No in-app purchases. Free.
- No Firebase, no crash reporting SDKs, no user accounts.
- All notification and phrase matching is on-device.
- App Store Privacy Label: **Data Not Collected**

## Building

```bash
# Fast Debug verification across all 3 targets (iOS, macOS, watchOS simulators)
./build.sh

# Clean build artifacts + DerivedData
./clean.sh

# Release build + install/launch on physical iPhone + iPad Simulator
./both.sh

# Commit, push, and Dropbox-backup in one step
./bu.sh "your commit message"
```

Manual `xcodebuild` invocations:

```bash
# iOS Simulator
xcodebuild -scheme ACIMDailyMinute \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# macOS
xcodebuild -scheme ACIMDailyMinute \
  -destination 'platform=macOS' build

# watchOS Simulator
xcodebuild -scheme "ACIMDailyMinuteWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
```

## Project Structure

```
ACIMDailyMinuteApp/
├── ACIMDailyMinute.xcodeproj
├── ACIMDailyMinute/                  (iOS / iPadOS / macOS unified target)
│   ├── App/                          ACIMDailyMinuteApp, ContentView
│   ├── Models/                       DailyMinute, DailyLesson, Bookmark,
│   │                                 ArchivedReading, Channel,
│   │                                 ACIMActivityAttributes
│   ├── Services/                     DataService, FeedService, PodcastService,
│   │                                 ArchiveService, AudioManager,
│   │                                 NotificationManager, BackgroundRefreshManager,
│   │                                 ConnectivityManager, PhraseMatcher,
│   │                                 LiveActivityManager, FetchCooldown
│   ├── Views/
│   │   ├── Today/                    TodayView (Minute + Lesson cards)
│   │   ├── Lessons/                  LessonsView, LessonDetailView (jump-to-N)
│   │   ├── Listen/                   ListenView, AudioPlayerView,
│   │   │                             YouTubePlayerView, MiniPlayerView
│   │   ├── Archive/                  ArchiveView, ArchiveSearchView, MacCalendarView
│   │   ├── Saved/                    SavedView
│   │   ├── Settings/                 SettingsView, WatchedPhrasesView,
│   │   │                             PrivacyPolicyView
│   │   └── Onboarding/               OnboardingView
│   ├── Utilities/                    BrandColors, PlatformTypography,
│   │                                 ShareTextBuilder, GzipUtility
│   ├── Resources/                    ACIMChime.caf
│   └── Assets.xcassets
│
├── ACIMDailyMinuteWidget/            (WidgetKit extension — iOS + macOS)
│   ACIMDailyMinuteWidget, ACIMDailyMinuteTimelineProvider,
│   ACIMDailyMinuteLiveActivity, SharedModelContainer (read-only)
│
└── ACIMDailyMinuteWatch/             (watchOS 10+ companion)
    ACIMDailyMinuteWatchApp, WatchContentView,
    ACIMDailyMinuteWatchWidget (complications)
```

Three targets, one App Group (`group.com.larryseyer.acimdailyminute`), one shared SwiftData store (`ACIMDailyMinute.sqlite`).

## Design Language

- **Primary:** deep purple `#1a1025`
- **Accent:** gold `#d4af37`
- **Secondary:** blue `#60a5fa`
- **Passage body:** Georgia serif
- **UI chrome:** system sans-serif
- **Radii:** pill buttons at 24px
- **Mode:** dark-first, with optional light toggle in Settings

Based on the [acimdailyminute.org](https://www.acimdailyminute.org) design tokens.

## Related

- [ACIM Daily Minute Website](https://www.acimdailyminute.org)
- [YouTube Channel](https://www.youtube.com/@ACIMDailyMinute)
- [RSS Feed](https://www.acimdailyminute.org/feed.xml)
- [Daily Minute Podcast](https://www.acimdailyminute.org/podcast-minute.xml)
- [Daily Lesson Podcast](https://www.acimdailyminute.org/podcast-lessons.xml)

## Credits

This app is architecturally derived from the [JTFNews iOS app](https://github.com/larryseyer/jtfnewsapp), repointed at the ACIM content stream. Same zero-dependency, privacy-first, pure-static-consumer philosophy.

### About the source text

**This app uses the public-domain "Sparkly Edition" of *A Course in Miracles*, published by Teddy Poppe (Theodore Poppe) and associated with the Course in Miracles Society (CIMS) — not the Foundation for Inner Peace (FIP) edition.**

The text distributed by this app is the Sparkly Edition published by Teddy Poppe, which descends from the CIMS / Endeavor Academy lineage that fought and won *Penguin Books USA, Inc. v. New Christian Church of Full Endeavor, Ltd.* (S.D.N.Y. 2003). In that case, the court held that the original *Course in Miracles* manuscript had entered the public domain because it was distributed without copyright notice before any copyright was registered. That ruling is settled law: this text is public domain in the United States and freely usable by anyone. FIP's later edited editions (the "Second Edition" and subsequent printings, which add FIP-authored prefaces, supplements, and editorial changes) are **not** what this app uses and are not covered here. If you want the FIP edition, get it from FIP.

The app code, audio recordings, video renderings, cover art, and visual designs in this repository are original works of the copyright holder and are licensed separately below.

## License

CC BY-SA 4.0 for original works in this repository (code, recordings, art, docs). The *Course* text itself is public domain and not covered by this license — you don't need permission to redistribute it because no one owns it. See [LICENSE](LICENSE) for full terms.
