import Foundation
import DDCSwitcherCore

final class DDCService {
    let backend: CommandBackend
    private let queue = DispatchQueue(label: "local.ddcswitcher.ddc", qos: .userInitiated)
    private(set) var busy = false // main-thread access only
    private var lastStarted = Date.distantPast
    init(executable: URL) { backend = CommandBackend(executable: executable) }

    func refresh(_ completion: @escaping (Result<[DisplayInfo], Error>) -> Void) {
        queue.async { [backend] in
            let result = Result { try backend.listDisplays() }
            DispatchQueue.main.async { completion(result) }
        }
    }
    @discardableResult
    func send(_ action: SwitchAction, completion: @escaping (Result<String, Error>) -> Void) -> Bool {
        guard !busy, Date().timeIntervalSince(lastStarted) > 0.8 else { return false }
        busy = true; lastStarted = Date()
        queue.async { [backend] in
            let result = Result { try backend.send(action) }
            DispatchQueue.main.async { self.busy = false; completion(result) }
        }
        return true
    }
}
