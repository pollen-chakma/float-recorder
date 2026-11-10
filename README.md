# Float Recorder

A native Apple Silicon Mac screen recorder for macOS 15 or later.

## Open

Double-click **Float Recorder.app** in this folder. A floating bar appears, with a menu bar icon as a backup way to reach controls.

- Red circle: start after a three-second countdown. Square: stop and save.
- Speaker: enable computer audio, including meeting participants and browser videos.
- Microphone: enable your voice or an external audio input. Choose the device in Settings.
- Folder: reveal the last saved recording, or open the save folder.
- Gear: select a display, microphone, storage folder, video quality (720p / 1080p / 4K), frame rate (30 / 60 fps), and format (MP4 / MOV).
- Circled X: hide the floating bar, cancel the countdown, or quit. Hiding keeps the app and any recording running; use the menu bar icon → Show recorder to restore it. Quitting while recording stops and saves first.
- Drag the bar by its left handle/background to reposition it. The app's own windows are excluded from recordings.

On the first recording, macOS asks for Screen & System Audio Recording permission. Allow Float Recorder in System Settings → Privacy & Security, then quit and reopen if macOS requests it. Microphone permission is requested only when that option is enabled.

Defaults: computer audio on, microphone off, files in `~/Movies/Float Recorder`. Output is H.264 in MP4 or MOV, at 30 or 60 fps. Resolution fits within 1280×720, 1920×1080, or 3840×2160 without upscaling; default is 1080p / 30 fps / MP4. Use headphones when recording both audio sources to avoid echo. Protected playback can appear blank or silent. System audio includes other apps and notifications on the Mac, so silence unwanted apps before recording.

Stop and wait for **Saved ✓** before quitting or disconnecting the save drive. Quit saves an active recording before exiting. Pause, editing, webcam overlay, and automatic upload are not included.

## Build

Run `zsh build.sh` from this folder. Requires Apple's Swift compiler / Command Line Tools. The script builds an Apple Silicon app bundle and applies a local ad-hoc signature. No third-party dependencies or virtual audio driver are needed. The app is a local build, not notarized for distribution.

## Validation

Compilation and launch are checked locally. End-to-end recording with system audio and microphone needs macOS privacy permissions and a manual playback check. To verify: play a short video with headphones, enable the microphone, record for ten seconds while speaking, stop, and use the folder button to open the MP4. Confirm the screen, video audio, and your voice are present.
