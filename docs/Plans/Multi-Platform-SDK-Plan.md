# Multi-Platform SDK Technical Plan

> **Created:** 2026-02-06
> **Status:** Planning
> **Goal:** Expand FeedbackKit SDK ecosystem to JavaScript, React Native, Flutter, and Kotlin

---

## 1. Core Architecture Principles

All SDKs should share these foundational elements:

### API Contract

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/v1/feedbacks` | GET/POST | X-API-Key | List/create feedback |
| `/api/v1/feedbacks/:id` | GET | X-API-Key | Get feedback details |
| `/api/v1/feedbacks/:id/votes` | POST/DELETE | X-API-Key | Vote management |
| `/api/v1/feedbacks/:id/comments` | GET/POST | X-API-Key | Comments |
| `/api/v1/users/register` | POST | X-API-Key | Register SDK user |
| `/api/v1/events/track` | POST | X-API-Key | Event tracking |

### Shared Data Models

```
FeedbackStatus: pending | approved | in_progress | testflight | completed | rejected
FeedbackCategory: feature_request | bug_report | improvement | other
```

### Authentication Pattern

All SDKs send `X-API-Key` header + optional `X-User-Id` for vote state.

---

## 2. Platform-Specific SDKs

### A. JavaScript SDK (Web)

**Target:** Browser + Node.js environments

**Package Structure:**
```
@swiftly-feedback/js
├── src/
│   ├── client.ts          # HTTP client with fetch/axios
│   ├── models/            # TypeScript interfaces
│   ├── api/               # Endpoint wrappers
│   └── index.ts           # Exports
├── dist/
│   ├── esm/               # ES Modules
│   ├── cjs/               # CommonJS
│   └── browser/           # UMD bundle
```

**Key Features:**
- TypeScript-first with full type definitions
- Zero dependencies option (fetch-based)
- Tree-shakeable ES modules
- Browser bundle via CDN (unpkg/jsdelivr)
- Promise-based async API

**API Design:**
```typescript
const feedback = new FeedbackKit({ apiKey: 'xxx', baseUrl: '...' });

// Core operations
await feedback.list({ status: 'pending' });
await feedback.submit({ title, description, category, userId });
await feedback.vote(feedbackId, { userId });
await feedback.comment(feedbackId, { content, userId });
await feedback.trackEvent('page_view', userId, { page: '/home' });
```

**Distribution:** npm + CDN

---

### B. React Native SDK

**Target:** iOS/Android via React Native

**Package Structure:**
```
@swiftly-feedback/react-native
├── src/
│   ├── core/              # Reuse JS SDK client
│   ├── components/        # Native UI components
│   │   ├── FeedbackList.tsx
│   │   ├── FeedbackForm.tsx
│   │   ├── FeedbackDetail.tsx
│   │   └── VoteButton.tsx
│   ├── hooks/             # React hooks
│   │   ├── useFeedback.ts
│   │   ├── useVote.ts
│   │   └── useFeedbackList.ts
│   └── context/           # FeedbackProvider
```

**Key Features:**
- Extends JavaScript SDK for networking
- Native-feeling UI components (follows platform conventions)
- React hooks for state management
- AsyncStorage for caching/offline support
- Push notification integration (FCM/APNs)

**API Design:**
```tsx
<FeedbackProvider apiKey="xxx" userId={user.id}>
  <FeedbackListScreen />
</FeedbackProvider>

// Or headless
const { feedbacks, vote, isLoading } = useFeedbackList();
```

**Distribution:** npm

---

### C. Flutter SDK

**Target:** iOS/Android/Web via Flutter

**Package Structure:**
```
swiftly_feedback_flutter/
├── lib/
│   ├── src/
│   │   ├── client/        # Dio/http client
│   │   ├── models/        # Dart data classes
│   │   ├── api/           # Repository pattern
│   │   └── widgets/       # Flutter UI components
│   │       ├── feedback_list.dart
│   │       ├── feedback_form.dart
│   │       ├── feedback_detail.dart
│   │       └── vote_button.dart
│   └── swiftly_feedback.dart  # Public API
├── example/               # Example app
└── test/                  # Unit tests
```

**Key Features:**
- Dart-idiomatic API with null safety
- Material & Cupertino widget variants
- Provider/Riverpod integration examples
- Offline-first with SQLite caching
- Customizable themes matching app design

**API Design:**
```dart
final feedbackKit = FeedbackKit(apiKey: 'xxx');

