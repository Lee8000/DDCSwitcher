import XCTest
@testable import DDCSwitcherCore

final class LoginItemTests: XCTestCase {
    func testDefaultAndExternalChangesAreReadFromSystem() {
        var system = LoginItemState.notRegistered
        let item = LoginItemController(read: { system }, register: {}, unregister: {})
        XCTAssertFalse(item.state.isChecked)
        system = .enabled
        item.refresh()
        XCTAssertEqual(item.state, .enabled)
        system = .requiresApproval
        item.refresh()
        XCTAssertTrue(item.state.isChecked)
        XCTAssertTrue(item.state.needsApproval)
    }
    func testEnableAndDisableReadBackActualState() throws {
        var system = LoginItemState.notRegistered
        let item = LoginItemController(read: { system }, register: { system = .requiresApproval }, unregister: { system = .notRegistered })
        try item.setEnabled(true)
        XCTAssertEqual(item.state, .requiresApproval)
        try item.setEnabled(false)
        XCTAssertEqual(item.state, .notRegistered)
    }
    func testFailedChangeReadsActualStateAndPropagatesError() {
        var system = LoginItemState.enabled
        let item = LoginItemController(read: { system }, register: {}, unregister: {
            system = .requiresApproval
            throw SwitcherError.message("registration denied")
        })
        XCTAssertThrowsError(try item.setEnabled(false))
        XCTAssertEqual(item.state, .requiresApproval)
    }
    func testDemoNeverReadsOrWritesRealStartupRegistration() {
        var accesses = 0
        let item = LoginItemController(isDemo: true, read: { accesses += 1; return .enabled }, register: { accesses += 1 }, unregister: { accesses += 1 })
        item.refresh()
        XCTAssertThrowsError(try item.setEnabled(true))
        XCTAssertThrowsError(try item.setEnabled(false))
        XCTAssertEqual(item.state, .unavailable)
        XCTAssertEqual(accesses, 0)
    }
}
