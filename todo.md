# ACIM Daily Minute — open items

One sentence per item, two at the most. Current and future only. Git is history.

---

## LIVE — #1

- [ ] Read tab: add Minute shelf (calendar of past minutes as readings). Spec: `docs/superpowers/specs/2026-09-10-tab-ia-design.md`.
- [ ] Listen tab: same four shelves (Minute / Lesson / Text / Manual), resume ribbon on top; unplayed audio is visible.
- [ ] Video tab: same four shelves; YouTube when a recording exists, composed player otherwise (Apple TV always composes).
- [ ] tvOS Read opens the reading, not the player. Today stays player-first.
- [ ] Onboarding, App Store listing, and support copy: Video is no longer “browse by date.”
- [ ] Shared shelf chrome so Read / Listen / Video cannot drift.

## HIS CALL

- [ ] Video tab YouTube on iPhone, Mac, and iPad sim — he is checking that a day plays the video (thumbnail, tap to play).
- [ ] The small label above a reading ("Daily Minute", "Lesson 84") wraps onto two lines when system text is huge, and the header gets taller. Is that OK?
- [ ] Preface citations: `Pref.4` does not say which of the two Preface parts it is in. Changing that changes backups already exported. Leave it?
- [ ] Companion note under Settings > About: three wording departures are his to veto.
- [ ] Import summary wording is his to keep or change.
- [ ] Citations stay `T-5.3` Arabic unless he overturns that.

## BEFORE SUBMIT — after he has tested this build

Store record exists (iOS, macOS, tvOS). Do not add a visionOS platform. Do not upload the current shots.

- [ ] Deploy the CloudKit schema from Development to Production before any release build.
- [ ] Remake every store screenshot after iPhone, iPad, Watch, Apple TV, and widgets are finished. The current set still says Archive; the Mac shot is the wrong size.
- [ ] Tick compatible iPhone/iPad on Vision Pro in App Store Connect, then submit. The support page is already on the site.

## AFTER 13 SEPTEMBER 2026

1.0 is iPhone, iPad, Mac, Watch, and Apple TV. Vision Pro 1.0 is iPhone-compatible mode, not a native target.

- [ ] Native visionOS later.
- [ ] A static PWA reader for Windows/Linux after 1.0, same backup `.json`, rules ported not re-invented.
- [ ] Whether Android is that PWA or a later native app — after 1.0.
