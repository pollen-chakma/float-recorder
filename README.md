# Float Recorder 🎬

A native, lightweight floating screen and internal system audio recorder designed exclusively for Apple Silicon Macs running **macOS 15 (Sequoia)** or later.

Built entirely with native Apple frameworks (`ScreenCaptureKit`, `AVFoundation`, `SwiftUI`, and `AppKit`) — **zero third-party dependencies** or virtual audio drivers required.

---

## 💻 System Requirements

- **Mac**: Apple Silicon (M1, M2, M3, M4, or later)
- **OS**: macOS 15.0 (Sequoia) or newer
- **Permissions**: Screen & System Audio Recording, Microphone (optional)

---

## 📥 Installation

Choose whichever option works best for you:

### Option 1: Download Pre-compiled App (Recommended for Most Users)

No coding or terminal experience needed.

1. **Download the app**:
   Go to the [GitHub Releases page](https://github.com/pollen-chakma/float-recorder/releases/latest) and download `Float-Recorder-macOS.zip`.

2. **Extract & Install**:
   * Double-click the downloaded `.zip` file to extract `Float Recorder.app`.
   * Drag `Float Recorder.app` into your **Applications** folder (`/Applications`).

3. **Opening for the first time (macOS Gatekeeper)**:
   Because this app is independently compiled and not signed with a paid Apple Developer certificate, macOS will display an *"unidentified developer"* or *"cannot verify"* prompt on the first launch.
   * **To open**: Right-click (or <kbd>Control</kbd>-click) **Float Recorder.app** → click **Open** → then click **Open** in the dialog.
   * *Alternative*: Go to **System Settings → Privacy & Security**, scroll down to the Security section, and click **Open Anyway**.

---

### Option 2: Build & Compile from Source (For Developers)

If you prefer building directly from the Swift source code:

1. **Ensure you have Apple Command Line Tools installed**:
   ```bash
   xcode-select --install
   ```

2. **Clone the repository**:
   ```bash
   git clone https://github.com/pollen-chakma/float-recorder.git
   cd float-recorder
   ```

3. **Compile the app**:
   Run the build script:
   ```bash
   zsh build.sh
   ```
   *(This uses `swiftc` to compile `Sources/main.swift` and bundles it into `Float Recorder.app` with an ad-hoc local signature in ~5 seconds).*

4. **Launch or install**:
   ```bash
   # Launch immediately
   open "Float Recorder.app"

   # Or install to your Applications folder
   cp -R "Float Recorder.app" /Applications/
   ```

---

## 🔒 Required macOS Permissions

On your first recording, macOS will prompt you for permissions:

1. **Screen & System Audio Recording**: Required to capture your display and computer sound.
   * Go to **System Settings → Privacy & Security → Screen & System Audio Recording**.
   * Toggle **Float Recorder** to **ON**. (macOS may require you to quit and reopen the app).
2. **Microphone**: Only requested if you toggle the microphone on to record your voice.

---

## 🚀 How to Use

When opened, a compact floating bar appears on your screen, accompanied by an icon in your macOS menu bar.

### Floating Bar Controls:
* **🔴 Red Circle**: Starts recording after a 3-second countdown.
* **⏹ Square**: Stops recording and finishes saving the file.
* **🔊 Speaker Icon**: Toggles recording computer audio (browser videos, meetings, system sounds).
* **🎙 Microphone Icon**: Toggles microphone input for voiceover/narration.
* **📁 Folder Icon**: Reveals your last recording in Finder or opens the recordings folder.
* **⚙️ Gear Icon**: Opens Settings to configure:
  * **Display**: Select which monitor to capture (multi-monitor setups).
  * **Audio Device**: Choose your specific microphone or input device.
  * **Save Folder**: Defaults to `~/Movies/Float Recorder`.
  * **Video Quality**: 720p, 1080p, or 4K.
  * **Frame Rate**: 30 FPS or 60 FPS.
  * **Format**: MP4 or MOV (H.264).
* **✖️ Circled X**: Hides the floating bar or quits.
  * *Note*: If hidden, click the menu bar icon (●) and select **"Show recorder"** to bring it back. Quitting while recording will safely save your video before exiting.

> [!TIP]
> Use headphones when recording both system audio and microphone simultaneously to avoid audio feedback/echo.

---

## 🛠 Project Structure

```text
├── Sources/
│   └── main.swift        # Complete Swift application logic (UI & recording engine)
├── Info.plist            # macOS app bundle metadata and permission descriptions
├── build.sh              # Standalone Swift compilation and signing script
├── .gitignore            # Excludes build caches (.build/) and binaries
└── README.md             # Project documentation and installation guide
```

---

## 👤 Author

Developed by **[Pollen Chakma](https://github.com/pollen-chakma)**.
