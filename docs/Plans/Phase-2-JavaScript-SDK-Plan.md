# Phase 2: JavaScript SDK Plan

> **Timeline:** Weeks 3-4
> **Status:** Implemented
> **Depends on:** Phase 1 (Foundation)

---

## Overview

Build a TypeScript-first JavaScript SDK that works in both browser and Node.js environments. The SDK will provide a clean API for interacting with the FeedbackKit server.

---

## 1. Package Structure

```
SwiftlyFeedbackKit-JS/
├── src/
│   ├── index.ts                 # Main exports
│   ├── client.ts                # FeedbackKit client class
│   ├── api/
│   │   ├── feedback.ts          # Feedback API methods
│   │   ├── votes.ts             # Vote API methods
│   │   ├── comments.ts          # Comment API methods
│   │   ├── users.ts             # User registration
│   │   └── events.ts            # Event tracking
│   ├── models/
│   │   ├── feedback.ts          # Feedback types
│   │   ├── vote.ts              # Vote types
│   │   ├── comment.ts           # Comment types
│   │   ├── user.ts              # User types
│   │   ├── event.ts             # Event types
│   │   └── errors.ts            # Error types
│   └── utils/
│       ├── http.ts              # HTTP client wrapper
│       └── storage.ts           # User ID persistence
├── tests/
│   ├── client.test.ts
│   ├── feedback.test.ts
│   ├── votes.test.ts
│   └── mocks/
│       └── fixtures.ts          # Import from sdk-specs
├── dist/
│   ├── index.js                 # CommonJS
│   ├── index.mjs                # ES Module
│   ├── index.d.ts               # TypeScript declarations
│   └── browser.min.js           # Browser bundle (UMD)
├── package.json
├── tsconfig.json
├── rollup.config.js             # Bundle configuration
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

## 2. TypeScript Models

### Enums
```typescript
export enum FeedbackStatus {
  Pending = 'pending',
  Approved = 'approved',
  InProgress = 'in_progress',
  TestFlight = 'testflight',
  Completed = 'completed',
  Rejected = 'rejected'
}

export enum FeedbackCategory {
  FeatureRequest = 'feature_request',
  BugReport = 'bug_report',
  Improvement = 'improvement',
  Other = 'other'
}
```

### Interfaces
```typescript
export interface Feedback {
  id: string;
  title: string;
  description: string;
  status: FeedbackStatus;
  category: FeedbackCategory;
  userId: string;
  userEmail?: string | null;
  voteCount: number;
  hasVoted: boolean;
  commentCount: number;
  totalMrr?: number | null;
  createdAt: string;
  updatedAt: string;
  rejectionReason?: string | null;
  mergedIntoId?: string | null;
  mergedAt?: string | null;
  mergedFeedbackIds?: string[] | null;
}

export interface CreateFeedbackRequest {
  title: string;
  description: string;
  category: FeedbackCategory;
  userId: string;
  userEmail?: string;
}

export interface VoteRequest {
  userId: string;
  email?: string;
  notifyStatusChange?: boolean;
}

export interface VoteResponse {
  feedbackId: string;
  voteCount: number;
  hasVoted: boolean;
}

export interface Comment {
  id: string;
  content: string;
  userId: string;
  isAdmin: boolean;
  createdAt: string;
}

export interface CreateCommentRequest {
  content: string;
  userId: string;
  isAdmin?: boolean;
}

export interface SDKUser {
  id: string;
  userId: string;
  mrr?: number | null;
  firstSeenAt: string;
  lastSeenAt: string;
}

export interface TrackEventRequest {
  eventName: string;
  userId: string;
  properties?: Record<string, unknown>;
}
```

### Error Types
```typescript
export class FeedbackKitError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public code: string
  ) {
    super(message);
    this.name = 'FeedbackKitError';
  }
}

export class AuthenticationError extends FeedbackKitError {
  constructor(message = 'Invalid API key') {
    super(message, 401, 'UNAUTHORIZED');
  }
}

export class PaymentRequiredError extends FeedbackKitError {
  constructor(message = 'Subscription limit exceeded') {
    super(message, 402, 'PAYMENT_REQUIRED');
  }
}

export class ForbiddenError extends FeedbackKitError {
  constructor(message = 'Action not allowed') {
    super(message, 403, 'FORBIDDEN');
  }
}

export class NotFoundError extends FeedbackKitError {
  constructor(message = 'Resource not found') {
    super(message, 404, 'NOT_FOUND');
  }
}

export class ConflictError extends FeedbackKitError {
  constructor(message = 'Conflict') {
    super(message, 409, 'CONFLICT');
  }
}
```

---

## 3. Client API Design

```typescript
import { FeedbackKit } from '@feedbackkit/js';

// Initialize
const feedbackKit = new FeedbackKit({
  apiKey: 'sf_your_api_key',
  baseUrl: 'https://api.feedbackkit.app/api/v1', // optional
  userId: 'user_12345', // optional, for hasVoted state
});

// === Feedback ===
// List feedback
const feedbacks = await feedbackKit.feedback.list();
const pending = await feedbackKit.feedback.list({ status: 'pending' });
const bugs = await feedbackKit.feedback.list({ category: 'bug_report' });

