import XCTest
@testable import DDCSwitcherCore

final class StatusTests: XCTestCase {
    func testDiscoveryCannotEraseRegistrationErrorUntilRegistrationSucceeds() {
        var status = StatusState()
        status.registrationFailed("快捷键冲突")
        status.update("发现 1 台显示器")
        XCTAssertEqual(status.message, "快捷键冲突")
        XCTAssertTrue(status.isError)
        status.registrationSucceeded()
        status.update("快捷键已生效")
        XCTAssertEqual(status.message, "快捷键已生效")
        XCTAssertFalse(status.isError)
    }
}
