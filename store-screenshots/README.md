# App Store screenshots

Taken from simulators. Upload from this folder in App Store Connect.

Capture: `tools/capture_store_screenshots.sh` — one simulator at a time. Lesson scene opens unpublished 256 so YouTube stays closed. Notification permission is denied before launch.

## Ready (clean)

### iPhone 6.7 (1320×2868)

- `iphone-6.7/01-today.png`
- `iphone-6.7/02-read.png`
- `iphone-6.7/03-lesson.png` — Lesson 256, bundled text, no YouTube
- `iphone-6.7/04-archive.png`
- `iphone-6.7/05-saved.png` — empty Saved is honest; a populated list would be better
- `iphone-6.7/06-settings.png`

### iPad 13 (2064×2752)

- `ipad-13/01-today.png`
- `ipad-13/02-read.png`
- `ipad-13/03-lesson.png`
- `ipad-13/04-archive.png`
- `ipad-13/05-saved.png`
- `ipad-13/06-settings.png` — Settings sheet over Today

### Apple TV 1080

- `appletv-1080/01-today.png`
- `appletv-1080/02-read.png`
- `appletv-1080/03-listen.png`
- `appletv-1080/04-archive.png`

### Apple Watch 46mm

- `watch-46mm/01-today.png`

### Mac (window only)

- `mac/01-today.png` — real app window. 1000×1800; Mac App Store wants 1280×800 (or 1440×900 / 2560×1600 / 2880×1800). Resize the window and retake.

## Phone reference (wrong size for the 6.7 slot)

- `iphone-6.7/iPhone lesson screen.png` — Lesson 256 on a real iPhone, 1125×2436. Keep. Do not upload as 6.7-inch.

## Still need you

- **Mac** — size the window to a store size and take Today, Read, Video, Saved, Settings. Automated capture cannot get a CGWindowID through System Events; Today was grabbed once at the current 500×900pt window.
- **Apple Watch watch face** — circular and rectangular complications. Only a real watch can place those.

Do not upload any shot that still has “Open in app?” or “Would Like to Send You Notifications” on it.