// Widgets
FeedbackListView(
  client: feedbackKit,
  userId: user.id,
  onTap: (feedback) => Navigator.push(...),
)

// Or programmatic
final feedbacks = await feedbackKit.list(status: FeedbackStatus.pending);
await feedbackKit.vote(feedbackId, userId: user.id);
```

**Distribution:** pub.dev

---

### D. Kotlin SDK (Android)

**Target:** Native Android (Kotlin/Java interop)

**Package Structure:**
```
com.swiftlyfeedback:sdk
├── src/main/kotlin/com/swiftlyfeedback/
│   ├── client/            # Ktor/OkHttp client
│   ├── models/            # Data classes
│   ├── api/               # Repository + UseCases
│   ├── ui/                # Jetpack Compose components
│   │   ├── FeedbackListScreen.kt
│   │   ├── FeedbackFormScreen.kt
│   │   ├── FeedbackDetailScreen.kt
│   │   └── components/
│   └── FeedbackKit.kt     # Main entry point
```

**Key Features:**
- Kotlin Coroutines + Flow for async
- Jetpack Compose UI components
- XML Views support (legacy)
- Room for offline caching
- Firebase Cloud Messaging integration
- Java interoperability

**API Design:**
```kotlin
val feedbackKit = FeedbackKit.Builder()
    .apiKey("xxx")
    .baseUrl("...")
    .build()

// Compose
FeedbackListScreen(
    feedbackKit = feedbackKit,
    userId = user.id,
    onFeedbackClick = { navController.navigate(...) }
)

