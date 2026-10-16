import AppKit
import DDCSwitcherCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settings: SettingsWindowController!
    private let hotkeys = HotKeyManager()
    private var service: DDCService!
    private var store: SettingsStore!
    private var configuration = Configuration()
    private var recoveryNeeded = false
    private var statusState = StatusState()
    private var lastStatus: String { statusState.message }
    private var isDemo = false
    private var displayObserver: NSObjectProtocol?
    private var refreshWork: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           let other = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: [.activateAllWindows]); NSApp.terminate(nil); return
        }
        buildMainMenu()
        do { try prepareRuntime() }
        catch { showFatal(error.localizedDescription); return }
        var initialError: String?
        do { configuration = try store.load() }
        catch { recoveryNeeded = true; initialError = error.localizedDescription }
        if isDemo, !recoveryNeeded, configuration.actions.isEmpty { configuration = DemoRuntime.configuration }
        settings = SettingsWindowController(configuration: configuration)
        settings.window?.title += isDemo ? " · 演示模式（不控制硬件）" : ""
        settings.onRecording = { [weak self] in self?.hotkeys.setRecording($0) }
        settings.onSave = { [weak self] config in
            guard let self else { return }
            guard !self.recoveryNeeded else { throw SwitcherError.message("原设置无法读取；请先备份并重置，避免覆盖原文件。") }
            try self.hotkeys.replace(with: config.actions) { try self.store.save(config) }
            self.configuration = config
            self.statusState.registrationSucceeded()
            self.report("设置已保存，快捷键已生效")
        }
        settings.onSwitch = { [weak self] in self?.trigger($0) }
        settings.onRefresh = { [weak self] in self?.refresh() }
        settings.onReveal = { [weak self] in self?.revealSettings() }
        settings.onReset = { [weak self] in self?.recoverSettings() }
        hotkeys.onTrigger = { [weak self] in self?.trigger($0) }
        hotkeys.onError = { [weak self] message in
            self?.statusState.registrationFailed(message)
            self?.report(message, error: true)
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "DDC 输入源快捷切换")
        statusItem.button?.image?.isTemplate = true
        rebuildMenu()
        do { try hotkeys.replace(with: configuration.actions) }
        catch { initialError = error.localizedDescription; statusState.registrationFailed(error.localizedDescription) }
        settings.setRecoveryNeeded(recoveryNeeded)
        refresh()
        if let initialError { report(initialError, error: true) }
        displayObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in
            self?.refreshWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.refresh() }
            self?.refreshWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
        }
        if configuration.actions.isEmpty || initialError != nil || isDemo || CommandLine.arguments.contains("--settings") { showSettings(nil) }
    }
    private func prepareRuntime() throws {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--demo"), args.indices.contains(index + 1) {
            let directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            isDemo = true
            service = DDCService(executable: try DemoRuntime.makeBackend(in: directory))
            store = SettingsStore(url: directory.appendingPathComponent("settings.json"))
        } else {
            guard let helper = Bundle.main.url(forAuxiliaryExecutable: "m1ddc"),
                  FileManager.default.isExecutableFile(atPath: helper.path) else {
                throw SwitcherError.message("应用中缺少 m1ddc 控制组件。请使用完整的 DDCSwitcher.app，或运行 scripts/build.sh 重新构建。")
            }
            service = DDCService(executable: helper)
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: false)
            store = SettingsStore(url: support.appendingPathComponent("DDCSwitcher/settings.json"))
        }
    }
    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "DDC Switcher 设置…", action: #selector(showSettings(_:)), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 DDC Switcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; main.addItem(appItem)
        let editItem = NSMenuItem(); editItem.title = "编辑"
        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit; main.addItem(editItem)
        NSApp.mainMenu = main
    }
    private func rebuildMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu(); menu.autoenablesItems = false
        menu.addItem(withTitle: isDemo ? "DDC Switcher · 演示模式" : "DDC 输入源快捷切换", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(withTitle: String(lastStatus.prefix(55)), action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        let actions = configuration.actions.filter(\.enabled)
        if actions.isEmpty { menu.addItem(withTitle: "尚无动作，请打开设置添加", action: nil, keyEquivalent: "").isEnabled = false }
        for action in actions {
            let item = menu.addItem(withTitle: "\(action.name)    \(shortcutText(action.shortcut))", action: #selector(menuSwitch(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = action.id
            item.isEnabled = !service.busy && !recoveryNeeded
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(showSettings(_:)), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "刷新显示器", action: #selector(menuRefresh), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 DDC Switcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu; statusItem.button?.toolTip = lastStatus
    }
    @objc private func menuSwitch(_ item: NSMenuItem) { if let id = item.representedObject as? UUID { trigger(id) } }
    @objc private func menuRefresh() { refresh() }
    @objc func showSettings(_ sender: Any?) {
        settings?.showWindow(nil); settings?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func trigger(_ id: UUID) {
        guard !recoveryNeeded, let action = configuration.actions.first(where: { $0.id == id && $0.enabled }) else { return }
        let accepted = service.send(action) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success: self.report("\(action.name)：切换命令已发送，请观察显示器是否响应。")
            case let .failure(error): self.report(error.localizedDescription, error: true); NSSound.beep()
            }
        }
        if accepted { report("正在向显示器发送“\(action.name)”切换命令…") }
    }
    private func refresh() {
        guard settings != nil, !recoveryNeeded else { return }
        settings.setRefreshing()
        service.refresh { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(displays):
                self.settings.updateDisplays(displays)
                if displays.isEmpty { self.report("未检测到外接显示器。请连接显示器并启用 DDC/CI，再点击刷新。") }
                else { self.report("发现 \(displays.count) 台外接显示器。请选择目标、输入源和快捷键后保存。") }
            case let .failure(error):
                self.settings.updateDisplays([]); self.report(error.localizedDescription, error: true)
            }
        }
    }
    private func report(_ message: String, error: Bool = false) {
        statusState.update(message, error: error)
        settings?.setStatus(statusState.message, error: statusState.isError); rebuildMenu()
        if statusState.isError { showSettings(nil) }
    }
    private func revealSettings() {
        do {
            let directory = store.url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(directory)
        } catch { report(error.localizedDescription, error: true) }
    }
    private func recoverSettings() {
        guard recoveryNeeded else { return }
        let alert = NSAlert(); alert.messageText = "备份原设置并重新开始？"
        alert.informativeText = "原设置将保留为同文件夹内的备份文件，随后可以重新配置显示器与快捷键。"
        alert.addButton(withTitle: "备份并重置"); alert.addButton(withTitle: "取消")
        guard let window = settings.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            do {
                let backup = self.store.url.deletingLastPathComponent().appendingPathComponent("settings-backup-\(UUID().uuidString).json")
                try FileManager.default.moveItem(at: self.store.url, to: backup)
                self.configuration = Configuration(); self.recoveryNeeded = false
                self.settings.replaceDraft(self.configuration); self.settings.setRecoveryNeeded(false); self.refresh()
            } catch { self.report("备份失败：\(error.localizedDescription)", error: true) }
        }
    }
    private func showFatal(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "DDC Switcher 无法启动"; alert.informativeText = message
        alert.runModal(); NSApp.terminate(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(nil); return true }
    func applicationWillTerminate(_ notification: Notification) {
        refreshWork?.cancel()
        if let displayObserver { NotificationCenter.default.removeObserver(displayObserver) }
        settings?.recorder.stop()
    }
}
