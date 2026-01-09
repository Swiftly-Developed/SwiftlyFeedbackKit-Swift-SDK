import Fluent

struct AddUserSubscriptionFields: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("subscription_tier", .string, .required, .sql(.default("free")))
            .field("subscription_status", .string)
            .field("subscription_product_id", .string)
            .field("subscription_expires_at", .datetime)
            .field("revenuecat_app_user_id", .string)
            .field("subscription_updated_at", .datetime)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("subscription_tier")
            .deleteField("subscription_status")
            .deleteField("subscription_product_id")
            .deleteField("subscription_expires_at")
            .deleteField("revenuecat_app_user_id")
            .deleteField("subscription_updated_at")
            .update()
    }
}
