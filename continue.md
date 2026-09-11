# continue.md

LIVE: Read tab — add Minute shelf (calendar of past minutes as readings). Spec: `docs/superpowers/specs/2026-09-10-tab-ia-design.md`. He approved it.

NEXT: Listen four shelves, then Video four shelves, then tvOS Read opens the reading. Copy last.

Do not rebuild text size. Watch is done. Do not touch the backend, prd.json, or native visionOS. Do not invent TTS. Do not host MP4s. Do not rebuild `TVPlayerView` — reuse it for Video when there is no YouTube. Apple TV still composes from the MP3s.

Start at `LessonsView`: fourth shelf `Minute`, reuse `ArchiveCalendarView`. Destination is a `MinuteDateRef` (not `String` — lesson numbers are `Int`). Open `DailyMinuteCard` or `ArchivedReadingCard`, never `LiteYouTubeCard`. From the Read lesson spine, pass `presentsVideo: false`. Default shelf stays Lesson.

New Swift files need four `project.pbxproj` lines each, both app and tvOS Sources phases. Pattern: `SegmentReadingView.swift`.

Branch `ralph/acim-3.9-to-5-finish-2026-04-14`.
