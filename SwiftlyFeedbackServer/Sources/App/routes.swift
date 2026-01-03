import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        "SwiftlyFeedback API Server"
    }

    app.get("health") { req in
        ["status": "ok"]
    }

    // API v1 routes
    let api = app.grouped("api", "v1")

    // Auth routes (signup, login, etc.)
    try api.register(collection: AuthController())

    // Project management routes (requires authentication)
    try api.register(collection: ProjectController())

    // Feedback routes (public API with API key + admin routes with auth)
    try api.register(collection: FeedbackController())
    try api.register(collection: VoteController())
    try api.register(collection: CommentController())

    // SDK User routes (for MRR tracking)
    try api.register(collection: SDKUserController())

    // View event tracking routes
    try api.register(collection: ViewEventController())

    // Dashboard routes (home KPIs)
    try api.register(collection: DashboardController())
}
