import Fluent

struct AddIntegrationActiveToggles: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("projects")
            .field("slack_is_active", .bool, .required, .sql(.default(true)))
            .field("github_is_active", .bool, .required, .sql(.default(true)))
            .field("clickup_is_active", .bool, .required, .sql(.default(true)))
            .field("notion_is_active", .bool, .required, .sql(.default(true)))
            .field("monday_is_active", .bool, .required, .sql(.default(true)))
            .field("linear_is_active", .bool, .required, .sql(.default(true)))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("projects")
            .deleteField("slack_is_active")
            .deleteField("github_is_active")
            .deleteField("clickup_is_active")
            .deleteField("notion_is_active")
            .deleteField("monday_is_active")
            .deleteField("linear_is_active")
            .update()
    }
}
