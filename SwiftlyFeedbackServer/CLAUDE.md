# CLAUDE.md - SwiftlyFeedbackServer

Vapor 4 backend API server with PostgreSQL database.

## Build & Run

```bash
# Build
swift build

# Run (starts on http://localhost:8080)
swift run

# Test
swift test
```

## Database Setup

```bash
# Create database (native)
createdb swiftly_feedback

# Or with Docker
docker run --name swiftly-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=swiftly_feedback -p 5432:5432 -d postgres
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_HOST` | localhost | PostgreSQL host |
| `DATABASE_PORT` | 5432 | PostgreSQL port |
| `DATABASE_USERNAME` | postgres | Database username |
| `DATABASE_PASSWORD` | postgres | Database password |
| `DATABASE_NAME` | swiftly_feedback | Database name |

## Directory Structure

```
Sources/App/
├── Controllers/          # API route handlers
│   ├── AuthController.swift
│   ├── ProjectController.swift
│   ├── FeedbackController.swift
│   ├── VoteController.swift
│   ├── CommentController.swift
│   └── SDKUserController.swift
├── Models/               # Fluent database models
│   ├── User.swift
│   ├── UserToken.swift
│   ├── Project.swift
│   ├── ProjectMember.swift
│   ├── ProjectInvite.swift
│   ├── EmailVerification.swift
│   ├── Feedback.swift
│   ├── Vote.swift
│   ├── Comment.swift
│   └── SDKUser.swift
├── Migrations/           # Database migrations
├── DTOs/                 # Data transfer objects
├── Services/             # Business logic services
├── configure.swift       # App configuration
├── routes.swift          # Route registration
└── entrypoint.swift      # Main entry point
```

## Dependencies

- **Vapor 4** - Web framework
- **Fluent** - ORM
- **FluentPostgresDriver** - PostgreSQL driver
- **JWT** - JSON Web Tokens

## API Endpoints

All routes prefixed with `/api/v1`.

### Authentication
- `POST /auth/signup` - Create account (sends verification email)
- `POST /auth/login` - Login (returns token)
- `GET /auth/me` - Get current user (requires auth)
- `POST /auth/logout` - Logout (requires auth)
- `POST /auth/verify-email` - Verify email with 8-character code
- `POST /auth/resend-verification` - Resend verification email (requires auth)
- `PUT /auth/password` - Change password (requires auth)
- `DELETE /auth/account` - Delete account (requires auth)

### Projects (Bearer token required)
- `GET /projects` - List user's projects
- `POST /projects` - Create project (returns API key)
- `GET /projects/:id` - Get project details
- `PATCH /projects/:id` - Update project (owner/admin)
- `DELETE /projects/:id` - Delete project (owner only)
- `POST /projects/:id/archive` - Archive project (owner only)
- `POST /projects/:id/unarchive` - Unarchive project (owner only)
- `POST /projects/:id/regenerate-key` - Regenerate API key (owner only)

### Project Members (Bearer token required)
- `GET /projects/:id/members` - List members
- `POST /projects/:id/members` - Add member by email (owner/admin)
- `PATCH /projects/:id/members/:memberId` - Update role (owner/admin)
- `DELETE /projects/:id/members/:memberId` - Remove member (owner/admin)

### Feedback (X-API-Key header required)
- `GET /feedbacks` - List feedback (`?status=`, `?category=` filters)
- `POST /feedbacks` - Submit feedback (blocked if archived)
- `GET /feedbacks/:id` - Get feedback details
- `PATCH /feedbacks/:id` - Update feedback (auth + project access)
- `DELETE /feedbacks/:id` - Delete feedback (auth + owner/admin)

### Votes (X-API-Key header required)
- `POST /feedbacks/:id/votes` - Vote (blocked if archived)
- `DELETE /feedbacks/:id/votes` - Remove vote (blocked if archived)

### Comments (X-API-Key header required)
- `GET /feedbacks/:id/comments` - List comments
- `POST /feedbacks/:id/comments` - Add comment (blocked if archived)
- `DELETE /feedbacks/:id/comments/:commentId` - Delete comment (blocked if archived)

### SDK Users (Bearer token required)
- `GET /users/project/:projectId` - List SDK users for a project
- `GET /users/project/:projectId/stats` - Get SDK user stats (total users, MRR totals, averages)

## Code Patterns

### Adding a New Model

1. Create model in `Models/` extending `Model` and `Content`
2. Create migration in `Migrations/`
3. Register migration in `configure.swift`
4. Create DTO in `DTOs/` if needed

### Adding a New Controller

1. Create controller in `Controllers/`
2. Implement route collection conformance
3. Register routes in `routes.swift`

### Authentication

- User authentication uses Bearer tokens via `UserToken` model
- API key authentication uses `X-API-Key` header for SDK requests
- Use `req.auth.require(User.self)` for authenticated routes
