# Phase 3: React Native SDK Plan

> **Timeline:** Weeks 5-7
> **Status:** Implemented
> **Depends on:** Phase 2 (JavaScript SDK)
> **Repository:** `/Users/paulvelasquez/Desktop/Feedback/SwiftlyFeedbackKit-RN/`

---

## Overview

Build a React Native SDK that extends the JavaScript SDK with:
1. **React Hooks** - useFeedback, useVote, useFeedbackList, etc.
2. **React Native UI Components** - FeedbackList, FeedbackForm, FeedbackDetail
3. **Context Provider** - FeedbackProvider for app-wide configuration
4. **AsyncStorage** - Persistent user ID and caching

---

## 1. Package Structure

```
SwiftlyFeedbackKit-RN/
├── src/
│   ├── index.ts                    # Main exports
│   ├── provider.tsx                # FeedbackProvider context
│   ├── hooks/
│   │   ├── useFeedbackKit.ts       # Access client from context
│   │   ├── useFeedbackList.ts      # List with loading/error state
│   │   ├── useFeedback.ts          # Single feedback
│   │   ├── useVote.ts              # Vote mutation
│   │   ├── useComments.ts          # Comments list
│   │   └── useSubmitFeedback.ts    # Submit mutation
│   ├── components/
│   │   ├── FeedbackList.tsx        # Scrollable feedback list
│   │   ├── FeedbackCard.tsx        # Single feedback card
│   │   ├── FeedbackDetail.tsx      # Full feedback view
│   │   ├── FeedbackForm.tsx        # Submit feedback form
│   │   ├── VoteButton.tsx          # Vote/unvote button
│   │   ├── CommentList.tsx         # Comments display
│   │   ├── CommentInput.tsx        # Add comment input
│   │   ├── StatusBadge.tsx         # Status pill
│   │   └── CategoryBadge.tsx       # Category pill
│   ├── styles/
│   │   ├── theme.ts                # Default theme
│   │   └── colors.ts               # Status/category colors
│   └── utils/
│       └── storage.ts              # AsyncStorage wrapper
├── package.json
├── tsconfig.json
├── README.md
└── LICENSE
```

---

## 2. React Hooks API

### useFeedbackList
```typescript
const {
  feedbacks,      // Feedback[]
  isLoading,      // boolean
  error,          // Error | null
  refetch,        // () => Promise<void>
  filter,         // { status?, category? }
  setFilter       // (filter) => void
} = useFeedbackList();
```

### useFeedback
```typescript
const {
  feedback,       // Feedback | null
  isLoading,
  error,
  refetch
} = useFeedback(feedbackId);
```

### useVote
```typescript
const {
  vote,           // (feedbackId) => Promise<VoteResponse>
  unvote,         // (feedbackId) => Promise<VoteResponse>
  isVoting        // boolean
} = useVote();
```

### useSubmitFeedback
```typescript
const {
  submit,         // (data) => Promise<Feedback>
  isSubmitting,
  error
} = useSubmitFeedback();
```

### useComments
```typescript
const {
  comments,       // Comment[]
  isLoading,
  addComment,     // (content) => Promise<Comment>
  isAdding
} = useComments(feedbackId);
```

---

## 3. UI Components

### FeedbackList
```tsx
<FeedbackList
  onFeedbackPress={(feedback) => navigation.navigate('Detail', { id: feedback.id })}
  filterByStatus={FeedbackStatus.Approved}
  filterByCategory={FeedbackCategory.FeatureRequest}
  showAddButton={true}
  onAddPress={() => navigation.navigate('Submit')}
  emptyComponent={<CustomEmptyView />}
  ListHeaderComponent={<Header />}
/>
```

### FeedbackForm
```tsx
<FeedbackForm
  userId="user_123"
  userEmail="user@example.com"
  onSuccess={(feedback) => navigation.goBack()}
  onCancel={() => navigation.goBack()}
  showEmailField={true}
  defaultCategory={FeedbackCategory.FeatureRequest}
/>
```

