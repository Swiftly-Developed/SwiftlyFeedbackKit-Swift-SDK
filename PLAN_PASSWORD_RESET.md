# Password Reset Workflow & Login Field Navigation

## Overview

This plan covers two features:
1. **Password Reset Workflow** - Complete forgot password flow with email verification
2. **Field Navigation with FocusState** - Improve UX with Return key navigation in auth forms

---

## Part 1: Password Reset Workflow

### Server-Side Changes

#### 1.1 Create PasswordReset Model
**File:** `SwiftlyFeedbackServer/Sources/App/Models/PasswordReset.swift`

```swift
final class PasswordReset: Model, Content, @unchecked Sendable {
    static let schema = "password_resets"

    @ID var id: UUID?
    @Parent(key: "user_id") var user: User
    @Field(key: "token") var token: String
    @Field(key: "expires_at") var expiresAt: Date
    @OptionalField(key: "used_at") var usedAt: Date?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
}
```

- Uses same 8-character code pattern as EmailVerification
- 1-hour expiration (shorter for security)
- `used_at` prevents code reuse

#### 1.2 Create Migration
**File:** `SwiftlyFeedbackServer/Sources/App/Migrations/CreatePasswordReset.swift`

Schema: `password_resets`
- `id` (UUID, PK)
- `user_id` (UUID, FK to users, cascade delete)
- `token` (String, unique)
- `expires_at` (DateTime)
- `used_at` (DateTime, nullable)
- `created_at` (Timestamp)

Register in `configure.swift` after other migrations.

#### 1.3 Add DTOs
**File:** `SwiftlyFeedbackServer/Sources/App/DTOs/AuthDTO.swift`

Add:
```swift
struct ForgotPasswordDTO: Content, Validatable {
    let email: String

    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
    }
}

struct ResetPasswordDTO: Content, Validatable {
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case code
        case newPassword = "new_password"
    }

    static func validations(_ validations: inout Validations) {
        validations.add("code", as: String.self, is: .count(8...8))
        validations.add("new_password", as: String.self, is: .count(8...))
    }
}
```

#### 1.4 Add Email Template
**File:** `SwiftlyFeedbackServer/Sources/App/Services/EmailService.swift`

Add `sendPasswordResetEmail(to:userName:resetCode:)`:
- Similar styling to verification email
- Subject: "Reset your Swiftly Feedback password"
- Shows 8-char code prominently
- States "This code expires in 1 hour"

#### 1.5 Add Controller Routes
**File:** `SwiftlyFeedbackServer/Sources/App/Controllers/AuthController.swift`

Add two public (non-authenticated) routes:

```swift
auth.post("forgot-password", use: forgotPassword)
auth.post("reset-password", use: resetPassword)
```

**`forgotPassword`:**
1. Validate email from DTO
2. Find user by email (case-insensitive)
3. If user exists:
   - Delete any existing password reset tokens for user
   - Create new PasswordReset with 1-hour expiry
   - Send password reset email
4. Always return success message (prevents email enumeration)

**`resetPassword`:**
1. Validate code + newPassword from DTO
2. Find PasswordReset by token (uppercased)
3. Verify not expired and not used
4. Hash new password and update user
5. Mark token as used (`used_at = Date()`)
6. Delete all user tokens (force re-login on all devices)
7. Return success message

---

### Admin App Changes

#### 1.6 Add Auth Models
**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Models/AuthModels.swift`

Add:
```swift
nonisolated
struct ForgotPasswordRequest: Encodable, Sendable {
    let email: String
}

nonisolated
struct ResetPasswordRequest: Encodable, Sendable {
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case code
        case newPassword = "new_password"
    }
}
```

#### 1.7 Add AuthService Methods
**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Services/AuthService.swift`

Add:
```swift
func requestPasswordReset(email: String) async throws -> MessageResponse
func resetPassword(code: String, newPassword: String) async throws -> MessageResponse
```

Both call `AdminAPIClient.shared.post()` without bearer auth.

#### 1.8 Add AuthViewModel Properties & Methods
**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/ViewModels/AuthViewModel.swift`

Add properties:
```swift
var resetEmail = ""
var resetCode = ""
var resetNewPassword = ""
var resetConfirmPassword = ""
var resetEmailSent = false
```

Add methods:
```swift
func requestPasswordReset() async { ... }
func resetPassword() async -> Bool { ... }
func clearResetState() { ... }
```

#### 1.9 Create ForgotPasswordView
**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Auth/ForgotPasswordView.swift`

Two-stage view:

**Stage 1 - Request Reset:**
- Email text field
- "Send Reset Code" button
- Back to login link

