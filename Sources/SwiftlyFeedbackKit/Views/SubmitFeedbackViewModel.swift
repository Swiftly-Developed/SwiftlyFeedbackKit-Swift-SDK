import SwiftUI

@MainActor
@Observable
final class SubmitFeedbackViewModel {
    var title = ""
    var description = ""
    var category: FeedbackCategory = .featureRequest
    var email = SwiftlyFeedback.configuration.userEmail ?? ""
    var subscribeToMailingList = SwiftlyFeedback.configuration.mailingListDefaultOptIn
    var operationalEmails = true
    var marketingEmails = true
    var isSubmitting = false
    var isSubmitted = false
    var showingError = false
    var errorMessage: String?
    var hasInvalidApiKey = false
    /// How long a submit waits for `configure` before it reports a failure.
    var configurationPatience = SwiftlyFeedback.configurationPatience

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The reason the form cannot be submitted yet, title-first (same trimming
    /// as `isValid`), or `nil` when the form is valid. Rendered visually under
    /// the form and read by VoiceOver on the submit button's hint.
    var unmetRequirement: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: .feedbackFormValidationTitleRequired)
        }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: .feedbackFormValidationDescriptionRequired)
        }
        return nil
    }

    func buildEmailTypes() -> [String]? {
        guard subscribeToMailingList else { return nil }
        var types: [String] = []
        if operationalEmails { types.append("operational") }
        if marketingEmails { types.append("marketing") }
        return types.isEmpty ? nil : types
    }

    func submit(using swiftlyFeedback: SwiftlyFeedback?) async {
        guard isValid else { return }
        guard !hasInvalidApiKey else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        // The form can be older than the client. The wait ends, because a send must not fire
        // long after the user was told it failed.
        let client: SwiftlyFeedback?
        if let swiftlyFeedback {
            client = swiftlyFeedback
        } else {
            client = await SwiftlyFeedback.waitForCurrent(timeout: configurationPatience)
        }
        guard let sf = client else {
            SDKLogger.error("No client after \(configurationPatience). Call SwiftlyFeedback.configure, or pass a client to the view.")
            errorMessage = String(localized: .errorGeneric)
            showingError = true
            return
        }

        do {
            _ = try await sf.submitFeedback(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                email: email.isEmpty ? nil : email,
                subscribeToMailingList: !email.isEmpty ? subscribeToMailingList : nil,
                mailingListEmailTypes: !email.isEmpty ? buildEmailTypes() : nil
            )
            isSubmitted = true
        } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
            hasInvalidApiKey = true
        } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
            errorMessage = message ?? String(localized: .errorFeedbackLimitMessage)
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
