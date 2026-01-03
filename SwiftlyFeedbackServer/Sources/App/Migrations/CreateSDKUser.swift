import Fluent

struct CreateSDKUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sdk_users")
            .id()
            .field("user_id", .string, .required)
            .field("project_id", .uuid, .required, .references("projects", "id", onDelete: .cascade))
            .field("mrr", .double)
            .field("first_seen_at", .datetime)
            .field("last_seen_at", .datetime)
            .unique(on: "user_id", "project_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sdk_users").delete()
    }
}
