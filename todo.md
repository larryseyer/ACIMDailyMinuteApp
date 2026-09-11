# ACIM Daily Minute — open items

One sentence per item, two at the most. Current and future only. Git is history.

---

## LIVE — the presentation redesign

Plan and exact spec: `docs/superpowers/plans/2026-09-11-ios-presentation-redesign.md`.
Visual spec: `docs/design/2026-09-11-ios-presentation.html`.

- [ ] Step 1 — token layer: `Metric`, `ACIMType`, `CitationLabel`, the `Ink` / `Surface` / `Raised` / `Rule` colorsets.
- [ ] Step 2 — Today: masthead, passage as a page, citation band, action row, lesson and practice cards.
- [ ] Step 3 — the practice sheet over `PracticePlanner`.
- [ ] Step 4 — the Course tab: three shelf implementations collapse to one, five tabs to three, `ACIMTabBar` replaces the system bar and `MacBottomTabBar`.
- [ ] Step 5 — the reading and the medium band, through `ReadingScaffold`.
- [ ] Step 6 — Now Playing, the full player.
- [ ] Step 7 — Saved as one filtered stream.
- [ ] Step 8 — iPad and Mac `NavigationSplitView`; decide the iPad reading column.
- [ ] Step 9 — Apple TV, Watch, widgets.
- [ ] Step 10 — onboarding copy, `APP_STORE_LISTING.md`, `store-support-page.md`.

## CARRIED — still true, now blocked behind the redesign

- [ ] Mac Video sheets have no min frame; Listen's YouTube sheet is 720×405.
- [ ] Unnarrated compose does not stop Listen audio that is already playing.

## HIS CALL

- [ ] The small label above a reading wraps onto two lines at huge system text sizes and the header grows. Acceptable?
- [ ] Preface citations: `Pref.4` does not say which of the two Preface parts it is in, and changing it changes backups already exported. Leave it?
- [ ] Companion note under Settings > About: three wording departures are his to veto.
- [ ] Import summary wording is his to keep or change.
- [ ] Citations stay `T-5.3` Arabic unless he overturns that.

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
