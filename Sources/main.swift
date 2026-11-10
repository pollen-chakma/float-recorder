import AppKit
import SwiftUI
import ScreenCaptureKit
import AVFoundation

@MainActor
final class Recorder: NSObject, ObservableObject, SCStreamDelegate, SCRecordingOutputDelegate {
    @Published var phase = "Ready"
    @Published var busy = false
    @Published var recording = false
    @Published var systemAudio = UserDefaults.standard.object(forKey: "systemAudio") as? Bool ?? true
    @Published var microphone = UserDefaults.standard.bool(forKey: "microphone")
    @Published var micID = UserDefaults.standard.string(forKey: "micID") ?? ""
    @Published var folder = UserDefaults.standard.string(forKey: "folder") ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/Float Recorder").path
    @Published var displays: [SCDisplay] = []
    @Published var displayID: UInt32 = 0
    @Published var lastURL: URL?
    @Published var elapsed = 0
    var stream: SCStream?
    var output: SCRecordingOutput?
    var pendingURL: URL?
    var timer: Timer?
    var started: Date?
    @Published var quality = UserDefaults.standard.string(forKey: "quality") ?? "1080p"
    @Published var format = UserDefaults.standard.string(forKey: "format") ?? "mp4"
    @Published var fps = UserDefaults.standard.integer(forKey: "fps") == 60 ? 60 : 30
    @Published var countingDown = false
    var startTask: Task<Void, Never>?
    var quitAfterSave = false
    var hideAction: (() -> Void)?
    var quitAction: (() -> Void)?
    var settingsAction: (() -> Void)?
    var devices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified).devices
    }
    var clock: String { String(format: "%02d:%02d:%02d", elapsed / 3600, elapsed / 60 % 60, elapsed % 60) }
    func savePreferences() {
        let d = UserDefaults.standard
        d.set(quality, forKey: "quality"); d.set(format, forKey: "format"); d.set(fps, forKey: "fps")
        d.set(folder, forKey: "folder"); d.set(systemAudio, forKey: "systemAudio")
        d.set(microphone, forKey: "microphone"); d.set(micID, forKey: "micID")
    }
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: folder)
        if panel.runModal() == .OK, let url = panel.url { folder = url.path; savePreferences() }
    }
    func reveal() {
        if let url = lastURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        else { try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true); NSWorkspace.shared.open(URL(fileURLWithPath: folder)) }
    }
    func refreshDisplays() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            displays = content.displays
            if !displays.contains(where: { $0.displayID == displayID }) { displayID = displays.first?.displayID ?? 0 }
        } catch { showError(error) }
    }
    func start() async {
        guard !busy else { return }
        busy = true; phase = "Preparing…"; savePreferences()
        do {
            if microphone {
                let allowed = await AVCaptureDevice.requestAccess(for: .audio)
                guard allowed else { throw NSError(domain: "FloatRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone access is off. Enable Float Recorder in System Settings → Privacy & Security → Microphone, or turn off the microphone button."]) }
            }
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else { throw NSError(domain: "FloatRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "No display is available."]) }
            let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            let config = SCStreamConfiguration()
            let maxSize: (Double, Double) = quality == "720p" ? (1280, 720) : quality == "1080p" ? (1920, 1080) : (3840, 2160)
            let scale = min(1.0, min(maxSize.0 / Double(display.width), maxSize.1 / Double(display.height)))
            config.width = max(2, Int(Double(display.width) * scale) / 2 * 2)
            config.height = max(2, Int(Double(display.height) * scale) / 2 * 2)
            config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(fps))
            config.showsCursor = true; config.capturesAudio = systemAudio
            config.excludesCurrentProcessAudio = true
            config.captureMicrophone = microphone
            config.microphoneCaptureDeviceID = micID.isEmpty ? nil : micID
            config.sampleRate = 48000; config.channelCount = 2
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            let stamp = DateFormatter(); stamp.dateFormat = "yyyy-MM-dd HH-mm-ss"
            let url = URL(fileURLWithPath: folder).appendingPathComponent("Recording \(stamp.string(from: Date())) \(UUID().uuidString.prefix(4)).\(format)")
            let destination = SCRecordingOutputConfiguration()
            destination.outputURL = url; destination.outputFileType = format == "mov" ? .mov : .mp4; destination.videoCodecType = .h264
            let capture = SCStream(filter: filter, configuration: config, delegate: self)
            let writer = SCRecordingOutput(configuration: destination, delegate: self)
            try capture.addRecordingOutput(writer)
            stream = capture; output = writer; pendingURL = url
            countingDown = true
            for count in (1...3).reversed() { phase = "\(count)"; try await Task.sleep(for: .seconds(1)) }
            countingDown = false
            try Task.checkCancellation()
            phase = "Starting…"
            try await capture.startCapture()
        } catch is CancellationError { clear(); phase = "Cancelled" }
        catch { clear(); showError(error) }
    }
    func stop() async {
        guard recording, let stream else { return }
        recording = false; phase = "Saving…"; timer?.invalidate()
        do { try await stream.stopCapture() } catch { clear(); showError(error) }
    }
    func clear() {
        timer?.invalidate(); timer = nil; countingDown = false; recording = false; busy = false
        stream = nil; output = nil; pendingURL = nil
    }
    func showError(_ error: Error) {
        quitAfterSave = false
        phase = "Needs attention"
        let alert = NSAlert(); alert.messageText = "Couldn’t record"
        alert.informativeText = error.localizedDescription + "\n\nFor screen access, open System Settings → Privacy & Security → Screen & System Audio Recording and allow Float Recorder. You may need to quit and reopen the app."
        alert.addButton(withTitle: "OK"); alert.runModal()
    }
    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in
            self.recording = true; self.phase = "Recording"; self.elapsed = 0; self.started = Date()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in guard let self, let started = self.started else { return }; self.elapsed = Int(Date().timeIntervalSince(started)) }
            }
        }
    }
    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.lastURL = self.pendingURL; self.clear(); self.phase = "Saved ✓"; if self.quitAfterSave { NSApp.terminate(nil) } }
    }
    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in self.clear(); self.showError(error) }
    }
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in self.clear(); self.showError(error) }
    }
}

