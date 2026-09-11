# continue.md

LIVE: Video tab — same four shelves (Minute / Lesson / Text / Manual); YouTube when a recording exists, composed player otherwise (Apple TV always composes). Spec: `docs/superpowers/specs/2026-09-10-tab-ia-design.md`.

NEXT: tvOS Read opens the reading. Copy last. Shared shelf chrome after that.

Listen is in HEAD (`03f02ea`). Do not redo Listen. Do not redo Read. Do not rebuild `TVPlayerView`. Do not invent TTS. Do not host MP4s. Do not touch the backend, prd.json, Watch, or native visionOS.

Read already has four shelves via `CourseShelf`. Listen has the same picker, a resume ribbon, unplayed rows visible, play omitted when there is no MP3. Video today is still the Archive calendar in `Views/Archive/ArchiveView.swift`.

Plan Video first. Do not run `./build.sh` or any verify until that plan is finished. Then implement only Video.

New Swift files need four `project.pbxproj` lines each, both app and tvOS Sources phases. Pattern: `SegmentReadingView.swift`.

HEAD `03f02ea` on `ralph/acim-3.9-to-5-finish-2026-04-14`.
