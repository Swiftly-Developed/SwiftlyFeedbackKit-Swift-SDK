import Vapor

struct TrelloService {
    private let client: Client
    private let baseURL = "https://api.trello.com/1"

    init(client: Client) {
        self.client = client
    }

    // MARK: - Response Types

    struct TrelloBoard: Codable {
        let id: String
        let name: String
        let closed: Bool
        let url: String
    }

    struct TrelloList: Codable {
        let id: String
        let name: String
        let closed: Bool
        let idBoard: String
    }

    struct TrelloCard: Codable {
        let id: String
        let name: String
        let desc: String
        let url: String
        let shortUrl: String
        let idList: String
        let idBoard: String
    }

    // MARK: - API Key

    private var apiKey: String {
        Environment.get("TRELLO_API_KEY") ?? ""
    }

    private func authParams(token: String) -> String {
        "key=\(apiKey)&token=\(token)"
    }

    // MARK: - Discovery

    func getBoards(token: String) async throws -> [TrelloBoard] {
        let url = URI(string: "\(baseURL)/members/me/boards?\(authParams(token: token))&filter=open")

        let response = try await client.get(url)

        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Failed to fetch Trello boards: \(response.status)")
        }

        return try response.content.decode([TrelloBoard].self)
    }

    func getLists(token: String, boardId: String) async throws -> [TrelloList] {
        let url = URI(string: "\(baseURL)/boards/\(boardId)/lists?\(authParams(token: token))&filter=open")

        let response = try await client.get(url)

        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Failed to fetch Trello lists: \(response.status)")
        }

        return try response.content.decode([TrelloList].self)
    }

    // MARK: - Card Operations

    func createCard(
        token: String,
        listId: String,
        name: String,
        description: String
    ) async throws -> TrelloCard {
        let url = URI(string: "\(baseURL)/cards?\(authParams(token: token))")

        struct CreateCardRequest: Content {
            let idList: String
            let name: String
            let desc: String
            let pos: String
        }

        let body = CreateCardRequest(
            idList: listId,
            name: name,
            desc: description,
            pos: "bottom"
        )

        let response = try await client.post(url) { req in
            try req.content.encode(body)
        }

        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Failed to create Trello card: \(response.status)")
        }

        return try response.content.decode(TrelloCard.self)
    }

    func moveCard(token: String, cardId: String, toListId: String) async throws {
        let url = URI(string: "\(baseURL)/cards/\(cardId)?\(authParams(token: token))")

        struct MoveCardRequest: Content {
            let idList: String
        }

        let response = try await client.put(url) { req in
            try req.content.encode(MoveCardRequest(idList: toListId))
        }

        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Failed to move Trello card: \(response.status)")
        }
    }

    func addComment(token: String, cardId: String, text: String) async throws {
        let url = URI(string: "\(baseURL)/cards/\(cardId)/actions/comments?\(authParams(token: token))")

        struct AddCommentRequest: Content {
            let text: String
        }

        let response = try await client.post(url) { req in
            try req.content.encode(AddCommentRequest(text: text))
        }

        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Failed to add comment to Trello card: \(response.status)")
        }
    }

    // MARK: - Content Building

    func buildCardDescription(
        feedback: Feedback,
        projectName: String,
        voteCount: Int,
        mrr: Double?
    ) -> String {
        var description = """
        ## \(feedback.category.displayName)

        \(feedback.description)

        ---

        **Source:** FeedbackKit
        **Project:** \(projectName)
        **Status:** \(feedback.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
        **Votes:** \(voteCount)
        """

        if let mrr = mrr, mrr > 0 {
            description += "\n**MRR:** $\(String(format: "%.2f", mrr))"
        }

        if let userEmail = feedback.userEmail {
            description += "\n**Submitted by:** \(userEmail)"
        }

        description += "\n\n---\n*Synced from FeedbackKit*"

        return description
    }
}

// MARK: - Request Extension

extension Request {
    var trelloService: TrelloService {
        TrelloService(client: self.client)
    }
}

