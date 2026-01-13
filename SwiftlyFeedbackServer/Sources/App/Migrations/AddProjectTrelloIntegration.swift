import Fluent

struct AddProjectTrelloIntegration: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Add Trello fields to projects table
        try await database.schema("projects")
            .field("trello_token", .string)
            .field("trello_board_id", .string)
            .field("trello_board_name", .string)
            .field("trello_list_id", .string)
            .field("trello_list_name", .string)
            .field("trello_sync_status", .bool, .required, .sql(.default(false)))
            .field("trello_sync_comments", .bool, .required, .sql(.default(false)))
            .field("trello_is_active", .bool, .required, .sql(.default(true)))
            .update()

        // Add Trello fields to feedbacks table
        try await database.schema("feedbacks")
            .field("trello_card_url", .string)
            .field("trello_card_id", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("projects")
            .deleteField("trello_token")
            .deleteField("trello_board_id")
            .deleteField("trello_board_name")
            .deleteField("trello_list_id")
            .deleteField("trello_list_name")
            .deleteField("trello_sync_status")
            .deleteField("trello_sync_comments")
            .deleteField("trello_is_active")
            .update()

        try await database.schema("feedbacks")
            .deleteField("trello_card_url")
            .deleteField("trello_card_id")
            .update()
    }
}
