# Phase 1: Foundation Plan

> **Timeline:** Weeks 1-2
> **Status:** Implemented
> **Prerequisite for:** All other SDK phases

---

## Overview

Phase 1 establishes the foundational infrastructure that all platform SDKs will share:
1. **OpenAPI Specification** - Document all SDK-facing API endpoints
2. **Shared Test Fixtures** - Standardized test data for all SDKs
3. **Repository Structure** - Set up the multi-repo organization
4. **Versioning Strategy** - Establish semver conventions

---

## 1. OpenAPI Specification

### Goal
Create a comprehensive OpenAPI 3.0 specification documenting all SDK-facing API endpoints.

### File Location
```
feedbackkit-sdk-specs/       # New shared repository
└── openapi/
    └── openapi.yaml
```

### Endpoints to Document

#### Feedback (`X-API-Key` Auth)
| Method | Path | Request DTO | Response DTO |
|--------|------|-------------|--------------|
| GET | `/api/v1/feedbacks` | Query: `status`, `category` | `[FeedbackResponseDTO]` |
| POST | `/api/v1/feedbacks` | `CreateFeedbackDTO` | `FeedbackResponseDTO` |
| GET | `/api/v1/feedbacks/{id}` | - | `FeedbackResponseDTO` |

#### Votes (`X-API-Key` Auth)
| Method | Path | Request DTO | Response DTO |
|--------|------|-------------|--------------|
| POST | `/api/v1/feedbacks/{id}/votes` | `CreateVoteDTO` | `VoteResponseDTO` |
| DELETE | `/api/v1/feedbacks/{id}/votes` | `DeleteVoteDTO` | `VoteResponseDTO` |

#### Comments (`X-API-Key` Auth)
| Method | Path | Request DTO | Response DTO |
|--------|------|-------------|--------------|
| GET | `/api/v1/feedbacks/{id}/comments` | - | `[CommentResponseDTO]` |
| POST | `/api/v1/feedbacks/{id}/comments` | `CreateCommentDTO` | `CommentResponseDTO` |

#### SDK Users (`X-API-Key` Auth)
| Method | Path | Request DTO | Response DTO |
|--------|------|-------------|--------------|
| POST | `/api/v1/users/register` | `RegisterSDKUserDTO` | `SDKUserResponseDTO` |

#### Events (`X-API-Key` Auth)
| Method | Path | Request DTO | Response DTO |
|--------|------|-------------|--------------|
| POST | `/api/v1/events/track` | `TrackViewEventDTO` | `ViewEventResponseDTO` |

### Schema Definitions

#### Enums
```yaml
FeedbackStatus:
  type: string
  enum: [pending, approved, in_progress, testflight, completed, rejected]

FeedbackCategory:
  type: string
  enum: [feature_request, bug_report, improvement, other]
```

#### Request DTOs
```yaml
CreateFeedbackDTO:
  required: [title, description, category, userId]
  properties:
    title: string
    description: string
    category: FeedbackCategory
    userId: string
    userEmail: string (optional)

CreateVoteDTO:
  required: [userId]
  properties:
    userId: string
    email: string (optional)
    notifyStatusChange: boolean (default: false)

CreateCommentDTO:
  required: [content, userId]
  properties:
    content: string
    userId: string
    isAdmin: boolean (default: false)

RegisterSDKUserDTO:
  required: [userId]
  properties:
    userId: string
    mrr: number (optional)

TrackViewEventDTO:
  required: [eventName, userId]
  properties:
    eventName: string
    userId: string
    properties: object (optional)
```

#### Response DTOs
```yaml
FeedbackResponseDTO:
  properties:
    id: uuid
    title: string
    description: string
    status: FeedbackStatus
    category: FeedbackCategory
    userId: string
    userEmail: string | null
    voteCount: integer
    hasVoted: boolean
    commentCount: integer
    totalMrr: number | null
    createdAt: date-time
    updatedAt: date-time
    rejectionReason: string | null
    mergedIntoId: uuid | null
    mergedAt: date-time | null
    mergedFeedbackIds: uuid[] | null

VoteResponseDTO:
  properties:
    feedbackId: uuid
    voteCount: integer
    hasVoted: boolean

CommentResponseDTO:
  properties:
    id: uuid
    content: string
    userId: string
    isAdmin: boolean
    createdAt: date-time

SDKUserResponseDTO:
  properties:
    id: uuid
    userId: string
    mrr: number | null
    firstSeenAt: date-time
    lastSeenAt: date-time

ViewEventResponseDTO:
  properties:
    id: uuid
    eventName: string
    userId: string
    properties: object | null
    createdAt: date-time
```

### Error Responses
| Status | Description |
|--------|-------------|
| 400 | Bad Request - Validation errors |
| 401 | Unauthorized - Missing/invalid API key |
| 402 | Payment Required - Tier limit exceeded |
| 403 | Forbidden - Archived project |
| 404 | Not Found |
| 409 | Conflict - Duplicate vote |

### Authentication
```yaml
securitySchemes:
  ApiKeyAuth:
    type: apiKey
    in: header
    name: X-API-Key

  UserIdHeader:
    type: apiKey
    in: header
    name: X-User-Id  # Optional, for hasVoted state
```

