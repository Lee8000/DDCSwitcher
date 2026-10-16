import Foundation

public enum LoginItemState: Equatable {
    case notRegistered, enabled, requiresApproval, unavailable
    public var isChecked: Bool { self == .enabled || self == .requiresApproval }
    public var needsApproval: Bool { self == .requiresApproval }
    public var message: String {
        switch self {
        case .notRegistered: return "已关闭；勾选后立即生效。"
        case .enabled: return "已启用；登录后加载快捷键，在菜单栏运行。"
        case .requiresApproval: return "需要在系统“登录项”中允许启动。"
        case .unavailable: return "登录项不可用；请将完整应用放到固定位置后重试。"
        }
    }
}

/// Registration is OS state, independent of action drafts and configuration files.
public final class LoginItemController {
    public private(set) var state: LoginItemState = .notRegistered
    private let isDemo: Bool
    private let read: () -> LoginItemState
    private let register: () throws -> Void
    private let unregister: () throws -> Void
    public init(isDemo: Bool = false, read: @escaping () -> LoginItemState,
                register: @escaping () throws -> Void, unregister: @escaping () throws -> Void) {
        self.isDemo = isDemo; self.read = read; self.register = register; self.unregister = unregister
        refresh()
    }
    public func refresh() { state = isDemo ? .unavailable : read() }
    public func setEnabled(_ enabled: Bool) throws {
        guard !isDemo else { throw SwitcherError.message("演示模式不修改系统登录项。") }
        defer { refresh() }
        if enabled { try register() } else { try unregister() }
    }
}
