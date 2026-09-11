# continue.md

LIVE: Implement Listen four shelves from `docs/superpowers/plans/2026-09-10-listen-four-shelves.md`. Spec: `docs/superpowers/specs/2026-09-10-tab-ia-design.md`.

NEXT: Video four shelves, then tvOS Read opens the reading. Copy last.

Plan is finished. Implement only Listen. Do not start Video. Do not redo Read.

Do not rebuild text size. Watch is done. Do not touch the backend, prd.json, or native visionOS. Do not invent TTS. Do not host MP4s. Do not rebuild `TVPlayerView`.

Read already has the four shelves via `CourseShelf` (`Utilities/CourseShelf.swift`) in `LessonsView`. Reuse that picker. Do not invent a second enum. Default on Read is Lesson; Minute is first in the picker. Daily Minute still holds no reading ribbon.

Listen today is activity-only in `Views/Listen/ListenView.swift`: now playing, part-finished, downloaded, finished. Unplayed audio is invisible. Text and Manual have no listening home. Keep `AudioManager`, downloads, listened marks. Activity becomes a Now Playing / Continue ribbon on top, not the tab. No play control on a row with no MP3 — show the row, omit play. `ContentView` already hides the floating mini player on this tab; `ListenView` draws `MiniPlayerView` in the bottom inset. Keep that.

Existing checks: `./tools/verify_listen_activity.sh`, `verify_listen_play_pause.sh`, `verify_listen_session.sh`. New check: Listen shows unplayed.

New Swift files need four `project.pbxproj` lines each, both app and tvOS Sources phases. Pattern: `SegmentReadingView.swift`.

HEAD `e7780bd` on `ralph/acim-3.9-to-5-finish-2026-04-14`.
