# continue.md

LIVE: Video tab — same four shelves (Minute / Lesson / Text / Manual); YouTube when a recording exists, composed player otherwise (Apple TV always composes). Spec: `docs/superpowers/specs/2026-09-10-tab-ia-design.md`. Plan: `docs/superpowers/plans/2026-09-10-video-four-shelves.md`. He approved the spec. Default shelf is Lesson, matching Read and Listen.

NEXT: Task 4 — Four shelves on the Video tab (`ArchiveView` + `ArchiveDateDetailView`). Then Task 5. Do not start tvOS Read. Do not redo Read or Listen.

Do not rebuild `TVPlayerView` — the fence is lifted. Do not invent TTS. Do not host MP4s. Do not pull YouTube on tvOS. Do not touch Watch, the backend, prd.json, or native visionOS. Do not rename tabs. Reuse `CourseShelf`. Keep `YouTubeID.candidates`.

`./build.sh` runs only in Task 5, after the library, the player fence, the views, the pbxproj lines, and the rewritten checks exist.

`VideoPlayableRow.swift` is `AA000002751` / `AA000001751` / `C0DE0001A11CE0B1000017`. `VideoTextChapterView.swift` is `AA000002752` / `AA000001752` / `C0DE0001A11CE0B1000018`. Do not re-register them. Wire them in ArchiveView; do not push `TextSectionView`.
