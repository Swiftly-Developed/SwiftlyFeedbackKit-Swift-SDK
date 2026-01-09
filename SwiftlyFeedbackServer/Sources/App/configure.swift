import Vapor
import Fluent
import FluentPostgresDriver

func configure(_ app: Application) async throws {
    // Configure JSON encoding/decoding to use snake_case
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    // Database configuration - PostgreSQL
    // Try to use DATABASE_URL first (Heroku standard), then fall back to individual vars
    if let databaseURL = Environment.get("DATABASE_URL") {
        // Parse DATABASE_URL (format: postgres://username:password@hostname:port/database)
        guard let url = URL(string: databaseURL),
              let host = url.host,
              let user = url.user,
              let pass = url.password,
              let port = url.port else {
            fatalError("Invalid DATABASE_URL format")
        }
        let dbName = String(url.path.dropFirst()) // Remove leading "/"

        // Use URL-based configuration (simpler and handles TLS automatically)
        try app.databases.use(.postgres(url: databaseURL), as: .psql)
        app.logger.info("Using DATABASE_URL: \(host):\(port)/\(dbName)")
    } else {
        // Fall back to individual environment variables (for local development)
        let hostname = Environment.get("DATABASE_HOST") ?? "localhost"
        let port = Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5432
        let username = Environment.get("DATABASE_USERNAME") ?? "postgres"
        let password = Environment.get("DATABASE_PASSWORD") ?? "postgres"
        let database = Environment.get("DATABASE_NAME") ?? "swiftly_feedback"

        let config = SQLPostgresConfiguration(
            hostname: hostname,
            port: port,
            username: username,
            password: password,
            database: database,
            tls: .disable
        )
        app.databases.use(.postgres(configuration: config), as: .psql)
        app.logger.info("Using individual DB vars: \(hostname):\(port)/\(database)")
    }

    // Migrations - order matters!
    app.migrations.add(CreateUser())
    app.migrations.add(CreateUserToken())
    app.migrations.add(CreateProject())
    app.migrations.add(CreateProjectMember())
    app.migrations.add(CreateFeedback())
    app.migrations.add(CreateVote())
    app.migrations.add(CreateComment())
    app.migrations.add(CreateProjectInvite())
    app.migrations.add(AddUserEmailVerified())
    app.migrations.add(CreateEmailVerification())
    app.migrations.add(CreateSDKUser())
    app.migrations.add(CreateViewEvent())
    app.migrations.add(AddProjectColorIndex())
    app.migrations.add(AddUserNotificationSettings())
    app.migrations.add(AddProjectSlackWebhook())
    app.migrations.add(AddFeedbackMergeFields())
    app.migrations.add(AddProjectAllowedStatuses())
    app.migrations.add(AddProjectGitHubIntegration())
    app.migrations.add(AddProjectClickUpIntegration())
    app.migrations.add(AddProjectNotionIntegration())
    app.migrations.add(AddProjectMondayIntegration())
    app.migrations.add(AddProjectLinearIntegration())
    app.migrations.add(AddIntegrationActiveToggles())
    app.migrations.add(CreatePasswordReset())

    try await app.autoMigrate()

    // CORS middleware
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

    // Routes
    try routes(app)
}
