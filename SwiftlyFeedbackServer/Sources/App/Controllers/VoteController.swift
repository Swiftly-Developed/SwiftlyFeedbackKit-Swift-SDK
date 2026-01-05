import Vapor
import Fluent

struct VoteController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let votes = routes.grouped("feedbacks", ":feedbackId", "votes")

        votes.post(use: vote)
        votes.delete(use: unvote)
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

        // Check if user already voted
        let existingVote = try await Vote.query(on: req.db)
            .filter(\.$userId == dto.userId)
            .filter(\.$feedback.$id == feedbackId)
            .first()

        if existingVote != nil {
            throw Abort(.conflict, reason: "User has already voted for this feedback")
        }

        let vote = Vote(userId: dto.userId, feedbackId: feedbackId)
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

        return VoteResponseDTO(feedbackId: feedbackId, voteCount: feedback.voteCount, hasVoted: false)
    }
}
