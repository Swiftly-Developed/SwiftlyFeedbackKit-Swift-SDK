import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// `configure` publishes `SwiftlyFeedback.current` after an async step, so a view created at
/// launch, as a `TabView` creates its tabs, can exist before there is a client.
///
/// The view models used to read `current` once, in `init`, and keep the nil: no request, no
/// error, and a blank list for the life of the app, however soon configuration finished.
@Suite("Configuration finishing after the view is created", .isolatedSharedClient)
@MainActor
struct LateConfigurationTests {
    private static func makeClient(_ stub: StubURLProtocol.Session) -> SwiftlyFeedback {
        SwiftlyFeedback(
            apiKey: "sf_test_stub_key_not_a_credential",
            userId: "user-under-test",
            baseURL: URL(string: "https://stub.invalid/api/v1")!,
            session: stub.urlSession
        )
    }

    private static func enqueueList(_ items: [Feedback], on stub: StubURLProtocol.Session) throws {
        stub.enqueueResponse(data: try WireCoding.makeEncoder().encode(items))
    }

    /// Lets a task reach a state the test then acts on. Returns false if it never does.
    @discardableResult
    private static func eventually(
        within limit: Duration = .seconds(2),
        _ condition: () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + limit
        while !condition() {
            guard clock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return true
    }

    private static func listRequests(_ stub: StubURLProtocol.Session) -> [String] {
        stub.recordedRequests.filter { $0.path?.hasSuffix("/feedbacks") == true }.map(\.method)
    }

    // MARK: - List

    /// The demo app's path: the tab's view exists at launch and first appears after `configure`.
    @Test("A list created before configuration loads when it appears after configuration")
    func listAppearingAfterConfigurationLoads() async throws {
        let stub = StubURLProtocol.Session()
        let item = FeedbackFixtures.make(title: "Demo test item")
        try Self.enqueueList([item], on: stub)

        let viewModel = FeedbackListViewModel(swiftlyFeedback: nil)
        SwiftlyFeedback.current = Self.makeClient(stub)
        await viewModel.loadFeedbackIfNeeded()

        #expect(Self.listRequests(stub) == ["GET"])
        #expect(viewModel.feedbackItems.map(\.id) == [item.id])
    }

    @Test("A list already on screen loads by itself when configuration finishes")
    func listOnScreenLoadsWhenConfigurationFinishes() async throws {
        let stub = StubURLProtocol.Session()
        let item = FeedbackFixtures.make(title: "Demo test item")
        try Self.enqueueList([item], on: stub)

        let viewModel = FeedbackListViewModel(swiftlyFeedback: nil)
        let load = Task { await viewModel.loadFeedbackIfNeeded() }
        await Self.eventually { viewModel.state == .loading }

        SwiftlyFeedback.current = Self.makeClient(stub)
        await load.value

        #expect(Self.listRequests(stub) == ["GET"])
        #expect(viewModel.feedbackItems.map(\.id) == [item.id])
        #expect(viewModel.showSkeleton == false)
    }

    @Test("A list waiting for configuration shows the skeleton, not a blank screen")
    func listWaitingShowsSkeleton() async throws {
        let stub = StubURLProtocol.Session()
        try Self.enqueueList([], on: stub)

        let viewModel = FeedbackListViewModel(swiftlyFeedback: nil)
        let load = Task { await viewModel.loadFeedbackIfNeeded() }
        await Self.eventually { viewModel.showSkeleton }

        #expect(viewModel.showSkeleton)
        #expect(viewModel.state == .loading)
        #expect(stub.recordedRequests.isEmpty)

        SwiftlyFeedback.current = Self.makeClient(stub)
        await load.value
        #expect(viewModel.state == .loaded([]))
    }

    @Test("An explicitly passed client wins over the shared one")
    func explicitClientWins() async throws {
        let explicit = StubURLProtocol.Session()
        let shared = StubURLProtocol.Session()
        try Self.enqueueList([], on: explicit)
        SwiftlyFeedback.current = Self.makeClient(shared)

        let viewModel = FeedbackListViewModel(swiftlyFeedback: Self.makeClient(explicit))
        await viewModel.loadFeedbackIfNeeded()

        #expect(Self.listRequests(explicit) == ["GET"])
        #expect(shared.recordedRequests.isEmpty)
    }

    @Test("An explicitly passed client does not wait for configuration")
    func explicitClientDoesNotWait() async throws {
        let explicit = StubURLProtocol.Session()
        try Self.enqueueList([], on: explicit)

        let viewModel = FeedbackListViewModel(swiftlyFeedback: Self.makeClient(explicit))
        await viewModel.loadFeedbackIfNeeded()

        #expect(SwiftlyFeedback.current == nil)
        #expect(viewModel.state == .loaded([]))
    }

    @Test("A list nothing ever configures stops at Retry instead of a skeleton forever")
    func listNeverConfiguredShowsRetry() async throws {
        let viewModel = FeedbackListViewModel(swiftlyFeedback: nil)
        viewModel.configurationPatience = .milliseconds(50)
        let load = Task { await viewModel.loadFeedbackIfNeeded() }
        defer { load.cancel() }

        await Self.eventually { viewModel.state != .loading && viewModel.state != .idle }

        #expect(viewModel.state == .failed(message: String(localized: .errorGeneric)))
        #expect(viewModel.showSkeleton == false)
    }

    @Test("A list past its patience still loads by itself when configuration finishes")
    func listPastPatienceRecovers() async throws {
        let stub = StubURLProtocol.Session()
        let item = FeedbackFixtures.make()
        try Self.enqueueList([item], on: stub)

        let viewModel = FeedbackListViewModel(swiftlyFeedback: nil)
        viewModel.configurationPatience = .milliseconds(50)
        let load = Task { await viewModel.loadFeedbackIfNeeded() }
        await Self.eventually { viewModel.state != .loading && viewModel.state != .idle }

        SwiftlyFeedback.current = Self.makeClient(stub)
        await load.value

        #expect(viewModel.feedbackItems.map(\.id) == [item.id])
    }

    @Test("Retry replaces the wait, so one configuration sends one request")
    func retryReplacesTheWait() async throws {
        let stub = StubURLProtocol.Session()
        try Self.enqueueList([], on: stub)

        let viewModel = FeedbackListViewModel(swiftlyFeedback: nil)
        viewModel.configurationPatience = .milliseconds(50)
        let first = Task { await viewModel.loadFeedbackIfNeeded() }
        await Self.eventually { viewModel.state != .loading && viewModel.state != .idle }

        let retry = Task { await viewModel.loadFeedback() }
        await Self.eventually { viewModel.state == .loading }
        await first.value

        SwiftlyFeedback.current = Self.makeClient(stub)
        await retry.value

        #expect(Self.listRequests(stub) == ["GET"])
        #expect(viewModel.state == .loaded([]))
    }

    @Test("Leaving the screen ends the wait, and coming back loads")
    func cancellingTheWaitAllowsAReload() async throws {
        let stub = StubURLProtocol.Session()
        try Self.enqueueList([], on: stub)

        let viewModel = FeedbackListViewModel(swiftlyFeedback: nil)
        let left = Task { await viewModel.loadFeedbackIfNeeded() }
        await Self.eventually { viewModel.state == .loading }
        left.cancel()
        await left.value

        #expect(viewModel.state == .idle)
        #expect(viewModel.showSkeleton == false)
        #expect(stub.recordedRequests.isEmpty)

        SwiftlyFeedback.current = Self.makeClient(stub)
        await viewModel.loadFeedbackIfNeeded()
        #expect(viewModel.state == .loaded([]))
    }

    @Test("A client resolved once stays, as it does for a view created after configuration")
    func resolvedClientIsKept() async throws {
        let first = StubURLProtocol.Session()
        let second = StubURLProtocol.Session()
        try Self.enqueueList([], on: first)
        try Self.enqueueList([], on: first)

        let viewModel = FeedbackListViewModel(swiftlyFeedback: nil)
        SwiftlyFeedback.current = Self.makeClient(first)
        await viewModel.loadFeedbackIfNeeded()

        SwiftlyFeedback.current = Self.makeClient(second)
        await viewModel.loadFeedback()

        #expect(Self.listRequests(first) == ["GET", "GET"])
        #expect(second.recordedRequests.isEmpty)
    }

    // MARK: - Waiting

    @Test("Every waiter gets the client, and clearing current wakes nobody")
    func waitersResumeOnlyOnAClient() async throws {
        let stub = StubURLProtocol.Session()
        let client = Self.makeClient(stub)
        let one = Task { await SwiftlyFeedback.waitForCurrent() }
        let two = Task { await SwiftlyFeedback.waitForCurrent() }
        await Task.yield()

        SwiftlyFeedback.current = nil
        SwiftlyFeedback.current = client

        #expect(await one.value === client)
        #expect(await two.value === client)
    }

    @Test("A wait with a timeout returns nil when nothing configures")
    func timedWaitEnds() async throws {
        #expect(await SwiftlyFeedback.waitForCurrent(timeout: .milliseconds(20)) == nil)
    }

    @Test("A cancelled wait returns nil, whether it was cancelled before or during")
    func cancelledWaitEnds() async throws {
        let during = Task { await SwiftlyFeedback.waitForCurrent() }
        await Task.yield()
        during.cancel()
        #expect(await during.value == nil)

        let before = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await SwiftlyFeedback.waitForCurrent()
        }
        #expect(await before.value == nil)
    }

