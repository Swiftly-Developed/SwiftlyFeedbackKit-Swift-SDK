import Vapor
import Fluent

struct VoteController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let votes = routes.grouped("feedbacks", ":feedbackId", "votes")

        votes.post(use: vote)
        votes.delete(use: unvote)

        // Unsubscribe endpoint (no auth required - uses permission key)
        routes.get("votes", "unsubscribe", use: unsubscribeGet)
    }

    @Sendable
    func vote(req: Request) async throws -> VoteResponseDTO {
        guard let feedbackId = req.parameters.get("feedbackId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid feedback ID")
        }

        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == feedbackId)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        // Check if project is archived
        if feedback.project.isArchived {
            throw Abort(.forbidden, reason: "Cannot vote on feedback for an archived project")
        }

        // Check if feedback status allows voting
        if feedback.status == .completed || feedback.status == .rejected {
            throw Abort(.forbidden, reason: "Cannot vote on feedback that is \(feedback.status.rawValue)")
        }

        let dto = try req.content.decode(CreateVoteDTO.self)

        // Validate userId
        guard !dto.userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "User ID cannot be empty")
        }

        // Validate email if provided
        let email = dto.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let email = email, !email.isEmpty {
            let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
            guard email.range(of: emailRegex, options: .regularExpression) != nil else {
                throw Abort(.badRequest, reason: "Invalid email format")
            }
        }

        // Check if user already voted
        let existingVote = try await Vote.query(on: req.db)
            .filter(\.$userId == dto.userId)
            .filter(\.$feedback.$id == feedbackId)
            .first()

        if existingVote != nil {
            throw Abort(.conflict, reason: "User has already voted for this feedback")
        }

        var notifyStatusChange = dto.notifyStatusChange ?? false
        let validEmail = (email?.isEmpty == false) ? email : nil

        // Only allow notification opt-in if project owner has Team tier
        // Voter notifications are a Team-tier feature
        if notifyStatusChange && validEmail != nil {
            try await feedback.project.$owner.load(on: req.db)
            if !feedback.project.owner.subscriptionTier.meetsRequirement(.team) {
                // Silently disable - don't error, just don't save the preference
                notifyStatusChange = false
            }
        }

        let vote = Vote(
            userId: dto.userId,
            feedbackId: feedbackId,
            email: validEmail,
            notifyStatusChange: notifyStatusChange && validEmail != nil
        )
        try await vote.save(on: req.db)

        // Update vote count
        feedback.voteCount += 1
        try await feedback.save(on: req.db)

        // Sync vote count to ClickUp if configured
        let project = feedback.project
        if let votesFieldId = project.clickupVotesFieldId,
           let taskId = feedback.clickupTaskId,
           let token = project.clickupToken {
            Task {
                try? await req.clickupService.setCustomFieldValue(
                    taskId: taskId,
                    fieldId: votesFieldId,
                    token: token,
                    value: feedback.voteCount
                )
            }
        }

        // Sync vote count to Notion if configured
        if let votesProperty = project.notionVotesProperty,
           !votesProperty.isEmpty,
           let pageId = feedback.notionPageId,
           let token = project.notionToken {
            Task {
                try? await req.notionService.updatePageNumber(
                    pageId: pageId,
                    token: token,
                    propertyName: votesProperty,
                    value: feedback.voteCount
                )
            }
        }

        // Sync vote count to Monday.com if configured
        if let votesColumnId = project.mondayVotesColumnId,
           !votesColumnId.isEmpty,
           let itemId = feedback.mondayItemId,
           let boardId = project.mondayBoardId,
           let token = project.mondayToken {
            Task {
                try? await req.mondayService.updateItemNumber(
                    boardId: boardId,
                    itemId: itemId,
                    columnId: votesColumnId,
                    token: token,
                    value: feedback.voteCount
                )
            }
        }

        return VoteResponseDTO(feedbackId: feedbackId, voteCount: feedback.voteCount, hasVoted: true)
    }

    @Sendable
    func unvote(req: Request) async throws -> VoteResponseDTO {
        guard let feedbackId = req.parameters.get("feedbackId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid feedback ID")
        }

        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == feedbackId)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        // Check if project is archived
        if feedback.project.isArchived {
            throw Abort(.forbidden, reason: "Cannot modify votes on feedback for an archived project")
        }

        let dto = try req.content.decode(CreateVoteDTO.self)

        guard let vote = try await Vote.query(on: req.db)
            .filter(\.$userId == dto.userId)
            .filter(\.$feedback.$id == feedbackId)
            .first() else {
            throw Abort(.notFound, reason: "Vote not found")
        }

        try await vote.delete(on: req.db)

        // Update vote count
        feedback.voteCount = max(0, feedback.voteCount - 1)
        try await feedback.save(on: req.db)

        // Sync vote count to ClickUp if configured
        let project = feedback.project
        if let votesFieldId = project.clickupVotesFieldId,
           let taskId = feedback.clickupTaskId,
           let token = project.clickupToken {
            Task {
                try? await req.clickupService.setCustomFieldValue(
                    taskId: taskId,
                    fieldId: votesFieldId,
                    token: token,
                    value: feedback.voteCount
                )
            }
        }

        // Sync vote count to Notion if configured
        if let votesProperty = project.notionVotesProperty,
           !votesProperty.isEmpty,
           let pageId = feedback.notionPageId,
           let token = project.notionToken {
            Task {
                try? await req.notionService.updatePageNumber(
                    pageId: pageId,
                    token: token,
                    propertyName: votesProperty,
                    value: feedback.voteCount
                )
            }
        }

        // Sync vote count to Monday.com if configured
        if let votesColumnId = project.mondayVotesColumnId,
           !votesColumnId.isEmpty,
           let itemId = feedback.mondayItemId,
           let boardId = project.mondayBoardId,
           let token = project.mondayToken {
            Task {
                try? await req.mondayService.updateItemNumber(
                    boardId: boardId,
                    itemId: itemId,
                    columnId: votesColumnId,
                    token: token,
                    value: feedback.voteCount
                )
            }
        }

        return VoteResponseDTO(feedbackId: feedbackId, voteCount: feedback.voteCount, hasVoted: false)
    }

    @Sendable
    func unsubscribeGet(req: Request) async throws -> Response {
        guard let keyString = req.query[String.self, at: "key"],
              let key = UUID(uuidString: keyString) else {
            return Response(
                status: .ok,
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: .init(string: unsubscribeErrorHTML(message: "Missing or invalid unsubscribe key."))
            )
        }

        guard let vote = try await Vote.query(on: req.db)
            .filter(\.$permissionKey == key)
            .with(\.$feedback)
            .first() else {
            return Response(
                status: .ok,
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: .init(string: unsubscribeErrorHTML(message: "This unsubscribe link is invalid or has already been used."))
            )
        }

        let feedbackTitle = vote.feedback.title

        // Disable notifications
        vote.notifyStatusChange = false
        vote.permissionKey = nil
        try await vote.save(on: req.db)

        return Response(
            status: .ok,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            body: .init(string: unsubscribeSuccessHTML(feedbackTitle: feedbackTitle))
        )
    }

    private func unsubscribeSuccessHTML(feedbackTitle: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Unsubscribed - Feedback Kit</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: linear-gradient(135deg, #f5f7fa 0%, #e4e8ec 100%);
                    min-height: 100vh;
                    margin: 0;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 20px;
                    box-sizing: border-box;
                }
                .container {
                    max-width: 420px;
                    background: white;
                    padding: 40px;
                    border-radius: 16px;
                    box-shadow: 0 4px 24px rgba(0,0,0,0.1);
                    text-align: center;
                }
                .icon {
                    width: 64px;
                    height: 64px;
                    background: linear-gradient(135deg, #10B981 0%, #059669 100%);
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0 auto 24px;
                }
                .icon svg {
                    width: 32px;
                    height: 32px;
                    fill: white;
                }
                h1 {
                    color: #1f2937;
                    font-size: 24px;
                    margin: 0 0 12px;
                    font-weight: 600;
                }
                .description {
                    color: #6b7280;
                    font-size: 16px;
                    margin: 0 0 20px;
                    line-height: 1.5;
                }
                .feedback-title {
                    color: #374151;
                    font-weight: 600;
                    font-size: 15px;
                    background: #f3f4f6;
                    padding: 12px 16px;
                    border-radius: 8px;
                    margin: 0 0 24px;
                    word-break: break-word;
                }
                .footer {
                    color: #9ca3af;
                    font-size: 13px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon">
                    <svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
                </div>
                <h1>Unsubscribed</h1>
                <p class="description">You will no longer receive status updates for:</p>
                <p class="feedback-title">\(feedbackTitle.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;"))</p>
                <p class="footer">You can close this page.</p>
            </div>
        </body>
        </html>
        """
    }

    private func unsubscribeErrorHTML(message: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Unsubscribe - Feedback Kit</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: linear-gradient(135deg, #f5f7fa 0%, #e4e8ec 100%);
                    min-height: 100vh;
                    margin: 0;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 20px;
                    box-sizing: border-box;
                }
                .container {
                    max-width: 420px;
                    background: white;
                    padding: 40px;
                    border-radius: 16px;
                    box-shadow: 0 4px 24px rgba(0,0,0,0.1);
                    text-align: center;
                }
                .icon {
                    width: 64px;
                    height: 64px;
                    background: linear-gradient(135deg, #F59E0B 0%, #D97706 100%);
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin: 0 auto 24px;
                }
                .icon svg {
                    width: 32px;
                    height: 32px;
                    fill: white;
                }
                h1 {
                    color: #1f2937;
                    font-size: 24px;
                    margin: 0 0 12px;
                    font-weight: 600;
                }
                .description {
                    color: #6b7280;
                    font-size: 16px;
                    margin: 0;
                    line-height: 1.5;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon">
                    <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
                </div>
                <h1>Unable to Unsubscribe</h1>
                <p class="description">\(message.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;"))</p>
            </div>
        </body>
        </html>
        """
    }
}
