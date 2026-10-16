import Foundation

public enum InputMode: String, Codable, CaseIterable {
    case standard = "input", lgAlternate = "input-alt"
}
public struct Shortcut: Codable, Equatable, Hashable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }
    public func validate() throws {
        let allowed: UInt32 = 256 | 512 | 2048 | 4096
        // Command or Control avoids layout-dependent Option-only shortcuts.
        guard modifiers & (256 | 4096) != 0, modifiers & ~allowed == 0 else {
            throw SwitcherError.message("快捷键需包含 ⌘ Command 或 ⌃ Control，可搭配 ⌥、⇧。")
        }
        guard keyCode <= 126, ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode) else {
            throw SwitcherError.message("请选择普通按键或功能键作为快捷键。")
        }
    }
}
public struct SwitchAction: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var displayID: String
    public var inputValue: Int
    public var mode: InputMode
    public var shortcut: Shortcut?
    public var enabled: Bool
    public init(id: UUID = UUID(), name: String, displayID: String, inputValue: Int = 17,
                mode: InputMode = .standard, shortcut: Shortcut? = nil, enabled: Bool = true) {
        self.id = id; self.name = name; self.displayID = displayID; self.inputValue = inputValue
        self.mode = mode; self.shortcut = shortcut; self.enabled = enabled
    }
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80 else {
            throw SwitcherError.message("动作名称不能为空，且不能超过 80 个字符。")
        }
        guard UUID(uuidString: displayID) != nil else {
            throw SwitcherError.message("请为“\(name)”选择显示器；无法使用临时编号。")
        }
        guard (0...65535).contains(inputValue) else {
            throw SwitcherError.message("输入代码必须是 0 至 65535 的整数。")
        }
        if let shortcut { try shortcut.validate() }
    }
    public func arguments(connectedIDs: Set<String>) throws -> [String] {
        try validate()
        guard enabled else { throw SwitcherError.message("“\(name)”已停用。") }
        guard connectedIDs.contains(where: { $0.caseInsensitiveCompare(displayID) == .orderedSame }) else {
            throw SwitcherError.message("未找到“\(name)”绑定的显示器。请连接显示器后刷新；切到其他设备后，原端口可能无法继续控制。")
        }
        return ["display", displayID, "set", mode.rawValue, String(inputValue)]
    }
}
public struct Configuration: Codable, Equatable {
    public var schemaVersion = 1
    public var actions: [SwitchAction]
    public init(actions: [SwitchAction] = []) { self.actions = actions }
    public func validate() throws {
        guard schemaVersion == 1 else { throw SwitcherError.message("设置版本不受支持；请保留原文件并使用匹配版本的应用。") }
        var ids = Set<UUID>()
        var shortcuts = Set<Shortcut>()
        for action in actions {
            try action.validate()
            guard ids.insert(action.id).inserted else { throw SwitcherError.message("设置中出现重复的动作标识。") }
            if action.enabled, let shortcut = action.shortcut, !shortcuts.insert(shortcut).inserted {
                throw SwitcherError.message("“\(action.name)”的快捷键与其他已启用动作重复。")
            }
        }
    }
}
public struct DisplayInfo: Equatable, Identifiable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}
public enum SwitcherError: Error, LocalizedError {
    case message(String)
    public var errorDescription: String? { if case let .message(value) = self { return value }; return nil }
}