    // MARK: - Detail

    @Test("A detail screen created before configuration loads comments when it appears after")
    func detailAppearingAfterConfigurationLoadsComments() async throws {
        let stub = StubURLProtocol.Session()
        stub.enqueueResponse(data: Data("[]".utf8))

        let viewModel = FeedbackDetailViewModel(feedback: FeedbackFixtures.make(), swiftlyFeedback: nil)
        SwiftlyFeedback.current = Self.makeClient(stub)
        await viewModel.loadComments()

        #expect(stub.recordedRequests.map(\.method) == ["GET"])
        #expect(viewModel.hasLoadedCommentsOnce)
    }

    @Test("A detail screen on screen loads comments by itself when configuration finishes")
    func detailOnScreenLoadsCommentsWhenConfigurationFinishes() async throws {
        let stub = StubURLProtocol.Session()
        stub.enqueueResponse(data: Data("[]".utf8))

        let viewModel = FeedbackDetailViewModel(feedback: FeedbackFixtures.make(), swiftlyFeedback: nil)
        let load = Task { await viewModel.loadComments() }
        await Self.eventually { viewModel.isLoadingComments }
        #expect(viewModel.isLoadingComments)

        SwiftlyFeedback.current = Self.makeClient(stub)
        await load.value

        #expect(viewModel.hasLoadedCommentsOnce)
        #expect(viewModel.isLoadingComments == false)
    }