struct Bar: View {
    @ObservedObject var model: Recorder
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "line.3.horizontal").foregroundStyle(.secondary).help("Drag the bar to move it")
            Button { if model.recording { Task { await model.stop() } } else { model.startTask = Task { await model.start() } } } label: {
                Image(systemName: model.recording ? "stop.fill" : "record.circle.fill")
                    .font(.system(size: 26)).foregroundStyle(model.recording ? .white : .red)
                    .frame(width: 44, height: 44).background(model.recording ? Color.red : Color.white.opacity(0.08), in: Circle())
            }.disabled(model.busy && !model.recording).help(model.recording ? "Stop and save" : "Start recording · 3 second countdown")
            VStack(alignment: .leading, spacing: 3) {
                Text(model.recording ? model.clock : "Float Recorder").font(.system(.body, design: .monospaced).weight(.semibold))
                Text(model.phase).font(.caption).foregroundStyle(model.recording ? .red : .secondary)
            }.frame(width: 128, alignment: .leading)
            Divider().frame(height: 28)
            Button { model.systemAudio.toggle(); model.savePreferences() } label: { Image(systemName: model.systemAudio ? "speaker.wave.2.fill" : "speaker.slash.fill").foregroundStyle(model.systemAudio ? .mint : .secondary) }.disabled(model.busy).help("Computer audio: \(model.systemAudio ? "on" : "off")")
            Button { model.microphone.toggle(); model.savePreferences() } label: { Image(systemName: model.microphone ? "mic.fill" : "mic.slash.fill").foregroundStyle(model.microphone ? .mint : .secondary) }.disabled(model.busy).help("Microphone: \(model.microphone ? "on" : "off")")
            Button { model.reveal() } label: { Image(systemName: "folder") }.help("Show recordings")
            Button { model.settingsAction?() } label: { Image(systemName: "gearshape") }.help("Settings")
            Menu {
                Button("Hide floating bar") { model.hideAction?() }
                if model.countingDown { Button("Cancel countdown") { model.startTask?.cancel() } }
                Button(model.recording ? "Stop, save and quit" : "Quit Float Recorder") { model.quitAction?() }
            } label: { Image(systemName: "xmark.circle") }.menuStyle(.borderlessButton).fixedSize().help("Hide, cancel or quit")
        }.buttonStyle(.plain).font(.system(size: 18)).padding(.horizontal, 20).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24)).environment(\.colorScheme, .dark)
    }
}

