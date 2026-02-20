import XCTest
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

    func testPasteDispatchDecisionSendsWhenRetriesExhausted() {
        let decision = AutoPaste.pasteDispatchDecision(
            frontmostPID: 111,
            targetPID: 222,
            retriesRemaining: 0
        )

        XCTAssertEqual(decision, .send)
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
                XCTAssertEqual(retrySteps, 3)
                return
            case .retry(let nextRetriesRemaining):
                retrySteps += 1
                retriesRemaining = nextRetriesRemaining
            }
        }
    }
}