// Get single feedback
const feedback = await feedbackKit.feedback.get('feedback-id');

// Submit feedback
const newFeedback = await feedbackKit.feedback.create({
  title: 'Add dark mode',
  description: 'Please add dark mode support.',
  category: 'feature_request',
  userId: 'user_12345',
  userEmail: 'user@example.com' // optional
});

// === Voting ===
// Vote for feedback
const voteResult = await feedbackKit.votes.vote('feedback-id', {
  userId: 'user_12345',
  email: 'user@example.com', // optional
  notifyStatusChange: true   // optional
});

// Remove vote
const unvoteResult = await feedbackKit.votes.unvote('feedback-id', {
  userId: 'user_12345'
});

// === Comments ===
// List comments
const comments = await feedbackKit.comments.list('feedback-id');

// Add comment
const comment = await feedbackKit.comments.create('feedback-id', {
  content: 'Great idea!',
  userId: 'user_12345',
  isAdmin: false
});

// === Users ===
// Register/update user
const user = await feedbackKit.users.register({
  userId: 'user_12345',
  mrr: 9.99 // optional
});

// === Events ===
// Track event
await feedbackKit.events.track({
  eventName: 'feedback_list',
  userId: 'user_12345',
  properties: { filter: 'feature_request' }
});
```

---

## 4. Implementation Tasks

### Week 3: Core Implementation

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | Set up project structure | package.json, tsconfig.json, rollup.config.js |
| 1 | Create TypeScript models | src/models/*.ts |
| 2 | Implement HTTP client | src/utils/http.ts |
| 2 | Implement error handling | src/models/errors.ts |
| 3 | Implement Feedback API | src/api/feedback.ts |
| 3 | Implement Votes API | src/api/votes.ts |
| 4 | Implement Comments API | src/api/comments.ts |
| 4 | Implement Users API | src/api/users.ts |
| 5 | Implement Events API | src/api/events.ts |
| 5 | Create main client class | src/client.ts, src/index.ts |

### Week 4: Testing & Publishing

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | Write unit tests | tests/*.test.ts |
| 2 | Write integration tests | tests/integration/*.ts |
| 2 | Set up test fixtures | Import from sdk-specs |
| 3 | Configure build outputs | ESM, CJS, UMD bundles |
| 3 | Test in browser environment | Browser bundle verification |
| 4 | Write README documentation | README.md with examples |
| 4 | Configure npm publishing | package.json, .npmrc |
| 5 | Set up GitHub Actions | CI/CD workflow |
| 5 | Publish to npm | @feedbackkit/js package |

---

## 5. Build Configuration

### package.json
```json
{
  "name": "@feedbackkit/js",
  "version": "1.0.0",
  "description": "JavaScript SDK for FeedbackKit",
  "main": "dist/index.js",
  "module": "dist/index.mjs",
  "types": "dist/index.d.ts",
  "browser": "dist/browser.min.js",
  "exports": {
    ".": {
      "import": "./dist/index.mjs",
      "require": "./dist/index.js",
      "types": "./dist/index.d.ts"
    }
  },
  "files": ["dist"],
  "scripts": {
    "build": "rollup -c",
    "test": "vitest",
    "test:coverage": "vitest --coverage",
    "lint": "eslint src",
    "typecheck": "tsc --noEmit",
    "prepublishOnly": "npm run build"
  },
  "keywords": ["feedback", "sdk", "feedbackkit"],
  "author": "Swiftly Developed",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/Swiftly-Developed/SwiftlyFeedbackKit-JS"
  },
  "devDependencies": {
    "@rollup/plugin-typescript": "^11.0.0",
    "@types/node": "^20.0.0",
    "rollup": "^4.0.0",
    "rollup-plugin-dts": "^6.0.0",
    "rollup-plugin-terser": "^7.0.0",
    "typescript": "^5.0.0",
    "vitest": "^1.0.0"
  }
}
```

### tsconfig.json
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "declaration": true,
    "declarationDir": "dist",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

---

## 6. Distribution

### npm
```bash
npm publish --access public
```

### CDN (unpkg/jsdelivr)
```html
<script src="https://unpkg.com/@feedbackkit/js@1.0.0/dist/browser.min.js"></script>
<script>
  const feedbackKit = new FeedbackKit({ apiKey: 'sf_...' });
</script>
```

---

## 7. Success Criteria

- [ ] TypeScript models match OpenAPI spec
- [ ] All API endpoints implemented
- [ ] Zero runtime dependencies
- [ ] Works in Node.js 18+
- [ ] Works in modern browsers
- [ ] Unit test coverage > 80%
- [ ] Integration tests pass against local server
- [ ] Published to npm as @feedbackkit/js
- [ ] README with usage examples
- [ ] TypeScript declarations included

---

## 8. Verification

```bash
# Build
npm run build

# Test
npm test

# Test against local server
cd ../SwiftlyFeedbackServer && swift run &
npm run test:integration

# Verify browser bundle
npx serve dist/
# Open browser and test
```

---

## Next Phase

**Phase 3: React Native SDK** will:
1. Extend this JavaScript SDK
2. Add React Native UI components
3. Add React hooks (useFeedback, useVote, etc.)
4. Support push notifications
