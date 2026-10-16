import XCTest
@testable import DDCSwitcherCore

final class CoreTests: XCTestCase {
    let monitor = "10ACB8A0-0000-0000-1419-0104A2435078"
    func action(_ value: Int = 17) -> SwitchAction {
        SwitchAction(name: "HDMI 1", displayID: monitor, inputValue: value,
                     shortcut: Shortcut(keyCode: 18, modifiers: 256 | 2048 | 4096))
    }

    func testInputRangeAndExplicitStableIdentity() throws {
        for value in [0, 17, 27, 65535] { XCTAssertNoThrow(try action(value).validate()) }
        for value in [-1, 65536] { XCTAssertThrowsError(try action(value).validate()) }
        var a = action()
        for invalid in ["", "1", "2", "uuid=", "$(touch /tmp/unsafe)"] {
            a.displayID = invalid
            XCTAssertThrowsError(try a.validate())
        }
    }

    func testHotkeyNeedsCommandOrControlAndRejectsInvalidKeyCodes() {
        for modifiers: UInt32 in [0, 512, 2048, 512 | 2048] {
            XCTAssertThrowsError(try Shortcut(keyCode: 18, modifiers: modifiers).validate())
        }
        XCTAssertNoThrow(try Shortcut(keyCode: 18, modifiers: 4096 | 2048).validate())
        XCTAssertThrowsError(try Shortcut(keyCode: 999, modifiers: 4096).validate())
        XCTAssertThrowsError(try Shortcut(keyCode: 18, modifiers: 4096 | 1).validate())
    }

    func testDuplicateActiveHotkeysRejectedButDisabledActionsDoNotReserveKeys() throws {
        var b = action(27)
        b.name = "USB-C"
        XCTAssertThrowsError(try Configuration(actions: [action(), b]).validate())
        b.enabled = false
        XCTAssertNoThrow(try Configuration(actions: [action(), b]).validate())
    }

    func testArgumentsAreExactAndDisconnectedDisplaysCannotBeAddressed() throws {
        var a = action()
        XCTAssertEqual(try a.arguments(connectedIDs: [monitor]), ["display", monitor, "set", "input", "17"])
        a.mode = .lgAlternate
        a.inputValue = 144
        XCTAssertEqual(try a.arguments(connectedIDs: [monitor]), ["display", monitor, "set", "input-alt", "144"])
        XCTAssertThrowsError(try a.arguments(connectedIDs: []))
    }

    func testDetailedMonitorOutputAndNamesContainingParentheses() throws {
        let text = """
        [1] DELL (Office) (10ACB8A0-0000-0000-1419-0104A2435078)
         - Product name:  DELL (Office)
         - Manufacturer:  DEL
        [2] LG UltraFine (A1B2C3D4-0000-0000-0000-123456789ABC)
         - System UUID: A1B2C3D4-0000-0000-0000-123456789ABC
        """
        let displays = try DisplayParser.parse(text)
        XCTAssertEqual(displays.count, 2)
        guard displays.count == 2 else { return }
        XCTAssertEqual(displays[0].name, "DELL (Office)")
        XCTAssertEqual(displays[0].id, monitor)
        XCTAssertEqual(try DisplayParser.parse(""), [])
        XCTAssertThrowsError(try DisplayParser.parse("unexpected backend failure"))
        XCTAssertThrowsError(try DisplayParser.parse("[1] Bad ((null))"))
    }

    func testConfigurationRejectsFutureSchemaAndDuplicateIDs() {
        var c = Configuration(actions: [action()])
        c.schemaVersion = 2
        XCTAssertThrowsError(try c.validate())
        c.schemaVersion = 1
        c.actions.append(c.actions[0])
        c.actions[1].enabled = false
        XCTAssertThrowsError(try c.validate())
    }
}
