public struct StatusState {
    public private(set) var message = "尚未配置输入源动作"
    public private(set) var isError = false
    private var registrationError: String?
    public init() {}
    public mutating func update(_ message: String, error: Bool = false) {
        self.message = registrationError ?? message
        isError = registrationError != nil || error
    }
    public mutating func registrationFailed(_ message: String) { registrationError = message; update(message, error: true) }
    public mutating func registrationSucceeded() { registrationError = nil }
}
