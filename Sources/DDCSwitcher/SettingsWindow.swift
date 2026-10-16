import AppKit
import DDCSwitcherCore

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSWindowDelegate {
    private(set) var draft: Configuration
    private var displays: [DisplayInfo] = []
    private let table = NSTableView()
    private let nameField = NSTextField()
    private let monitorPopup = NSPopUpButton()
    private let modePopup = NSPopUpButton()
    private let presetPopup = NSPopUpButton()
    private let valueField = NSTextField()
    let recorder = ShortcutRecorder()
    private let enabled = NSButton(checkboxWithTitle: "启用此动作", target: nil, action: nil)
    private let editor = NSStackView()
    private let emptyLabel = NSTextField(wrappingLabelWithString: "还没有切换动作\n\n点击左下角“＋ 添加”，\n为一个输入源绑定快捷键。")
    private let status = NSTextField(wrappingLabelWithString: "正在查找外接显示器…")
    private let refreshButton = NSButton(title: "刷新显示器", target: nil, action: nil)
    private let resetButton = NSButton(title: "备份并重置损坏设置", target: nil, action: nil)
    private let loginItem = NSButton(checkboxWithTitle: "登录后自动启动", target: nil, action: nil)
    private let loginStatus = NSTextField(wrappingLabelWithString: "")
    private let loginSettings = NSButton(title: "系统登录项…", target: nil, action: nil)
    private var loginController: LoginItemController?
    var onOpenLoginSettings: (() -> Void)?
    private var loading = false
    var onSave: ((Configuration) throws -> Void)?
    var onSwitch: ((UUID) -> Void)?
    var onRefresh: (() -> Void)?
    var onRecording: ((Bool) -> Void)?
    var onReveal: (() -> Void)?
    var onReset: (() -> Void)?

    init(configuration: Configuration) {
        draft = configuration
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 790),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "DDC Switcher · 输入源快捷切换"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.center()
        buildUI()
        reloadList(select: draft.actions.first?.id)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func label(_ text: String, size: CGFloat = 12, color: NSColor = .secondaryLabelColor) -> NSTextField {
        let view = NSTextField(wrappingLabelWithString: text)
        view.font = .systemFont(ofSize: size)
        view.textColor = color
        return view
    }
    private func button(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded
        return b
    }
    private func stack(_ views: [NSView], vertical: Bool = false, spacing: CGFloat = 10) -> NSStackView {
        let s = NSStackView(views: views); s.orientation = vertical ? .vertical : .horizontal
        s.alignment = vertical ? .leading : .centerY; s.spacing = spacing
        return s
    }
    private func section(_ title: String, _ control: NSView, hint: String? = nil) {
        let titleView = label(title, size: 12, color: .labelColor)
        titleView.font = .systemFont(ofSize: 12, weight: .semibold)
        let s = stack([titleView, control], vertical: true, spacing: 6)
        if let hint { s.addArrangedSubview(label(hint, size: 11)) }
        editor.addArrangedSubview(s)
        s.widthAnchor.constraint(equalTo: editor.widthAnchor).isActive = true
        control.widthAnchor.constraint(equalTo: s.widthAnchor).isActive = true
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical; root.alignment = .leading; root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 26),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -26),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
        let heading = label("一个组合键，切换输入源", size: 24, color: .labelColor)
        heading.font = .systemFont(ofSize: 24, weight: .bold)
        root.addArrangedSubview(heading)
        root.addArrangedSubview(label("为每个显示器输入源设置动作，关闭窗口后仍可从菜单栏或快捷键触发。", size: 12))
        let separator = NSBox(); separator.boxType = .separator
        root.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        column.width = 226; table.addTableColumn(column)
        table.headerView = nil; table.rowHeight = 58; table.intercellSpacing = NSSize(width: 0, height: 4)
        table.dataSource = self; table.delegate = self
        table.style = .sourceList; table.allowsEmptySelection = true
        table.setAccessibilityLabel("输入源动作列表")
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let left = stack([label("切换动作", size: 13, color: .labelColor), scroll,
                          stack([button("＋ 添加", action: #selector(addAction)), button("− 删除", action: #selector(removeAction))])],
                         vertical: true)
        left.widthAnchor.constraint(equalToConstant: 234).isActive = true
        scroll.widthAnchor.constraint(equalTo: left.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true

        let right = NSView()
        editor.orientation = .vertical; editor.alignment = .leading; editor.spacing = 15
        editor.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.alignment = .center; emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        right.addSubview(editor); right.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            editor.leadingAnchor.constraint(equalTo: right.leadingAnchor, constant: 22),
            editor.trailingAnchor.constraint(equalTo: right.trailingAnchor),
            editor.topAnchor.constraint(equalTo: right.topAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: right.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: right.centerYAnchor),
            emptyLabel.widthAnchor.constraint(equalToConstant: 330)
        ])
        nameField.placeholderString = "例如：工作电脑 · HDMI 1"; nameField.delegate = self
        nameField.setAccessibilityLabel("动作名称")
        section("动作名称", nameField)
        monitorPopup.target = self; monitorPopup.action = #selector(editorChanged)
        monitorPopup.setAccessibilityLabel("目标显示器")
        section("目标显示器", monitorPopup, hint: "按稳定标识绑定；显示器重连后不会自动改选其他设备。")
        modePopup.addItems(withTitles: ["标准 DDC/CI", "LG 兼容方式（input-alt）"])
        modePopup.target = self; modePopup.action = #selector(modeChanged)
        modePopup.setAccessibilityLabel("输入控制方式")
        section("输入控制方式", modePopup)
        presetPopup.target = self; presetPopup.action = #selector(presetChanged)
        presetPopup.setAccessibilityLabel("输入源预设")
        valueField.placeholderString = "十进制代码"; valueField.delegate = self
        valueField.setAccessibilityLabel("输入源十进制代码")
        let codeRow = stack([presetPopup, valueField])
        valueField.widthAnchor.constraint(equalToConstant: 90).isActive = true
        section("输入源", codeRow, hint: "预设不代表显示器一定支持；自定义代码范围为 0–65535。")
        recorder.onChange = { [weak self] in self?.updateDraft() }
        recorder.onRecording = { [weak self] recording in self?.onRecording?(recording) }
        let shortcutRow = stack([recorder, button("清除", action: #selector(clearShortcut))])
        section("全局组合快捷键", shortcutRow, hint: "点击录制，再按 ⌃⌥⌘1 等组合键；需包含 ⌘ 或 ⌃。")
        enabled.target = self; enabled.action = #selector(editorChanged)
        editor.addArrangedSubview(enabled)

        let body = stack([left, right], spacing: 12)
        body.alignment = .top
        root.addArrangedSubview(body)
        body.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        body.heightAnchor.constraint(equalToConstant: 415).isActive = true
        left.heightAnchor.constraint(equalTo: body.heightAnchor).isActive = true
        right.heightAnchor.constraint(equalTo: body.heightAnchor).isActive = true
        right.widthAnchor.constraint(greaterThanOrEqualToConstant: 500).isActive = true

        refreshButton.target = self; refreshButton.action = #selector(refresh)
        resetButton.target = self; resetButton.action = #selector(resetSettings); resetButton.isHidden = true
        root.addArrangedSubview(stack([refreshButton, button("设置文件夹", action: #selector(reveal)),
                                      button("使用说明", action: #selector(help)), resetButton], spacing: 8))
        loginItem.target = self; loginItem.action = #selector(toggleLoginItem)
        loginItem.setAccessibilityLabel("登录后自动启动")
        loginSettings.target = self; loginSettings.action = #selector(openLoginSettings)
        loginStatus.font = .systemFont(ofSize: 11); loginStatus.textColor = .secondaryLabelColor
        loginStatus.maximumNumberOfLines = 2
        let loginRow = stack([loginItem, loginStatus, loginSettings], spacing: 10)
        root.addArrangedSubview(loginRow)
        loginRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        loginStatus.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        status.font = .systemFont(ofSize: 11)
        status.maximumNumberOfLines = 3; status.lineBreakMode = .byTruncatingTail
        root.addArrangedSubview(status)
        status.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        status.heightAnchor.constraint(equalToConstant: 42).isActive = true
        let save = button("保存并启用", action: #selector(save))
        save.keyEquivalent = "s"; save.keyEquivalentModifierMask = .command
        let bottom = stack([label("切换到另一台设备后，原端口可能无法再切回。", size: 11),
                            button("保存并切换此动作", action: #selector(saveAndSwitch)), save])
        bottom.distribution = .fill
        root.addArrangedSubview(bottom)
        bottom.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }

    func numberOfRows(in tableView: NSTableView) -> Int { draft.actions.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let action = draft.actions[row]
        let title = label(action.name, size: 13, color: action.enabled ? .labelColor : .tertiaryLabelColor)
        title.maximumNumberOfLines = 1
        title.font = .systemFont(ofSize: 13, weight: .medium)
        let subtitle = label((action.enabled ? "" : "已停用 · ") + shortcutText(action.shortcut), size: 11)
        let s = stack([title, subtitle], vertical: true, spacing: 3)
        s.edgeInsets = NSEdgeInsets(top: 7, left: 8, bottom: 7, right: 8)
        return s
    }
    func tableViewSelectionDidChange(_ notification: Notification) { loadEditor() }
    func controlTextDidChange(_ obj: Notification) { updateDraft() }
    private var selectedIndex: Int? { draft.actions.indices.contains(table.selectedRow) ? table.selectedRow : nil }

    private func reloadList(select id: UUID?) {
        table.reloadData()
        if let id, let index = draft.actions.firstIndex(where: { $0.id == id }) {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else { table.deselectAll(nil) }
        loadEditor()
    }
    private func loadEditor() {
        recorder.stop()
        guard let index = selectedIndex else { editor.isHidden = true; emptyLabel.isHidden = false; return }
        editor.isHidden = false; emptyLabel.isHidden = true; loading = true
        defer { loading = false }
        let action = draft.actions[index]
        nameField.stringValue = action.name
        populateMonitors(selected: action.displayID)
        modePopup.selectItem(at: action.mode == .standard ? 0 : 1)
        valueField.stringValue = String(action.inputValue)
        populatePresets(value: action.inputValue)
        recorder.shortcut = action.shortcut
        enabled.state = action.enabled ? .on : .off
    }
    private func populateMonitors(selected: String) {
        monitorPopup.removeAllItems()
        if displays.isEmpty { monitorPopup.addItem(withTitle: "未检测到外接显示器，请连接后刷新") }
        else { monitorPopup.addItem(withTitle: "请选择显示器…") }
        for display in displays {
            monitorPopup.addItem(withTitle: "\(display.name) · \(display.id.prefix(8))")
            monitorPopup.lastItem?.representedObject = display.id
        }
        if !selected.isEmpty, !displays.contains(where: { $0.id == selected }) {
            monitorPopup.addItem(withTitle: "已保存显示器 · \(selected.prefix(8))（未连接）")
            monitorPopup.lastItem?.representedObject = selected
        }
        if let index = monitorPopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == selected }) {
            monitorPopup.selectItem(at: index)
        }
    }
    private var presetItems: [(String, Int)] {
        modePopup.indexOfSelectedItem == 1
        ? [("HDMI 1", 144), ("HDMI 2", 145), ("DisplayPort 1", 208), ("DisplayPort 2", 209), ("USB-C / DP 3", 210)]
        : [("HDMI 1", 17), ("HDMI 2", 18), ("DisplayPort 1", 15), ("DisplayPort 2", 16), ("USB-C", 27)]
    }
    private func populatePresets(value: Int) {
        presetPopup.removeAllItems()
        for preset in presetItems { presetPopup.addItem(withTitle: "\(preset.0) · \(preset.1)") }
        presetPopup.addItem(withTitle: "自定义代码")
        presetPopup.selectItem(at: presetItems.firstIndex(where: { $0.1 == value }) ?? presetItems.count)
    }
    private func updateDraft() {
        guard !loading, let index = selectedIndex else { return }
        draft.actions[index].name = nameField.stringValue
        draft.actions[index].displayID = monitorPopup.selectedItem?.representedObject as? String ?? ""
        draft.actions[index].inputValue = Int(valueField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
        draft.actions[index].mode = modePopup.indexOfSelectedItem == 1 ? .lgAlternate : .standard
        draft.actions[index].shortcut = recorder.shortcut
        draft.actions[index].enabled = enabled.state == .on
        table.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
    }
    @objc private func editorChanged() { updateDraft() }
    @objc private func modeChanged() { populatePresets(value: Int(valueField.stringValue) ?? -1); updateDraft() }
    @objc private func presetChanged() {
        if presetItems.indices.contains(presetPopup.indexOfSelectedItem) {
            valueField.stringValue = String(presetItems[presetPopup.indexOfSelectedItem].1)
        }
        updateDraft()
    }
    @objc private func clearShortcut() { recorder.stop(); recorder.shortcut = nil; updateDraft() }
    @objc private func addAction() {
        recorder.stop()
        let action = SwitchAction(name: "HDMI 1", displayID: displays.first?.id ?? "")
        draft.actions.append(action); reloadList(select: action.id)
        window?.makeFirstResponder(nameField)
    }
    @objc private func removeAction() {
        recorder.stop()
        guard let index = selectedIndex else { return }
        draft.actions.remove(at: index)
        reloadList(select: draft.actions.isEmpty ? nil : draft.actions[min(index, draft.actions.count - 1)].id)
    }
    @discardableResult private func apply() -> Bool {
        recorder.stop(); updateDraft()
        do {
            try draft.validate()
            try onSave?(draft)
            setStatus("设置已保存。已启用动作可从菜单栏或全局快捷键触发。")
            return true
        } catch { setStatus(error.localizedDescription, error: true); NSSound.beep(); return false }
    }
    @objc private func save() { apply() }
    @objc private func saveAndSwitch() {
        guard let index = selectedIndex else { setStatus("请先添加并选择一个动作。", error: true); return }
        let id = draft.actions[index].id
        if apply() { onSwitch?(id) }
    }
    @objc private func refresh() { onRefresh?() }
    @objc private func reveal() { onReveal?() }
    @objc private func resetSettings() { onReset?() }
    @objc private func help() {
        let alert = NSAlert()
        alert.messageText = "输入源快捷切换"
        alert.informativeText = "1. 在显示器菜单中启用 DDC/CI，连接 Mac 后点击刷新。\n2. 添加动作，选择显示器和输入源。\n3. 点击快捷键按钮录制组合键，再保存并启用。\n4. 在任意应用中按快捷键，或从菜单栏选择动作。\n\n先确认线材与扩展坞能传递 DDC 信号。USB-C 输入代码随厂商变化；标准方式无效时可尝试 LG 兼容方式或自定义代码。\n\n切换到其他电脑后，显示器可能不再接受此 Mac 的命令，届时需用显示器按键或另一台电脑切回。发送回执表示控制组件完成写入，显示器是否响应仍需观察。\n\n建议 ⌃⌥⌘1、⌃⌥⌘2 等组合；Fn 功能键可能需要同时按 Fn。首次运行无需屏幕录制或辅助功能权限。"
        alert.addButton(withTitle: "知道了")
        if let window { alert.beginSheetModal(for: window) }
    }
    func updateDisplays(_ displays: [DisplayInfo]) {
        self.displays = displays
        if let index = selectedIndex { populateMonitors(selected: draft.actions[index].displayID) }
        refreshButton.isEnabled = true
    }
    func setRefreshing() { refreshButton.isEnabled = false; setStatus("正在查找外接显示器…") }
    func setStatus(_ message: String, error: Bool = false) {
        status.stringValue = message; status.textColor = error ? .systemRed : .secondaryLabelColor
        status.toolTip = message
    }
    func setRecoveryNeeded(_ needed: Bool) { resetButton.isHidden = !needed }
    func replaceDraft(_ configuration: Configuration) { draft = configuration; reloadList(select: draft.actions.first?.id) }
    func configureLoginItem(_ controller: LoginItemController, isDemo: Bool) {
        loginController = controller
        loginItem.isEnabled = !isDemo
        loginSettings.isEnabled = !isDemo
        refreshLoginItem()
    }
    private func refreshLoginItem(error: String? = nil) {
        guard let controller = loginController else { return }
        controller.refresh()
        loginItem.state = controller.state.isChecked ? .on : .off
        let message = loginItem.isEnabled ? controller.state.message : "演示模式不修改登录项。"
        loginStatus.stringValue = error.map { "修改失败：\($0)" } ?? message
        loginStatus.toolTip = loginStatus.stringValue
        loginStatus.textColor = error != nil ? .systemRed : .secondaryLabelColor
    }
    @objc private func toggleLoginItem() {
        recorder.stop()
        do { try loginController?.setEnabled(loginItem.state == .on); refreshLoginItem() }
        catch { refreshLoginItem(error: error.localizedDescription); NSSound.beep() }
    }
    @objc private func openLoginSettings() { onOpenLoginSettings?() }
    func windowDidBecomeKey(_ notification: Notification) { refreshLoginItem() }
    func windowWillClose(_ notification: Notification) { recorder.stop() }
    func windowDidResignKey(_ notification: Notification) { recorder.stop() }
}
