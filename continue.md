# continue.md

LIVE: Video tab YouTube is on the iPhone, this Mac, and the iPad sim. He is checking that a day plays the video (thumbnail, tap to play). If he says it looks great, delete that item.

NEXT: HIS CALL items wait on him. Then CloudKit Development → Production before any release build. Screenshots after iPhone, iPad, Watch, Apple TV, and widgets are finished.

Do not rebuild text size. Watch is done. Do not touch the backend, prd.json, or native visionOS. Apple TV still rebuilds video from the MP3s — leave that path.

Video tab: `ArchiveDateDetailView` shows `LiteYouTubeCard`. Minute ids come from the podcast `<link>` first (`ArchiveView.refreshPodcasts`); lesson ids come from `DailyLesson` first. `LiteYouTubeCard` walks a 404 thumbnail to the next id. Prove with `./tools/verify_video_tab.sh`.

Branch `ralph/acim-3.9-to-5-finish-2026-04-14`. HEAD `a5b611d`.
