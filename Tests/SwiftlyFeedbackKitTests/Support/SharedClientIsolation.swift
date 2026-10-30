import Testing
@testable import SwiftlyFeedbackKit

/// Gives a test sole use of `SwiftlyFeedback.current`, starting from nil, and restores it after.
///
/// `current` is one value for the whole process and suites run in parallel, so `.serialized`
/// on one suite does not protect it from another. Every test that writes `current`, or needs it
/// to stay nil across a suspension, carries this trait. On a suite it applies per test.
struct SharedClientIsolationTrait: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        await SharedClientLock.shared.acquire()
        let saved = await MainActor.run {
            let saved = SwiftlyFeedback.current
            SwiftlyFeedback.current = nil
            return saved
        }
        do {
            try await function()
        } catch {
            await MainActor.run { SwiftlyFeedback.current = saved }
            await SharedClientLock.shared.release()
            throw error
        }
        await MainActor.run { SwiftlyFeedback.current = saved }
        await SharedClientLock.shared.release()
    }
}

extension Trait where Self == SharedClientIsolationTrait {
    /// See ``SharedClientIsolationTrait``.
    static var isolatedSharedClient: Self { SharedClientIsolationTrait() }
}

/// First come, first served. Held across suspensions, which rules out an `NSLock`.
private actor SharedClientLock {
    static let shared = SharedClientLock()

    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        guard isHeld else {
            isHeld = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
