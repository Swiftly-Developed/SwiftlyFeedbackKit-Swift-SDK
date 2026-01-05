import Fluent

struct AddProjectClickUpIntegration: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Add ClickUp fields to projects table
        try await database.schema("projects")
            .field("clickup_token", .string)
            .field("clickup_list_id", .string)
            .field("clickup_workspace_name", .string)
            .field("clickup_list_name", .string)
            .field("clickup_default_tags", .array(of: .string))
            .field("clickup_sync_status", .bool, .required, .sql(.default(false)))
            .field("clickup_sync_comments", .bool, .required, .sql(.default(false)))
            .field("clickup_votes_field_id", .string)
            .update()

        // Add ClickUp fields to feedbacks table
        try await database.schema("feedbacks")
            .field("clickup_task_url", .string)
            .field("clickup_task_id", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("projects")
            .deleteField("clickup_token")
            .deleteField("clickup_list_id")
            .deleteField("clickup_workspace_name")
            .deleteField("clickup_list_name")
            .deleteField("clickup_default_tags")
            .deleteField("clickup_sync_status")
            .deleteField("clickup_sync_comments")
            .deleteField("clickup_votes_field_id")
            .update()

        try await database.schema("feedbacks")
            .deleteField("clickup_task_url")
            .deleteField("clickup_task_id")
            .update()
    }
}