// Programmatic with coroutines
viewModelScope.launch {
    feedbackKit.feedbacks.collect { list -> ... }
    feedbackKit.vote(feedbackId, userId)
}
```

**Distribution:** Maven Central / JitPack

---

## 3. Shared Infrastructure

### OpenAPI Specification

Create an OpenAPI 3.0 spec from your Vapor server to:
- Auto-generate client code stubs
- Ensure API parity across SDKs
- Generate documentation

### Shared Test Suite

```
sdk-tests/
├── fixtures/              # Shared test data (JSON)
├── scenarios/             # Test case definitions
│   ├── feedback_crud.yaml
│   ├── voting.yaml
│   └── comments.yaml
└── runner/                # Platform-agnostic test runner
```

### CI/CD Pipeline per SDK

```yaml
# Each SDK repo
- Lint & format check
- Unit tests
- Integration tests (against staging server)
- Build artifacts
- Publish to package registry
- Update documentation
```

---

## 4. Implementation Phases

### Phase 1: Foundation (Weeks 1-2)
- [ ] Create OpenAPI spec from server
- [ ] Define shared test fixtures
- [ ] Set up monorepo or multi-repo structure
- [ ] Establish versioning strategy (semver aligned)

### Phase 2: JavaScript SDK (Weeks 3-4)
- [ ] Core HTTP client
- [ ] TypeScript models
- [ ] All API endpoints
- [ ] Unit + integration tests
- [ ] npm publish workflow
- [ ] Documentation site

### Phase 3: React Native SDK (Weeks 5-7)
- [ ] Extend JS SDK
- [ ] Build UI components
- [ ] React hooks
- [ ] Example app
- [ ] Push notification setup guide

### Phase 4: Flutter SDK (Weeks 8-10)
- [ ] Dart client implementation
- [ ] Model classes with JSON serialization
- [ ] Widget library (Material + Cupertino)
- [ ] pub.dev publishing
- [ ] Example app

### Phase 5: Kotlin SDK (Weeks 11-13)
- [ ] Ktor/OkHttp client
- [ ] Compose UI components
- [ ] Coroutines/Flow integration
- [ ] Maven Central publishing
- [ ] Sample Android app

### Phase 6: Documentation & Polish (Week 14)
- [ ] Unified documentation site
- [ ] Migration guides from Swift SDK patterns
- [ ] Video tutorials
- [ ] Community templates

---

## 5. Key Considerations

### API Parity Matrix

| Feature | Swift | JS | React Native | Flutter | Kotlin |
|---------|-------|----|--------------|---------| -------|
| List feedback | ✓ | ✓ | ✓ | ✓ | ✓ |
| Submit feedback | ✓ | ✓ | ✓ | ✓ | ✓ |
| Vote | ✓ | ✓ | ✓ | ✓ | ✓ |
| Comments | ✓ | ✓ | ✓ | ✓ | ✓ |
| User tracking | ✓ | ✓ | ✓ | ✓ | ✓ |
| Event tracking | ✓ | ✓ | ✓ | ✓ | ✓ |
| UI Components | ✓ | - | ✓ | ✓ | ✓ |
| Offline support | - | - | ✓ | ✓ | ✓ |
| Push notifications | ✓ | - | ✓ | ✓ | ✓ |

### Versioning Strategy

- All SDKs follow semver
- Major version tracks server API version (v1.x.x → API v1)
- Simultaneous releases when server API changes

### Error Handling Consistency

All SDKs should handle:
- `401` → `AuthenticationError`
- `402` → `SubscriptionLimitError`
- `403` → `ForbiddenError` (archived project)
- `404` → `NotFoundError`
- `409` → `ConflictError` (duplicate vote)

---

## 6. Repository Structure Options

### Option A: Monorepo

```
feedbackkit-sdks/
├── packages/
│   ├── javascript/
│   ├── react-native/
│   ├── flutter/
│   └── kotlin/
├── shared/
│   ├── openapi.yaml
│   └── test-fixtures/
└── docs/
```

### Option B: Multi-repo (Recommended)

```
SwiftlyFeedbackKit-JS     → npm
SwiftlyFeedbackKit-RN     → npm
swiftly_feedback_flutter  → pub.dev
SwiftlyFeedbackKit-Kotlin → Maven
```

**Recommendation:** Option B matches the existing subtree workflow, with a shared `feedbackkit-specs` repo for OpenAPI and test fixtures.

---

## 7. Server API Reference

### Request/Response DTOs

**CreateFeedbackDTO (POST /feedbacks)**
```json
{
  "title": "string",
  "description": "string",
  "category": "feature_request|bug_report|improvement|other",
  "userId": "string",
  "userEmail": "string (optional)"
}
```

**FeedbackResponseDTO**
```json
{
  "id": "uuid",
  "title": "string",
  "description": "string",
  "status": "status",
  "category": "category",
  "userId": "string",
  "userEmail": "string|null",
  "voteCount": "int",
  "hasVoted": "boolean",
  "commentCount": "int",
  "totalMrr": "double|null",
  "createdAt": "ISO8601 date",
  "updatedAt": "ISO8601 date",
  "rejectionReason": "string|null"
}
```

**CreateVoteDTO (POST /feedbacks/:id/votes)**
```json
{
  "userId": "string",
  "email": "string (optional)",
  "notifyStatusChange": "boolean (optional)"
}
```

**VoteResponseDTO**
```json
{
  "feedbackId": "uuid",
  "voteCount": "int",
  "hasVoted": "boolean"
}
```

**CreateCommentDTO (POST /feedbacks/:id/comments)**
```json
{
  "content": "string",
  "userId": "string",
  "isAdmin": "boolean (optional)"
}
```

**CommentResponseDTO**
```json
{
  "id": "uuid",
  "content": "string",
  "userId": "string",
  "isAdmin": "boolean",
  "createdAt": "ISO8601 date"
}
```

**RegisterSDKUserDTO (POST /users/register)**
```json
{
  "userId": "string",
  "mrr": "double (optional)"
}
```

**TrackViewEventDTO (POST /events/track)**
```json
{
  "eventName": "string",
  "userId": "string",
  "properties": {"key": "value"} (optional)
}
```

---

## Next Steps

1. Review and approve this plan
2. Decide on repository structure (monorepo vs multi-repo)
3. Begin Phase 1: Create OpenAPI specification
4. Prioritize which SDK to build first based on customer demand