### Tasks
- [ ] Create `openapi/openapi.yaml` with info, servers, security
- [ ] Define all component schemas
- [ ] Define all path operations with examples
- [ ] Validate with `swagger-cli validate`
- [ ] Generate HTML docs with `redoc-cli`

---

## 2. Shared Test Fixtures

### Goal
Create standardized test data that all SDKs can use for consistent testing.

### File Location
```
feedbackkit-sdk-specs/
├── fixtures/
│   ├── feedback/
│   │   ├── create-feedback.json
│   │   ├── feedback-response.json
│   │   └── feedback-list.json
│   ├── votes/
│   │   ├── create-vote.json
│   │   └── vote-response.json
│   ├── comments/
│   │   ├── create-comment.json
│   │   └── comment-response.json
│   ├── users/
│   │   └── register-user.json
│   └── events/
│       └── track-event.json
└── scenarios/
    ├── feedback-crud.yaml
    ├── voting-flow.yaml
    └── error-handling.yaml
```

### Fixture Format Example
```json
{
  "valid": {
    "basic": {
      "title": "Add dark mode support",
      "description": "It would be great to have dark mode.",
      "category": "feature_request",
      "userId": "user_12345"
    },
    "with_email": {
      "title": "Bug in login",
      "description": "App crashes on invalid email.",
      "category": "bug_report",
      "userId": "user_67890",
      "userEmail": "test@example.com"
    }
  },
  "invalid": {
    "missing_title": { ... },
    "empty_description": { ... }
  }
}
```

### Tasks
- [ ] Create `feedbackkit-sdk-specs` repository
- [ ] Define fixture JSON files for all endpoints
- [ ] Create test scenario YAML definitions
- [ ] Document fixture usage in README

---

## 3. Repository Structure

### Decision: Multi-Repo

```
GitHub: Swiftly-Developed/
├── feedbackkit-sdk-specs        # Shared specs & fixtures (NEW)
├── SwiftlyFeedbackKit           # Swift SDK (existing)
├── SwiftlyFeedbackKit-JS        # JavaScript SDK (NEW - Phase 2)
├── SwiftlyFeedbackKit-RN        # React Native SDK (NEW - Phase 3)
├── swiftly-feedback-flutter     # Flutter SDK (NEW - Phase 4)
└── SwiftlyFeedbackKit-Kotlin    # Kotlin SDK (NEW - Phase 5)
```

### Specs Repository Structure
```
feedbackkit-sdk-specs/
├── README.md
├── LICENSE
├── openapi/
│   └── openapi.yaml
├── fixtures/
│   └── ... (test data)
├── scenarios/
│   └── ... (test scenarios)
├── scripts/
│   ├── validate-spec.sh
│   └── generate-docs.sh
└── .github/
    └── workflows/
        └── validate.yml
```

### Tasks
- [ ] Create `feedbackkit-sdk-specs` repository on GitHub
- [ ] Set up folder structure
- [ ] Add OpenAPI spec
- [ ] Add test fixtures
- [ ] Configure GitHub Actions for validation

---

## 4. Versioning Strategy

### Semantic Versioning
```
MAJOR.MINOR.PATCH

MAJOR: Breaking API changes
MINOR: New features (backward-compatible)
PATCH: Bug fixes
```

### Version Alignment
| Component | Version |
|-----------|---------|
| Server API | v1 |
| OpenAPI Spec | 1.x.x |
| All SDKs | 1.x.x |

### Rules
1. **Major version tracks API version** - SDK v1.x.x → API v1
2. **Coordinated releases for API changes** - Update spec → Update SDKs
3. **Independent patch releases** - Bug fixes per-SDK

### Changelog Format
```markdown
## [1.1.0] - 2026-02-15
### Added
- Vote notification opt-in

### Fixed
- Race condition in voting
```

### Tasks
- [ ] Document versioning in specs repo README
- [ ] Create CHANGELOG template
- [ ] Set up tag protection on GitHub

---

## 5. Implementation Schedule

### Week 1
| Day | Task |
|-----|------|
| 1 | Create `feedbackkit-sdk-specs` repo |
| 1-2 | Write OpenAPI spec skeleton |
| 2-3 | Define all schemas |
| 3-4 | Define all path operations |
| 5 | Create test fixtures |

### Week 2
| Day | Task |
|-----|------|
| 1 | Create test scenarios |
| 2 | Set up CI/CD for spec validation |
| 3 | Generate HTML documentation |
| 4 | Document versioning strategy |
| 5 | Final review |

---

## 6. Verification

```bash
# Validate OpenAPI spec
npm install -g @apidevtools/swagger-cli
swagger-cli validate openapi/openapi.yaml

# Generate documentation
npm install -g redoc-cli
redoc-cli bundle openapi/openapi.yaml -o docs/api.html

# Test against local server
cd SwiftlyFeedbackServer && swift run
# Import openapi.yaml into Postman and run collection
```

---

## 7. Success Criteria

- [ ] OpenAPI 3.0 spec covers all SDK endpoints
- [ ] Spec validates without errors
- [ ] Test fixtures exist for all DTOs
- [ ] `feedbackkit-sdk-specs` repository is created
- [ ] Versioning strategy documented
- [ ] API documentation generated

---

## Next Phase

**Phase 2: JavaScript SDK** will:
1. Use OpenAPI spec to generate TypeScript types
2. Implement HTTP client
3. Use test fixtures for testing
4. Follow established versioning
