import Foundation

public struct Comment: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let content: String
    public let userId: String
    public let isAdmin: Bool
    public let createdAt: Date?

    public init(id: UUID, content: String, userId: String, isAdmin: Bool, createdAt: Date?) {
        self.id = id
        self.content = content
        self.userId = userId
        self.isAdmin = isAdmin
        self.createdAt = createdAt
    }
}