### FeedbackDetail
```tsx
<FeedbackDetail
  feedbackId="550e8400-..."
  userId="user_123"
  showComments={true}
  showVoteButton={true}
  onVoteChange={(hasVoted, voteCount) => {}}
/>
```

---

## 4. Context Provider

```tsx
import { FeedbackProvider } from '@feedbackkit/react-native';

export default function App() {
  return (
    <FeedbackProvider
      apiKey="sf_your_api_key"
      userId={user?.id}
      theme={{
        primaryColor: '#007AFF',
        statusColors: {
          pending: '#8E8E93',
          approved: '#007AFF',
          inProgress: '#FF9500',
          completed: '#34C759',
          rejected: '#FF3B30'
        }
      }}
    >
      <NavigationContainer>
        {/* Your app */}
      </NavigationContainer>
    </FeedbackProvider>
  );
}
```

---

## 5. Implementation Tasks

### Week 5: Core Hooks

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | Set up project, add JS SDK dependency | package.json, tsconfig |
| 1 | Create FeedbackProvider context | src/provider.tsx |
| 2 | Implement useFeedbackKit hook | src/hooks/useFeedbackKit.ts |
| 2 | Implement useFeedbackList hook | src/hooks/useFeedbackList.ts |
| 3 | Implement useFeedback hook | src/hooks/useFeedback.ts |
| 3 | Implement useVote hook | src/hooks/useVote.ts |
| 4 | Implement useComments hook | src/hooks/useComments.ts |
| 4 | Implement useSubmitFeedback hook | src/hooks/useSubmitFeedback.ts |
| 5 | Add AsyncStorage for user ID | src/utils/storage.ts |

### Week 6: UI Components

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | Create theme and colors | src/styles/*.ts |
| 1 | Create StatusBadge, CategoryBadge | src/components/*Badge.tsx |
| 2 | Create VoteButton component | src/components/VoteButton.tsx |
| 2 | Create FeedbackCard component | src/components/FeedbackCard.tsx |
| 3 | Create FeedbackList component | src/components/FeedbackList.tsx |
| 4 | Create FeedbackDetail component | src/components/FeedbackDetail.tsx |
| 5 | Create FeedbackForm component | src/components/FeedbackForm.tsx |

### Week 7: Polish & Publish

| Day | Task | Deliverable |
|-----|------|-------------|
| 1 | Create CommentList, CommentInput | src/components/Comment*.tsx |
| 2 | Write unit tests for hooks | tests/hooks/*.test.ts |
| 3 | Write component tests | tests/components/*.test.tsx |
| 4 | Write README documentation | README.md |
| 5 | Publish to npm | @feedbackkit/react-native |

---

## 6. Dependencies

```json
{
  "peerDependencies": {
    "react": ">=18.0.0",
    "react-native": ">=0.72.0",
    "@react-native-async-storage/async-storage": ">=1.19.0"
  },
  "dependencies": {
    "@feedbackkit/js": "^1.0.0"
  }
}
```

---

## 7. Success Criteria

- [x] All hooks implemented and tested
- [x] UI components match platform conventions (core components done)
- [x] Works on iOS and Android (React Native cross-platform)
- [x] Supports light/dark mode (defaultTheme + darkTheme)
- [x] TypeScript declarations included
- [ ] Published to npm as @feedbackkit/react-native (pending npm account setup)
- [x] README with usage examples

### Implemented Components
- FeedbackKitProvider (context with theme)
- useFeedbackKit, useFeedbackList, useFeedback, useVote, useComments, useSubmitFeedback
- StatusBadge, CategoryBadge, VoteButton, FeedbackCard, FeedbackList
- AsyncStorage for user ID persistence
- Jest test setup with mocks

### Future Enhancements (Optional)
- FeedbackDetail (full view with comments)
- FeedbackForm (submit feedback form)
- CommentList, CommentInput components
- Offline caching support

---

## Next Phase

**Phase 4: Flutter SDK** will:
1. Implement Dart client from OpenAPI spec
2. Create Flutter widgets (Material + Cupertino)
3. Support offline caching with SQLite