**Stage 2 - Enter Code & New Password:**
- 8-character code field (monospaced, centered)
- New password field (8+ chars)
- Confirm password field
- "Reset Password" button
- Password requirements display (like ChangePasswordView)
- "Resend Code" button with 60-second cooldown

Use `@FocusState` for field navigation (see Part 2).

#### 1.10 Update LoginView
**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Auth/LoginView.swift`

Add "Forgot Password?" link below password field, above Log In button:
```swift
Button("Forgot Password?") {
    onForgotPassword()
}
.font(.subheadline)
```

#### 1.11 Update AuthContainerView
**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Auth/AuthContainerView.swift`

Add state and navigation for forgot password flow:
```swift
enum AuthMode { case login, signup, forgotPassword }
@State private var authMode: AuthMode = .login
```

Handle transitions between login/signup/forgotPassword views.

---

## Part 2: Field Navigation with FocusState

### 2.1 Update LoginView
**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Auth/LoginView.swift`

```swift
enum LoginField: Hashable {
    case email, password
}

@FocusState private var focusedField: LoginField?

// Email field
TextField("Email", text: $viewModel.loginEmail)
    .focused($focusedField, equals: .email)
    .onSubmit { focusedField = .password }
    .submitLabel(.next)

// Password field
SecureField("Password", text: $viewModel.loginPassword)
    .focused($focusedField, equals: .password)
    .onSubmit { Task { await viewModel.login() } }
    .submitLabel(.go)

// Auto-focus email on appear
.onAppear { focusedField = .email }
```

### 2.2 Update SignupView
**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Auth/SignupView.swift`

```swift
enum SignupField: Hashable {
    case name, email, password, confirmPassword
}

@FocusState private var focusedField: SignupField?

// Name -> Email -> Password -> Confirm Password -> Submit
// Each field uses .onSubmit to advance focus
// Last field submits the form
.submitLabel(.next) // for first 3 fields
.submitLabel(.go)   // for confirm password
```

### 2.3 Update ForgotPasswordView (new file)
Apply same pattern:
- Stage 1: Email field -> Submit
- Stage 2: Code -> New Password -> Confirm Password -> Submit

### 2.4 Update EmailVerificationView
**File:** `SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Auth/EmailVerificationView.swift`

```swift
@FocusState private var isCodeFieldFocused: Bool

// Auto-focus on appear
.onAppear { isCodeFieldFocused = true }

// Submit on Return when code is 8 chars
.onSubmit {
    if viewModel.verificationCode.count == 8 {
        Task { await viewModel.verifyEmail() }
    }
}
.submitLabel(.go)
```

---

## Files to Modify/Create

### Server (SwiftlyFeedbackServer)
| Action | File |
|--------|------|
| Create | `Sources/App/Models/PasswordReset.swift` |
| Create | `Sources/App/Migrations/CreatePasswordReset.swift` |
| Modify | `Sources/App/DTOs/AuthDTO.swift` |
| Modify | `Sources/App/Services/EmailService.swift` |
| Modify | `Sources/App/Controllers/AuthController.swift` |
| Modify | `Sources/App/configure.swift` |

### Admin App (SwiftlyFeedbackAdmin)
| Action | File |
|--------|------|
| Create | `Views/Auth/ForgotPasswordView.swift` |
| Modify | `Models/AuthModels.swift` |
| Modify | `Services/AuthService.swift` |
| Modify | `ViewModels/AuthViewModel.swift` |
| Modify | `Views/Auth/LoginView.swift` |
| Modify | `Views/Auth/SignupView.swift` |
| Modify | `Views/Auth/AuthContainerView.swift` |
| Modify | `Views/Auth/EmailVerificationView.swift` |

---

## Security Considerations

1. **Email enumeration prevention**: Always return success for forgot-password requests
2. **Short token expiry**: 1 hour (vs 24 hours for email verification)
3. **Single-use tokens**: Mark as used after successful reset
4. **Force re-login**: Delete all user tokens after password reset
5. **Rate limiting**: Consider adding cooldown for forgot-password requests (future enhancement)

---

## Implementation Order

1. Server: Model + Migration + DTOs
2. Server: EmailService template
3. Server: AuthController routes
4. Admin: Models + AuthService methods
5. Admin: AuthViewModel properties/methods
6. Admin: ForgotPasswordView (new)
7. Admin: Update AuthContainerView navigation
8. Admin: Update LoginView with forgot password link
9. Admin: Add FocusState to LoginView
10. Admin: Add FocusState to SignupView
11. Admin: Add FocusState to EmailVerificationView
12. Test complete flow
