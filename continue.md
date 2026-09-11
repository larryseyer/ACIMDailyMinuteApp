# continue.md

LIVE: Listen tab — same four shelves (Minute / Lesson / Text / Manual), resume ribbon on top; unplayed audio is visible. Spec: `docs/superpowers/specs/2026-09-10-tab-ia-design.md`.

NEXT: Video four shelves, then tvOS Read opens the reading. Copy last.

Do not rebuild text size. Watch is done. Do not touch the backend, prd.json, or native visionOS. Do not invent TTS. Do not host MP4s. Do not rebuild `TVPlayerView` — reuse it for Video when there is no YouTube. Apple TV still composes from the MP3s.

`CourseShelf` is the picker. Read already has Minute / Lesson / Text / Manual. Listen today is activity buckets in `ListenView`. Catalogue first; keep `AudioManager`, downloads, listened marks. Unplayed audio is visible. No play control on a row with no MP3. Resume ribbon on top. New Swift files need four `project.pbxproj` lines each, both app and tvOS Sources phases.

Branch `ralph/acim-3.9-to-5-finish-2026-04-14`.
