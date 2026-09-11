# ACIM Daily Minute — open items

One sentence per item, two at the most. Current and future only. Git is history.

Priority one is the presentation redesign. Everything below LIVE waits.

---

## LIVE — priority one: the presentation redesign

Plan: `2026-09-11-Design_Plan.md`. Visual: `docs/design/2026-09-11-ios-presentation.html`.
This plan supersedes every other UI plan. Do not pick up any other section until
step 10 is on the devices.

- [ ] Step 2 — Today: masthead, passage as a page, citation band, action row, lesson and practice cards.
- [ ] Step 3 — the practice sheet over `PracticePlanner`.
- [ ] Step 4 — the Course tab: three shelves collapse to one, five tabs to three, `ACIMTabBar`, onboarding.
- [ ] Step 5 — the reading and the medium band, through `ReadingScaffold`.
- [ ] Step 6 — Now Playing, the full player.
- [ ] Step 7 — Saved as one filtered stream.
- [ ] Step 8 — iPad and Mac `NavigationSplitView`; the two questions in §O.
- [ ] Step 9 — Apple TV, Watch, widgets.
- [ ] Step 10 — `APP_STORE_LISTING.md`, `store-support-page.md`, screenshots.

## CARRIED — blocked behind the redesign

- [ ] Mac Video sheets have no min frame; Listen's YouTube sheet is 720×405.

## BEFORE SUBMIT — after the redesign is on the devices

Store record exists (iOS, macOS, tvOS). Do not add a visionOS platform.

- [ ] Deploy the CloudKit schema from Development to Production before any release build.
- [ ] Remake every store screenshot against the finished redesign.
- [ ] Tick compatible iPhone/iPad on Vision Pro in App Store Connect, then submit. The support page is already on the site.

## AFTER 1.0

1.0 is iPhone, iPad, Mac, Watch, and Apple TV. Vision Pro 1.0 is iPhone-compatible mode, not a native target.

- [ ] Native visionOS later.
- [ ] A static PWA reader for Windows/Linux, same backup `.json`, rules ported not re-invented.
- [ ] Whether Android is that PWA or a later native app.