struct Preferences: View {
    @ObservedObject var model: Recorder
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Keep it simple.").font(.largeTitle.bold())
            Text("Your screen. Your sound. One button.").foregroundStyle(.secondary)
            GroupBox("Capture") {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Display", selection: $model.displayID) {
                        if model.displays.isEmpty { Text("Load displays below").tag(UInt32(0)) }
                        ForEach(model.displays, id: \.displayID) { d in Text("Display \(d.displayID) · \(d.width) × \(d.height)").tag(d.displayID) }
                    }
                    Button("Load / refresh displays") { Task { await model.refreshDisplays() } }
                    Toggle("Record computer audio (meetings, videos, apps)", isOn: $model.systemAudio)
                    Toggle("Record microphone", isOn: $model.microphone)
                    Picker("Microphone", selection: $model.micID) {
                        Text("System default").tag("")
                        ForEach(model.devices, id: \.uniqueID) { Text($0.localizedName).tag($0.uniqueID) }
                    }
                }.padding(10)
            }.disabled(model.busy)
            GroupBox("Video") {
                VStack(spacing: 12) {
                    Picker("Quality", selection: $model.quality) {
                        Text("720p · smaller files").tag("720p")
                        Text("1080p · recommended").tag("1080p")
                        Text("4K · more detail").tag("4k")
                    }
                    Picker("Frame rate", selection: $model.fps) {
                        Text("30 fps").tag(30); Text("60 fps · smoother motion").tag(60)
                    }
                    Picker("Format", selection: $model.format) {
                        Text("MP4 · widely compatible").tag("mp4")
                        Text("MOV · QuickTime").tag("mov")
                    }
                    Text("H.264 video. Fits within the selected resolution without stretching or upscaling.").font(.caption).foregroundStyle(.secondary)
                }.padding(10)
            }.disabled(model.busy)
            GroupBox("Save recordings") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.folder).font(.caption).textSelection(.enabled).lineLimit(2)
                    HStack { Button("Choose folder…") { model.chooseFolder() }; Button("Open folder") { model.reveal() } }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }.disabled(model.busy)
            Text("The floating bar is excluded from recordings. Drag it anywhere.\nUse headphones to avoid microphone echo from speakers.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Hide bar") { model.hideAction?() }
                Button(model.recording ? "Save and quit" : "Quit app") { model.quitAction?() }
                if model.countingDown { Button("Cancel countdown") { model.startTask?.cancel() } }
            }
            HStack {
                Button("Screen recording permission…") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!) }
                Spacer()
                Text("macOS 15+").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(26).frame(width: 480)
        .onDisappear { model.savePreferences() }
        .onChange(of: model.systemAudio) { model.savePreferences() }
        .onChange(of: model.microphone) { model.savePreferences() }
        .onChange(of: model.quality) { model.savePreferences() }
        .onChange(of: model.format) { model.savePreferences() }
        .onChange(of: model.fps) { model.savePreferences() }
        .onChange(of: model.micID) { model.savePreferences() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Recorder()
    var panel: NSPanel!
    var preferences: NSWindow?
    var status: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 72), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true; panel.level = .floating; panel.backgroundColor = .clear; panel.isOpaque = false
        panel.hasShadow = true; panel.isMovableByWindowBackground = true; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: Bar(model: model))
        panel.center(); panel.orderFrontRegardless()
        model.settingsAction = { [weak self] in self?.showSettings() }
        model.hideAction = { [weak self] in self?.hideBar() }
        model.quitAction = { [weak self] in self?.quit() }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Float Recorder")
        let menu = NSMenu()
        for (title, action, key) in [("Show recorder", #selector(showBar), ""), ("Hide floating bar", #selector(hideBar), ""), ("Settings…", #selector(showSettings), ","), ("Stop and save", #selector(stopRecording), ""), ("Quit Float Recorder", #selector(quit), "q")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
        }
        status.menu = menu
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showBar()
        return true
    }
    @objc func hideBar() { panel.orderOut(nil) }
    @objc func showBar() { panel.orderFrontRegardless() }
    @objc func stopRecording() { Task { await model.stop() } }
    @objc func showSettings() {
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 532, height: 540), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Float Recorder Settings"; window.contentView = NSHostingView(rootView: Preferences(model: model))
            window.isReleasedWhenClosed = false; window.center(); preferences = window
        }
        preferences?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func quit() {
        if model.recording {
            model.quitAfterSave = true
            Task { await model.stop() }
        } else if model.countingDown {
            model.startTask?.cancel()
            NSApp.terminate(nil)
        } else if model.busy {
            let alert = NSAlert(); alert.messageText = "Finish your recording first"
            alert.informativeText = "Stop the recording and wait for Saved before quitting."; alert.runModal()
        } else { NSApp.terminate(nil) }
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    withExtendedLifetime(delegate) { application.run() }
}
