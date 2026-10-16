import XCTest
@testable import DDCSwitcherCore

final class RuntimeTests: XCTestCase {
    func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DDCSwitcherTests-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testSettingsRoundTripAndInvalidJSONIsPreserved() throws {
        let file = try temporaryDirectory().appendingPathComponent("settings.json")
        let store = SettingsStore(url: file)
        XCTAssertEqual(try store.load(), Configuration())
        let action = SwitchAction(name: "USB-C", displayID: "10ACB8A0-0000-0000-1419-0104A2435078", inputValue: 27)
        let config = Configuration(actions: [action])
        try store.save(config)
        XCTAssertEqual(try store.load(), config)
        let corrupt = Data("{bad json".utf8)
        try corrupt.write(to: file)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }

    func testProcessPreservesArgumentBoundariesAndCapturesFailures() throws {
        let result = try ProcessRunner().run(executable: URL(fileURLWithPath: "/usr/bin/printf"),
                                             arguments: ["%s", "$(should-not-run); with spaces"], timeout: 2)
        XCTAssertEqual(result.stdout, "$(should-not-run); with spaces")
        XCTAssertEqual(result.status, 0)
        let failed = try ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sh"),
                                             arguments: ["-c", "printf reason >&2; exit 7"], timeout: 2)
        XCTAssertEqual(failed.status, 7)
        XCTAssertEqual(failed.stderr, "reason")
    }

    func testTimeoutEscalatesWhenChildIgnoresTermination() {
        let start = Date()
        XCTAssertThrowsError(try ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sh"),
                  arguments: ["-c", "trap '' TERM; while :; do :; done"], timeout: 0.15))
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    func testLargeOutputDoesNotDeadlockAndIsCapped() throws {
        let r = try ProcessRunner().run(executable: URL(fileURLWithPath: "/usr/bin/head"),
                                        arguments: ["-c", "1000000", "/dev/zero"], timeout: 3)
        XCTAssertEqual(r.status, 0)
        XCTAssertLessThanOrEqual(r.stdout.utf8.count, 262144)
        XCTAssertTrue(r.truncated)
    }

    func makeBackend(_ body: String) throws -> CommandBackend {
        let executable = try temporaryDirectory().appendingPathComponent("fake-ddc")
        try Data(("#!/bin/sh\n" + body).utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return CommandBackend(executable: executable)
    }

    func testFullBackendExchangeUsesStableMonitorAndConfirmsWriteReceipt() throws {
        let id = "10ACB8A0-0000-0000-1419-0104A2435078"
        let backend = try makeBackend("""
        if [ "$2" = list ]; then printf '[1] Test Monitor (\(id))\\n'; exit 0; fi
        if [ "$1" = display ] && [ "$2" = '\(id)' ] && [ "$3" = set ] && [ "$4" = input ] && [ "$5" = 17 ]; then printf 'Writing 17\\n'; exit 0; fi
        printf 'wrong arguments' >&2; exit 9
        """)
        XCTAssertEqual(try backend.listDisplays().map(\.id), [id])
        XCTAssertEqual(try backend.send(SwitchAction(name: "HDMI", displayID: id)), "Writing 17")
    }

    func testEmptyDisplayListHandledButUnknownFailureAndFalseSuccessReported() throws {
        let noDisplays = try makeBackend("printf 'No external display found, aborting'; exit 1")
        XCTAssertEqual(try noDisplays.listDisplays(), [])
        let bad = try makeBackend("printf 'DDC communication failure'; exit 1")
        XCTAssertThrowsError(try bad.listDisplays())
        let lying = try makeBackend("""
        if [ "$2" = list ]; then printf '[1] Test (10ACB8A0-0000-0000-1419-0104A2435078)\\n'; else printf 'DDC communication failure'; fi
        """)
        XCTAssertThrowsError(try lying.send(SwitchAction(name: "HDMI", displayID: "10ACB8A0-0000-0000-1419-0104A2435078")))
    }
}
