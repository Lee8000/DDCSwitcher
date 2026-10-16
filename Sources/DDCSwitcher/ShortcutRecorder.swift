import AppKit
import DDCSwitcherCore

final class ShortcutRecorder: NSButton {
    var shortcut: Shortcut? { didSet { if !recording { title = shortcutText(shortcut) } } }
    var onChange: (() -> Void)?
    var onRecording: ((Bool) -> Void)?
    private var monitor: Any?
    private(set) var recording = false
    override var acceptsFirstResponder: Bool { true }

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        title = "点击录制快捷键"
        target = self; action = #selector(beginRecording)
        setAccessibilityLabel("录制全局快捷键")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func beginRecording() {
        if recording { stop(); return }
        recording = true
        onRecording?(true)
        title = "请按组合键… Esc 取消"
        window?.makeFirstResponder(self)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording else { return event }
            self.capture(event)
            return nil
        }
    }
    private func capture(_ event: NSEvent) {
        if event.keyCode == 53 { stop(); return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= 256 }
        if flags.contains(.shift) { modifiers |= 512 }
        if flags.contains(.option) { modifiers |= 2048 }
        if flags.contains(.control) { modifiers |= 4096 }
        let candidate = Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        do {
            try candidate.validate()
            shortcut = candidate
            stop()
            onChange?()
        } catch { title = "需包含 ⌘ 或 ⌃，请重试…"; NSSound.beep() }
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        let wasRecording = recording
        recording = false
        title = shortcutText(shortcut)
        if wasRecording { onRecording?(false) }
    }
    override func resignFirstResponder() -> Bool { stop(); return true }
    deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
}
