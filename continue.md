# continue.md

LIVE: Video tab — same four shelves (Minute / Lesson / Text / Manual); YouTube when a recording exists, composed player otherwise (Apple TV always composes). Spec: `docs/superpowers/specs/2026-09-10-tab-ia-design.md`. He approved it.

NEXT: tvOS Read opens the reading, not the player. Copy last. Shared shelf chrome after that.

Plan Video first. Do not run `./build.sh` or any verify until that plan is finished. Then implement only Video. Do not start tvOS Read. Do not redo Read or Listen.

Do not rebuild `TVPlayerView`. Do not invent TTS. Do not host MP4s. Do not pull YouTube on tvOS. Do not touch Watch, the backend, prd.json, or native visionOS. Do not rename tabs.

Read and Listen already have the four shelves via `CourseShelf` (`Utilities/CourseShelf.swift`). Reuse that picker. Do not invent a second enum. Default on Read and Listen is Lesson; Minute is first in the picker. Video should match unless the plan argues Minute (today’s calendar landing). Shared chrome is a later item — copy the picker, do not extract a shared shell yet.

Video today is still the Archive calendar: `Views/Archive/ArchiveView.swift` pushes `String` dates into `ArchiveDateDetailView`. iPhone / iPad / Mac play `LiteYouTubeCard`; tvOS Select calls `openPlayer`. A day with no YouTube is not a composed-player row yet. Text and Manual have no Video home. Keep `YouTubeID.candidates` / thumbnail advance — he is still checking that a day plays on iPhone, Mac, and iPad sim (HIS CALL). Do not break that path.

`TVPlayerView.swift` is `#if os(tvOS)` for the whole file. iOS/Mac Video without YouTube still needs composition (spec). Lift the fence or share the composition; do not rewrite the player. `TVPlayerItem` already has `workbookLesson`, `textSection(chapter:section:)`, and `manualSection(number:)`.

Opening a Video row starts the picture, never a reading (`TextSectionView` / `LessonDetailView` / `MinuteReadingView`) and never Listen’s `playOrToggle` as the tab’s job. Absence of a recording is not an empty state: show the row, compose.

Existing checks: `./tools/verify_video_tab.sh`, `verify_tv_player.sh`, `verify_archive_calendar.sh`. New check: Video opens a Text section with no YouTube.

New Swift files need four `project.pbxproj` lines each, both app and tvOS Sources phases. Pattern: `SegmentReadingView.swift`. Listen already used `AA000002740`–`743`.

HEAD `61790fc` on `ralph/acim-3.9-to-5-finish-2026-04-14`.
