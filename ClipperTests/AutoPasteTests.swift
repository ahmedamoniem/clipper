import XCTest
import Carbon
@testable import Clipper

final class AutoPasteTests: XCTestCase {
    func testPasteDispatchDecisionSendsWhenTargetIsFrontmost() {
        let decision = AutoPaste.pasteDispatchDecision(
            frontmostPID: 123,
            targetPID: 123,
            retriesRemaining: 8
        )

        XCTAssertEqual(decision, .send)
    }

    func testPasteDispatchDecisionCancelsWhenRetriesExhausted() {
        let decision = AutoPaste.pasteDispatchDecision(
            frontmostPID: 111,
            targetPID: 222,
            retriesRemaining: 0
        )

        XCTAssertEqual(decision, .cancel)
    }

    func testPasteDispatchDecisionCancelsWithoutForegroundApp() {
        XCTAssertEqual(AutoPaste.pasteDispatchDecision(frontmostPID: nil, targetPID: 222, retriesRemaining: 0), .cancel)
        XCTAssertEqual(AutoPaste.pasteDispatchDecision(frontmostPID: 111, targetPID: 222, retriesRemaining: -1), .cancel)
    }

    func testPasteDispatchDecisionRetriesAndDecrementsCount() {
        let decision = AutoPaste.pasteDispatchDecision(
            frontmostPID: 111,
            targetPID: 222,
            retriesRemaining: 3
        )

        XCTAssertEqual(decision, .retry(nextRetriesRemaining: 2))
    }

    func testPasteDispatchDecisionTerminatesAfterExpectedRetryCount() {
        var retriesRemaining = 3
        var retrySteps = 0

        while true {
            let decision = AutoPaste.pasteDispatchDecision(
                frontmostPID: 111,
                targetPID: 222,
                retriesRemaining: retriesRemaining
            )

            switch decision {
            case .send:
                XCTFail("Must never send to a different foreground app")
                return
            case .cancel:
                XCTAssertEqual(retrySteps, 3)
                return
            case .retry(let nextRetriesRemaining):
                retrySteps += 1
                retriesRemaining = nextRetriesRemaining
            }
        }
    }
    @MainActor
    func testInvalidHotkeyDoesNotCrashOrDiscardWorkingRegistration() throws {
        let owner = HotkeyManager()
        let contender = HotkeyManager()
        let modifiers = Int(cmdKey | optionKey | controlKey)
        try XCTSkipUnless(owner.register(keyCode: kVK_F19, modifierFlags: modifiers), "Test shortcut unavailable")
        XCTAssertFalse(owner.register(keyCode: -1, modifierFlags: Int.max))
        XCTAssertNotNil(owner.registrationError)
        XCTAssertFalse(contender.register(keyCode: kVK_F19, modifierFlags: modifiers))
        owner.unregister()
        XCTAssertTrue(contender.register(keyCode: kVK_F19, modifierFlags: modifiers))
    }

    @MainActor
    func testHotkeyConflictKeepsPreviousShortcut() throws {
        let owner = HotkeyManager()
        let contender = HotkeyManager()
        let probe = HotkeyManager()
        let modifiers = Int(cmdKey | optionKey | controlKey)
        try XCTSkipUnless(owner.register(keyCode: kVK_F19, modifierFlags: modifiers), "Test shortcut unavailable")
        try XCTSkipUnless(contender.register(keyCode: kVK_F18, modifierFlags: modifiers), "Test shortcut unavailable")
        XCTAssertFalse(contender.register(keyCode: kVK_F19, modifierFlags: modifiers))
        XCTAssertFalse(probe.register(keyCode: kVK_F18, modifierFlags: modifiers))
        contender.unregister()
        XCTAssertTrue(probe.register(keyCode: kVK_F18, modifierFlags: modifiers))
    }

}
