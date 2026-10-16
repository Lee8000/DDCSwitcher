import AppKit
import Carbon
import DDCSwitcherCore

enum DemoRuntime {
    static let monitor = "10ACB8A0-0000-0000-1419-0104A2435078"
    static var configuration: Configuration {
        Configuration(actions: [
            SwitchAction(name: "工作电脑 · HDMI 1", displayID: monitor, inputValue: 17,
                         shortcut: Shortcut(keyCode: 18, modifiers: 256 | 2048 | 4096)),
            SwitchAction(name: "笔记本 · USB-C", displayID: monitor, inputValue: 27,
                         shortcut: Shortcut(keyCode: 19, modifiers: 256 | 2048 | 4096))
        ])
    }
    static func makeBackend(in directory: URL) throws -> URL {
        let helper = directory.appendingPathComponent("demo-ddc")
        let script = """
        #!/bin/sh
        if [ "$1" = display ] && [ "$2" = list ]; then
          printf '[1] Studio Display Demo (\(monitor))\\n'
          exit 0
        fi
        if [ "$1" = display ] && [ "$2" = '\(monitor)' ] && [ "$3" = set ]; then
          printf '%s\\n' "$*" >> "$0.log"
          printf 'Writing %s\\n' "$5"
          exit 0
        fi
        printf 'Invalid demo arguments' >&2
        exit 2
        """
        try Data(script.utf8).write(to: helper, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
        return helper
    }
}

func runSelfTest() -> Int32 {
    _ = NSApplication.shared
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DDCSwitcherIntegration-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Exercise real AppKit controls with a fake OS registration provider.
        var startupState = LoginItemState.notRegistered
        var startupWrites = 0
        var startupFailure = false
        let startup = LoginItemController(read: { startupState }, register: {
            if startupFailure { throw SwitcherError.message("系统拒绝更改登录项；请检查应用是否已移动，以及系统设置中的登录项权限后重试。") }
            startupWrites += 1; startupState = .requiresApproval
        }, unregister: { startupWrites += 1; startupState = .notRegistered })
        let settings = SettingsWindowController(configuration: Configuration())
        settings.configureLoginItem(startup, isDemo: false)
        guard let content = settings.window?.contentView else { throw SwitcherError.message("设置窗口缺失") }
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap { descendants($0) } }
        let buttons = descendants(content).compactMap { $0 as? NSButton }
        guard let checkbox = buttons.first(where: { $0.title == "登录后自动启动" }),
              let systemSettings = buttons.first(where: { $0.title == "系统登录项…" }) else {
            throw SwitcherError.message("登录项控件缺失")
        }
        checkbox.performClick(nil)
        guard startup.state == .requiresApproval, checkbox.state == .on, startupWrites == 1,
              settings.draft.actions.isEmpty else { throw SwitcherError.message("空配置下登录项开关未独立生效") }
        checkbox.performClick(nil)
        guard startup.state == .notRegistered, checkbox.state == .off, startupWrites == 2 else {
            throw SwitcherError.message("登录项关闭未回读")
        }
        settings.configureLoginItem(startup, isDemo: true)
        guard !checkbox.isEnabled, !systemSettings.isEnabled, startupWrites == 2 else {
            throw SwitcherError.message("演示模式未禁用登录项控件")
        }
        settings.replaceDraft(DemoRuntime.configuration)
        settings.configureLoginItem(startup, isDemo: false)
        settings.window?.makeKeyAndOrderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        startupFailure = true
        checkbox.performClick(nil)
        guard checkbox.state == .off, startupWrites == 2 else { throw SwitcherError.message("登录项写入失败未恢复实际勾选状态") }
        content.layoutSubtreeIfNeeded()
        settings.window?.displayIfNeeded()
        for button in buttons where !button.isHidden && !button.isHiddenOrHasHiddenAncestor {
            let frame = button.convert(button.bounds, to: content)
            guard frame.width > 0, frame.height > 0, content.bounds.insetBy(dx: -1, dy: -1).contains(frame) else {
                throw SwitcherError.message("设置按钮超出窗口：\(button.title)")
            }
        }
        if let imagePath = ProcessInfo.processInfo.environment["DDC_SELF_TEST_UI_IMAGE"],
           let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
            content.cacheDisplay(in: content.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) { try png.write(to: URL(fileURLWithPath: imagePath)) }
        }
        settings.window?.orderOut(nil)
        let helper = try DemoRuntime.makeBackend(in: directory)
        let service = DDCService(executable: helper)
        let manager = HotKeyManager()
        var action = DemoRuntime.configuration.actions[0]
        action.shortcut = Shortcut(keyCode: 79, modifiers: 256 | 2048 | 4096)
        let store = SettingsStore(url: directory.appendingPathComponent("settings.json"))
        var received = [UUID]()
        var result: Result<String, Error>?
        manager.onTrigger = { id in
            received.append(id)
            if id == action.id { service.send(action) { result = $0 } }
        }
        try manager.replace(with: [action]) { try store.save(Configuration(actions: [action])) }
        guard try store.load().actions == [action] else { throw SwitcherError.message("配置往返失败") }
        func fire(_ id: UInt32) throws {
            var event: EventRef?
            guard CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0,
                              EventAttributes(kEventAttributeNone), &event) == noErr, let event else {
                throw SwitcherError.message("无法创建 Carbon 事件")
            }
            defer { ReleaseEvent(event) }
            var hotkeyID = EventHotKeyID(signature: 0x44444353, id: id)
            let set = SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                       MemoryLayout<EventHotKeyID>.size, &hotkeyID)
            guard set == noErr, SendEventToEventTarget(event, GetApplicationEventTarget()) == noErr else {
                throw SwitcherError.message("Carbon 事件分发失败")
            }
        }
        var changed = action
        changed.shortcut = Shortcut(keyCode: 80, modifiers: 256 | 2048 | 4096)
        do {
            try manager.replace(with: [changed]) { throw SwitcherError.message("模拟保存失败") }
            throw SwitcherError.message("事务应当失败")
        } catch let error as SwitcherError {
            guard error.localizedDescription == "模拟保存失败" else { throw error }
        }
        try fire(1); try fire(1)
        let deadline = Date().addingTimeInterval(8)
        while result == nil, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
        guard received == [action.id, action.id], let result else { throw SwitcherError.message("热键事件没有到达动作处理器") }
        _ = try result.get()
        let log = try String(contentsOf: helper.appendingPathExtension("log"), encoding: .utf8)
        guard log.components(separatedBy: .newlines).filter({ !$0.isEmpty }).count == 1,
              log.contains("display \(DemoRuntime.monitor) set input 17") else {
            throw SwitcherError.message("重复触发抑制或命令参数验证失败")
        }
        var second = DemoRuntime.configuration.actions[1]
        second.shortcut = changed.shortcut
        try manager.replace(with: [action, second])
        swap(&action.shortcut, &second.shortcut)
        manager.onTrigger = { received.append($0) }
        try manager.replace(with: [action, second])
        try fire(1)
        guard received.last == second.id else { throw SwitcherError.message("交换快捷键后映射错误") }
        print("PASS: 登录项 AppKit 控件、空配置启停、演示隔离、窗口布局边界、Carbon 注册/分发、保存失败回滚、快捷键交换、配置保存、完整模拟 DDC 流程、重复触发抑制。未发送任何真实 DDC 写入。")
        return 0
    } catch { fputs("SELF-TEST FAILED: \(error.localizedDescription)\n", stderr); return 1 }
}
