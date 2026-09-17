import AppKit
import AVFoundation
import Carbon

struct VideoClip {
    let id: String
    let title: String
    let url: URL
    let thumbnail: NSImage?
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var toggleItem: NSMenuItem!
    private var remainingItem: NSMenuItem!
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var overlay: OverlayWindow?
    private var timer: Timer?
    private var deadline: Date?
    private var running = false
    private var duration = UserDefaults.standard.object(forKey: "duration") as? Double ?? 300
    private var height = UserDefaults.standard.object(forKey: "height") as? Double ?? 320
    private var muted = UserDefaults.standard.object(forKey: "muted") as? Bool ?? true
    private var hotKey: EventHotKeyRef?
    private var clips: [VideoClip] = []
    private var currentClip: VideoClip?

    private func loadClips() {
        guard let resources = Bundle.main.resourceURL else { return }
        let library = resources.appendingPathComponent("Videos")
        let folders = (try? FileManager.default.contentsOfDirectory(at: library, includingPropertiesForKeys: nil)) ?? []
        clips = folders.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }.compactMap { folder in
            let url = folder.appendingPathComponent("transparent.mov")
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let image = NSImage(contentsOf: folder.appendingPathComponent("thumbnail.png"))
            image?.size = NSSize(width: 40, height: 60)
            return VideoClip(id: folder.lastPathComponent, title: folder.lastPathComponent, url: url, thumbnail: image)
        }
        if let original = Bundle.main.url(forResource: "WinCell", withExtension: "mov") {
            let image = NSImage(contentsOf: resources.appendingPathComponent("OriginalThumbnail.png"))
            image?.size = NSSize(width: 40, height: 60)
            clips.append(VideoClip(id: "original", title: "Original", url: original,
                                   thumbnail: image ?? NSImage(systemSymbolName: "film", accessibilityDescription: "Original video")))
        }
    }

    private func randomClip() -> VideoClip? {
        let candidates = clips.count > 1 ? clips.filter { $0.id != currentClip?.id } : clips
        return candidates.randomElement()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "WinCell")
        statusItem.button?.toolTip = "WinCell — click to start or stop"
        statusItem.menu = menu
        loadClips()
        buildMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(reposition), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        installShortcut()
        if CommandLine.arguments.contains("--smoke-test") { smokeTest() }
    }

    private func item(_ title: String, _ action: Selector?, in parent: NSMenu? = nil) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        (parent ?? menu).addItem(entry)
        return entry
    }

    private func buildMenu() {
        menu.removeAllItems()
        toggleItem = item(running ? "Stop WinCell" : "Play Random Video", #selector(toggle))
        toggleItem.keyEquivalent = "f"
        toggleItem.keyEquivalentModifierMask = [.command, .option]
        remainingItem = item("", nil)
        updateRemaining()
        if running, let clip = currentClip {
            _ = item("Playing: \(clip.title)", nil)
            _ = item("Play Another Random Video", #selector(playRandom))
        }
        let videos = NSMenu()
        for (index, clip) in clips.enumerated() {
            let entry = item(clip.title, #selector(selectClip(_:)), in: videos)
            entry.tag = index
            entry.image = clip.thumbnail
            entry.state = running && currentClip?.id == clip.id ? .on : .off
        }
        item("Choose Video", nil).submenu = videos
        menu.addItem(.separator())
        let durations = NSMenu()
        for (title, seconds) in [("Until I stop it", 0), ("1 minute", 60), ("5 minutes", 300), ("15 minutes", 900), ("30 minutes", 1800), ("1 hour", 3600)] {
            let entry = item(title, #selector(setDuration(_:)), in: durations)
            entry.tag = seconds
            entry.state = duration == Double(seconds) ? .on : .off
        }
        durations.addItem(.separator())
        _ = item("Custom duration…", #selector(customDuration), in: durations)
        let durationTitle = duration == 0 ? "Auto-stop: Never" : "Auto-stop: \(Int(duration / 60)) min"
        item(durationTitle, nil).submenu = durations
        let sizes = NSMenu()
        for (title, value) in [("Small", 220), ("Medium", 320), ("Large", 460)] {
            let entry = item(title, #selector(setSize(_:)), in: sizes)
            entry.tag = value
            entry.state = height == Double(value) ? .on : .off
        }
        item("Size", nil).submenu = sizes
        item("Mute sound", #selector(toggleMute)).state = muted ? .on : .off
        menu.addItem(.separator())
        _ = item("Quit WinCell", #selector(quit))
    }

    @objc private func toggle() { running ? stop() : start() }
    @objc private func playRandom() { start() }
    @objc private func selectClip(_ sender: NSMenuItem) {
        guard clips.indices.contains(sender.tag) else { return }
        start(clip: clips[sender.tag])
    }

    private func start(clip selectedClip: VideoClip? = nil) {
        guard let clip = selectedClip ?? randomClip() else {
            let alert = NSAlert()
            alert.messageText = "No WinCell videos were found"
            alert.informativeText = "Rebuild the app to include your video library."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        let wasRunning = running
        let previousDeadline = deadline
        if running { stop() }
        currentClip = clip
        let queue = AVQueuePlayer()
        queue.isMuted = muted
        player = queue
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: clip.url))
        let window = OverlayWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        let view = NSView()
        view.wantsLayer = true
        let layer = AVPlayerLayer(player: queue)
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = NSColor.clear.cgColor
        layer.isOpaque = false
        view.layer = layer
        window.contentView = view
        overlay = window
        reposition()
        window.orderFrontRegardless()
        running = true
        if wasRunning { deadline = previousDeadline } else { resetDeadline() }
        queue.play()
        let clock = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let end = self.deadline, Date() >= end { self.stop() }
            else { self.updateRemaining() }
        }
        timer = clock
        RunLoop.main.add(clock, forMode: .common)
        buildMenu()
        statusItem.button?.contentTintColor = .systemPink
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        deadline = nil
        player?.pause()
        overlay?.orderOut(nil)
        overlay?.close()
        overlay = nil
        looper?.disableLooping()
        looper = nil
        player?.removeAllItems()
        player = nil
        running = false
        buildMenu()
        statusItem.button?.contentTintColor = nil
    }

    @objc private func reposition() {
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let h = min(height, visible.height - 32)
        let w = h * 768 / 1168
        overlay?.setFrame(NSRect(x: visible.maxX - w - 16, y: visible.minY + 16, width: w, height: h), display: true)
    }

    private func resetDeadline() { deadline = duration > 0 ? Date().addingTimeInterval(duration) : nil }
    private func updateRemaining() {
        guard running else { remainingItem.title = "WinCell is off"; return }
        guard let deadline else { remainingItem.title = "Playing until you stop it"; return }
        let seconds = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        remainingItem.title = String(format: "Stops in %d:%02d", seconds / 60, seconds % 60)
    }

    @objc private func setDuration(_ sender: NSMenuItem) { saveDuration(Double(sender.tag)) }
    private func saveDuration(_ seconds: Double) {
        duration = seconds
        UserDefaults.standard.set(duration, forKey: "duration")
        if running { resetDeadline() }
        buildMenu()
    }

    @objc private func customDuration() {
        let alert = NSAlert()
        alert.messageText = "Stop WinCell after…"
        alert.informativeText = "Enter a whole number of minutes (1–1440). Changing this restarts the countdown."
        let field = NSTextField(string: String(max(1, Int(duration / 60))))
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Set timer")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let minutes = Int(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)), (1...1440).contains(minutes) else {
            let error = NSAlert()
            error.messageText = "Please enter a number from 1 to 1440."
            error.runModal()
            return
        }
        saveDuration(Double(minutes * 60))
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        height = Double(sender.tag)
        UserDefaults.standard.set(height, forKey: "height")
        reposition()
        buildMenu()
    }
    @objc private func toggleMute() {
        muted.toggle()
        UserDefaults.standard.set(muted, forKey: "muted")
        player?.isMuted = muted
        buildMenu()
    }
    @objc private func quit() { stop(); NSApp.terminate(nil) }

    private func installShortcut() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(data).takeUnretainedValue()
            delegate.toggle()
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), nil)
        let id = EventHotKeyID(signature: 0x46554E54, id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_F), UInt32(cmdKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKey)
    }

    private func smokeTest() {
        assert(!clips.isEmpty)
        assert(clips.allSatisfy { $0.thumbnail != nil }, "Each video needs a thumbnail")
        if clips.count > 1 {
            for _ in 0..<100 {
                let next = randomClip()!
                assert(next.id != currentClip?.id, "Random play must avoid immediate repeats")
                currentClip = next
            }
        }
        duration = 2
        start()
        assert(running && overlay != nil && player != nil)
        assert(overlay!.ignoresMouseEvents && !overlay!.isOpaque)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
            assert(player?.currentItem?.status == .readyToPlay, "Video must decode successfully")
            assert((player?.currentTime().seconds ?? 0) > 0, "Video must advance")
            print("PASS: playback ready, transparent window, click-through")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [self] in
            assert(!running && overlay == nil && player == nil, "Timer must stop and release playback")
            duration = 0
            start()
            assert(running && deadline == nil)
            stop()
            assert(!running && overlay == nil)
            print("PASS: automatic stop, unlimited mode, manual stop")
            testLibraryClip(at: 0)
        }
    }

    private func testLibraryClip(at index: Int) {
        guard index < clips.count else {
            stop()
            print("PASS: all \(clips.count) videos decode, thumbnails load, manual selection and random selection work")
            NSApp.terminate(nil)
            return
        }
        duration = 120
        let savedDeadline = deadline
        let wasRunning = running
        let entry = NSMenuItem()
        entry.tag = index
        selectClip(entry)
        assert(currentClip?.id == clips[index].id)
        if wasRunning { assert(deadline == savedDeadline, "Switching must preserve the stop timer") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
            assert(player?.currentItem?.status == .readyToPlay, "Video failed: \(clips[index].title)")
            assert((player?.currentTime().seconds ?? 0) > 0, "Video did not advance: \(clips[index].title)")
            print("PASS: \(clips[index].title)")
            testLibraryClip(at: index + 1)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
