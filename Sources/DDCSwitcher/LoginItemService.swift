import ServiceManagement
import DDCSwitcherCore

enum LoginItemService {
    static func makeController(isDemo: Bool) -> LoginItemController {
        LoginItemController(isDemo: isDemo, read: {
            switch SMAppService.mainApp.status {
            case .notRegistered: return .notRegistered
            case .enabled: return .enabled
            case .requiresApproval: return .requiresApproval
            case .notFound: return .unavailable
            @unknown default: return .unavailable
            }
        }, register: { try SMAppService.mainApp.register() },
           unregister: { try SMAppService.mainApp.unregister() })
    }
    static func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
