import Foundation
import Darwin
public struct ProcessResult {
    public let status: Int32
    public let stdout: String
    public let stderr: String
    public let truncated: Bool
}
public struct ProcessRunner {
    public init() {}
    public func run(executable: URL, arguments: [String], timeout: TimeInterval) throws -> ProcessResult {
        guard timeout > 0 else { throw SwitcherError.message("命令超时时间无效。") }
        // Files avoid pipe-buffer deadlocks and let us cap what is loaded into memory.
        // The bundled helper uses stdio, so repeated output appends normally.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DDCSwitcher-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: folder) }
        let outURL = folder.appendingPathComponent("stdout")
        let errURL = folder.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: outURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        FileManager.default.createFile(atPath: errURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let out = try FileHandle(forWritingTo: outURL)
        let err = try FileHandle(forWritingTo: errURL)
        defer { try? out.close(); try? err.close() }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch {
            throw SwitcherError.message("无法启动显示器控制组件：\(error.localizedDescription)")
        }
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            if process.isRunning { process.terminate() }
            if finished.wait(timeout: .now() + 0.25) == .timedOut, process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                _ = finished.wait(timeout: .now() + 0.5)
            }
            throw SwitcherError.message("显示器控制命令超时，请检查连接线、扩展坞和 DDC/CI 设置。")
        }
        func read(_ url: URL) throws -> (String, Bool) {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: 262145) ?? Data()
            return (String(decoding: data.prefix(262144), as: UTF8.self), data.count > 262144)
        }
        let stdout = try read(outURL)
        let stderr = try read(errURL)
        return ProcessResult(status: process.terminationStatus, stdout: stdout.0, stderr: stderr.0,
                             truncated: stdout.1 || stderr.1)
    }
}
public struct CommandBackend {
    public let executable: URL
    public init(executable: URL) { self.executable = executable }
    public func listDisplays() throws -> [DisplayInfo] {
        let result = try ProcessRunner().run(executable: executable, arguments: ["display", "list"], timeout: 6)
        if result.status == 1, result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "No external display found, aborting",
           result.stderr.isEmpty { return [] }
        try check(result)
        return try DisplayParser.parse(result.stdout)
    }
    public func send(_ action: SwitchAction) throws -> String {
        let connected = try listDisplays()
        let args = try action.arguments(connectedIDs: Set(connected.map(\.id)))
        let result = try ProcessRunner().run(executable: executable, arguments: args, timeout: 6)
        try check(result)
        let receipt = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard receipt == "Writing \(action.inputValue)" else {
            throw SwitcherError.message("控制组件没有返回发送回执：\(receipt.prefix(300))")
        }
        return receipt
    }
    private func check(_ result: ProcessResult) throws {
        guard result.status == 0, !result.truncated else {
            let detail = (result.stdout + "\n" + result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            throw SwitcherError.message("DDC 命令失败（\(result.status)）：\(detail.prefix(600))")
        }
    }
}
