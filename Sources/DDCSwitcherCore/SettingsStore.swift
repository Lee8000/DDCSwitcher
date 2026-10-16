import Foundation
public struct SettingsStore {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> Configuration {
        guard FileManager.default.fileExists(atPath: url.path) else { return Configuration() }
        do {
            let configuration = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: url))
            try configuration.validate()
            return configuration
        } catch {
            throw SwitcherError.message("无法读取设置，原文件已保留。\n\(url.path)\n\(error.localizedDescription)")
        }
    }
    public func save(_ configuration: Configuration) throws {
        try configuration.validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configuration).write(to: url, options: .atomic)
        // Atomic replacement is the commit point. A best-effort permission change must not
        // make callers roll back their runtime state after the file was already saved.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
