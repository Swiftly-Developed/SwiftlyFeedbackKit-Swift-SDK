# CLAUDE.md - Feedback Kit Server

Vapor 4 backend API server with PostgreSQL.

## Build & Run

```bash
swift build
swift run          # http://localhost:8080
swift test
```

## Database

```bash
# Docker
docker run --name swiftly-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=swiftly_feedback -p 5432:5432 -d postgres
```

**Environment:** `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`, `DATABASE_NAME`

## Directory Structure

```
Sources/App/
├── Controllers/     # Auth, Project, Feedback, Vote, Comment, SDKUser, ViewEvent, Dashboard
├── Models/          # User, UserToken, Project, ProjectMember, ProjectInvite, EmailVerification,
│                    # PasswordReset, Feedback, Vote, Comment, SDKUser, ViewEvent
├── Migrations/
├── DTOs/
├── Services/        # Email, Slack, GitHub, ClickUp, Notion, Monday, Linear
├── configure.swift, routes.swift, entrypoint.swift
```

## API Endpoints (prefix: `/api/v1`)

### Authentication
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /auth/signup | - | Create account |
| POST | /auth/login | - | Login (returns token) |
| GET | /auth/me | Bearer | Current user |
| POST | /auth/logout | Bearer | Logout |
| POST | /auth/verify-email | - | Verify with 8-char code |
| POST | /auth/resend-verification | Bearer | Resend code |
| PUT | /auth/password | Bearer | Change password |
| DELETE | /auth/account | Bearer | Delete account |
| POST | /auth/forgot-password | - | Request reset email |
| POST | /auth/reset-password | - | Reset with code |

### Projects (Bearer auth)
| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | /projects | - | List user's projects |
| POST | /projects | - | Create project |
| GET | /projects/:id | - | Get details |
| PATCH | /projects/:id | Owner/Admin | Update |
| DELETE | /projects/:id | Owner | Delete |
| POST | /projects/:id/archive | Owner | Archive |
| POST | /projects/:id/unarchive | Owner | Unarchive |
| POST | /projects/:id/regenerate-key | Owner | New API key |
| PATCH | /projects/:id/statuses | Owner/Admin | Update allowed statuses |

### Project Members (Bearer auth)
| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | /projects/:id/members | - | List |
| POST | /projects/:id/members | Owner/Admin | Add by email |
| PATCH | /projects/:id/members/:memberId | Owner/Admin | Update role |
| DELETE | /projects/:id/members/:memberId | Owner/Admin | Remove |

### Feedback (X-API-Key auth)
| Method | Path | Description |
|--------|------|-------------|
| GET | /feedbacks | List (?status=, ?category=) |
| POST | /feedbacks | Submit (blocked if archived) |
| GET | /feedbacks/:id | Details |
| PATCH | /feedbacks/:id | Update (Bearer + access) |
| DELETE | /feedbacks/:id | Delete (Bearer + Owner/Admin) |
| POST | /feedbacks/merge | Merge items (Bearer + Owner/Admin) |

### Votes (X-API-Key auth)
| Method | Path | Description |
|--------|------|-------------|
| POST | /feedbacks/:id/votes | Vote (blocked if archived/completed/rejected) |
| DELETE | /feedbacks/:id/votes | Remove vote |

### Comments (X-API-Key auth)
| Method | Path | Description |
|--------|------|-------------|
| GET | /feedbacks/:id/comments | List |
| POST | /feedbacks/:id/comments | Add (blocked if archived) |
| DELETE | /feedbacks/:id/comments/:commentId | Delete |

### SDK Users (Bearer auth)
| Method | Path | Description |
|--------|------|-------------|
| GET | /users/project/:projectId | List for project |
| GET | /users/project/:projectId/stats | Stats (total, MRR) |
| GET | /users/all | List across all projects |
| GET | /users/all/stats | Aggregated stats |

### Events
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /events/track | X-API-Key | Track event |
| GET | /events/project/:projectId | Bearer | Recent events |
| GET | /events/project/:projectId/stats | Bearer | Stats (?days=N, max 365) |
| GET | /events/all/stats | Bearer | Aggregated stats |

### Dashboard (Bearer auth)
| Method | Path | Description |
|--------|------|-------------|
| GET | /dashboard/home | KPIs across all projects |

## Integrations

All integrations follow the same pattern:

**Settings:** `PATCH /projects/:id/{integration}` (Bearer, Owner/Admin)
**Single create:** `POST /projects/:id/{integration}/{item}`
**Bulk create:** `POST /projects/:id/{integration}/{items}`
**Discovery endpoints:** For pickers (teams, boards, databases, etc.)

### Slack
- `PATCH /projects/:id/slack` - webhook URL + notification toggles

### GitHub
- `PATCH /projects/:id/github` - owner, repo, token, labels, sync_status
- `POST /projects/:id/github/issue` - Create issue
- `POST /projects/:id/github/issues` - Bulk create

### ClickUp
- `PATCH /projects/:id/clickup` - token, list_id, tags, sync_status/comments, votes_field_id
- `POST /projects/:id/clickup/task[s]` - Create task(s)
- `GET /projects/:id/clickup/workspaces|spaces|folders|lists|custom-fields` - Hierarchy picker

### Notion
- `PATCH /projects/:id/notion` - token, database_id, sync_status/comments, status/votes properties
- `POST /projects/:id/notion/page[s]` - Create page(s)
- `GET /projects/:id/notion/databases` - Database picker
- `GET /projects/:id/notion/database/:id/properties` - Schema

### Monday.com
- `PATCH /projects/:id/monday` - token, board_id, group_id, sync_status/comments, column IDs
- `POST /projects/:id/monday/item[s]` - Create item(s)
- `GET /projects/:id/monday/boards` - Board picker
- `GET /projects/:id/monday/boards/:id/groups|columns` - Board details

### Linear
- `PATCH /projects/:id/linear` - token, team_id, project_id, label_ids, sync_status/comments
- `POST /projects/:id/linear/issue[s]` - Create issue(s)
- `GET /projects/:id/linear/teams|projects|states|labels` - Team picker

## Status Sync Mapping

All integrations map feedback status similarly:
- pending → backlog/to do
- approved → approved/unstarted
- in_progress → in progress/started
- testflight → in review/started
- completed → complete/done
- rejected → closed/canceled

## Code Patterns

**New Model:** Create in Models/, add migration, register in configure.swift, add DTO if needed.

**New Controller:** Create in Controllers/, implement RouteCollection, register in routes.swift.

**Auth:**
- Bearer tokens via `UserToken` model
- API key via `X-API-Key` header
- `req.auth.require(User.self)` for authenticated routes

## Password Reset

`PasswordReset` model: 8-char token, 1-hour expiry, single-use, invalidates all sessions.

## Feedback Merging

`POST /feedbacks/merge`: Moves votes (de-duplicated), migrates comments with prefix, recalculates MRR, soft-deletes secondary items.

Fields: `merged_into_id`, `merged_at`, `merged_feedback_ids`