    @Test("A vote from a detail screen created before configuration reaches the server")
    func detailVoteAfterConfigurationIsSent() async throws {
        let stub = StubURLProtocol.Session()
        let feedback = FeedbackFixtures.make(voteCount: 1, hasVoted: false)
        stub.enqueueResponse(data: try WireCoding.makeEncoder().encode(
            VoteResult(feedbackId: feedback.id, voteCount: 2, hasVoted: true)
        ))

        let viewModel = FeedbackDetailViewModel(feedback: feedback, swiftlyFeedback: nil)
        SwiftlyFeedback.current = Self.makeClient(stub)
        await viewModel.submitVote(email: nil, notify: false)

        #expect(stub.recordedRequests.map(\.method) == ["POST"])
        #expect(viewModel.currentFeedback.voteCount == 2)
    }

    @Test("A detail screen nothing ever configures stops its placeholders and reports it")
    func detailNeverConfiguredReports() async throws {
        let viewModel = FeedbackDetailViewModel(feedback: FeedbackFixtures.make(), swiftlyFeedback: nil)
        viewModel.configurationPatience = .milliseconds(20)
        let load = Task { await viewModel.loadComments() }
        defer { load.cancel() }

        await Self.eventually { viewModel.showingError }

        #expect(viewModel.showingError)
        #expect(viewModel.isLoadingComments == false)
    }

    @Test("A pull on a detail screen with no client ends at once")
    func detailRefreshDoesNotWait() async throws {
        let viewModel = FeedbackDetailViewModel(feedback: FeedbackFixtures.make(), swiftlyFeedback: nil)
        await viewModel.refreshComments()
        #expect(viewModel.hasLoadedCommentsOnce == false)
    }

    // MARK: - Submit

    private static func filledSubmitModel() -> SubmitFeedbackViewModel {
        let viewModel = SubmitFeedbackViewModel()
        viewModel.title = "A title"
        viewModel.description = "A description"
        return viewModel
    }

    @Test("A submit form created before configuration sends once configuration has finished")
    func submitAfterConfigurationIsSent() async throws {
        let stub = StubURLProtocol.Session()
        stub.enqueueResponse(data: try WireCoding.makeEncoder().encode(FeedbackFixtures.make()))

        let viewModel = Self.filledSubmitModel()
        SwiftlyFeedback.current = Self.makeClient(stub)
        await viewModel.submit(using: nil)

        #expect(stub.recordedRequests.map(\.method) == ["POST"])
        #expect(viewModel.isSubmitted)
    }

    @Test("A submit tapped during configuration waits and then sends")
    func submitDuringConfigurationWaits() async throws {
        let stub = StubURLProtocol.Session()
        stub.enqueueResponse(data: try WireCoding.makeEncoder().encode(FeedbackFixtures.make()))

        let viewModel = Self.filledSubmitModel()
        let submit = Task { await viewModel.submit(using: nil) }
        await Self.eventually { viewModel.isSubmitting }
        #expect(viewModel.isSubmitting)

        SwiftlyFeedback.current = Self.makeClient(stub)
        await submit.value

        #expect(stub.recordedRequests.map(\.method) == ["POST"])
        #expect(viewModel.isSubmitted)
    }

    @Test("A submit nothing ever configures reports a failure and keeps the form")
    func submitNeverConfiguredReports() async throws {
        let viewModel = Self.filledSubmitModel()
        viewModel.configurationPatience = .milliseconds(20)

        await viewModel.submit(using: nil)

        #expect(viewModel.showingError)
        #expect(viewModel.isSubmitted == false)
        #expect(viewModel.isSubmitting == false)
        #expect(viewModel.title == "A title")
    }

    @Test("An explicit client passed to submit wins over the shared one")
    func submitExplicitClientWins() async throws {
        let explicit = StubURLProtocol.Session()
        let shared = StubURLProtocol.Session()
        explicit.enqueueResponse(data: try WireCoding.makeEncoder().encode(FeedbackFixtures.make()))
        SwiftlyFeedback.current = Self.makeClient(shared)

        let viewModel = Self.filledSubmitModel()
        await viewModel.submit(using: Self.makeClient(explicit))

        #expect(explicit.recordedRequests.map(\.method) == ["POST"])
        #expect(shared.recordedRequests.isEmpty)
    }
}
