import Fluent
import SQLKit

struct AddProjectAllowedStatuses: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Store allowed statuses as array of strings
        // Default includes all statuses except testflight
        guard let sql = database as? SQLDatabase else {
            fatalError("Database must support SQL")
        }

        try await sql.raw("""
            ALTER TABLE projects
            ADD COLUMN allowed_statuses TEXT[] NOT NULL DEFAULT ARRAY['pending','approved','in_progress','completed','rejected']
            """).run()
    }

    func revert(on database: Database) async throws {
        try await database.schema("projects")
            .deleteField("allowed_statuses")
            .update()
    }
}
