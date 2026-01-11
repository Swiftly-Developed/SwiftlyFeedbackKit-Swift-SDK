import Vapor
import Fluent

struct AuthController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")

        auth.post("signup", use: signup)
        auth.post("login", use: login)
        auth.post("verify-email", use: verifyEmail)
        auth.post("forgot-password", use: forgotPassword)
        auth.post("reset-password", use: resetPassword)

        // Protected routes
        let tokenProtected = auth.grouped(UserToken.authenticator())
        tokenProtected.get("me", use: me)
        tokenProtected.post("logout", use: logout)
        tokenProtected.put("password", use: changePassword)
        tokenProtected.delete("account", use: deleteAccount)
        tokenProtected.post("resend-verification", use: resendVerification)
        tokenProtected.patch("notifications", use: updateNotificationSettings)

        // Subscription routes
        tokenProtected.get("subscription", use: getSubscription)
        tokenProtected.post("subscription", "sync", use: syncSubscription)
        tokenProtected.patch("subscription", "tier", use: overrideSubscriptionTier)
    }

    @Sendable
    func signup(req: Request) async throws -> AuthResponseDTO {
        try SignupDTO.validate(content: req)
        let dto = try req.content.decode(SignupDTO.self)

        // Check if email already exists
        let existingUser = try await User.query(on: req.db)
            .filter(\.$email == dto.email.lowercased())
            .first()

        if existingUser != nil {
            throw Abort(.conflict, reason: "A user with this email already exists")
        }

        // Create user
        let passwordHash = try Bcrypt.hash(dto.password)
        let user = User(
            email: dto.email.lowercased(),
            name: dto.name,
            passwordHash: passwordHash
        )

        try await user.save(on: req.db)

        // Create email verification
        let verification = EmailVerification(userId: try user.requireID())
        try await verification.save(on: req.db)

        // Send verification email
        try await req.emailService.sendEmailVerification(
            to: user.email,
            userName: user.name,
            verificationCode: verification.token
        )

        // Generate token
        let token = try user.generateToken()
        try await token.save(on: req.db)

        return AuthResponseDTO(
            token: token.value,
            user: try user.asPublic()
        )
    }

    @Sendable
    func login(req: Request) async throws -> AuthResponseDTO {
        try LoginDTO.validate(content: req)
        let dto = try req.content.decode(LoginDTO.self)

        // Find user
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == dto.email.lowercased())
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }

        // Verify password
        guard try user.verify(password: dto.password) else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }

        // Generate token
        let token = try user.generateToken()
        try await token.save(on: req.db)

        return AuthResponseDTO(
            token: token.value,
            user: try user.asPublic()
        )
    }

    @Sendable
    func me(req: Request) async throws -> User.Public {
        let user = try req.auth.require(User.self)
        return try user.asPublic()
    }

    @Sendable
    func logout(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)

        // Delete all tokens for this user (logout from all devices)
        try await UserToken.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .delete()

        return .noContent
    }

    @Sendable
    func changePassword(req: Request) async throws -> HTTPStatus {
        try ChangePasswordDTO.validate(content: req)
        let dto = try req.content.decode(ChangePasswordDTO.self)
        let user = try req.auth.require(User.self)

        // Verify current password
        guard try user.verify(password: dto.currentPassword) else {
            throw Abort(.unauthorized, reason: "Current password is incorrect")
        }

        // Ensure new password is different
        guard dto.currentPassword != dto.newPassword else {
            throw Abort(.badRequest, reason: "New password must be different from current password")
        }

        // Update password
        user.passwordHash = try Bcrypt.hash(dto.newPassword)
        try await user.save(on: req.db)

        // Invalidate all existing tokens (force re-login)
        try await UserToken.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .delete()

        return .noContent
    }

    @Sendable
    func deleteAccount(req: Request) async throws -> HTTPStatus {
        try DeleteAccountDTO.validate(content: req)
        let dto = try req.content.decode(DeleteAccountDTO.self)
        let user = try req.auth.require(User.self)
        let userId = try user.requireID()

        // Verify password
        guard try user.verify(password: dto.password) else {
            throw Abort(.unauthorized, reason: "Password is incorrect")
        }

        // Find all projects owned by this user
        let ownedProjects = try await Project.query(on: req.db)
            .filter(\.$owner.$id == userId)
            .all()

        for project in ownedProjects {
            // Check if project has other members who could become owner
            let members = try await ProjectMember.query(on: req.db)
                .filter(\.$project.$id == project.requireID())
                .filter(\.$user.$id != userId)
                .with(\.$user)
                .all()

            if let newOwnerMember = members.first(where: { $0.role == .admin }) ?? members.first {
                // Transfer ownership to another member
                project.$owner.id = newOwnerMember.$user.id
                try await project.save(on: req.db)
                // Remove the new owner from members (they're now owner)
                try await newOwnerMember.delete(on: req.db)
            } else {
                // No other members, archive the project
                project.isArchived = true
                project.archivedAt = Date()
                try await project.save(on: req.db)
            }
        }

        // Remove user from all project memberships
        try await ProjectMember.query(on: req.db)
            .filter(\.$user.$id == userId)
            .delete()

        // Delete all user tokens
        try await UserToken.query(on: req.db)
            .filter(\.$user.$id == userId)
            .delete()

        // Delete the user
        try await user.delete(on: req.db)

        return .noContent
    }

    @Sendable
    func verifyEmail(req: Request) async throws -> VerifyEmailResponseDTO {
        try VerifyEmailDTO.validate(content: req)
        let dto = try req.content.decode(VerifyEmailDTO.self)

        // Find the verification record
        guard let verification = try await EmailVerification.query(on: req.db)
            .filter(\.$token == dto.code.uppercased())
            .with(\.$user)
            .first() else {
            throw Abort(.notFound, reason: "Invalid verification code")
        }

        // Check if already verified
        if verification.isVerified {
            throw Abort(.badRequest, reason: "Email has already been verified")
        }

        // Check if expired
        if verification.isExpired {
            throw Abort(.gone, reason: "Verification code has expired. Please request a new one.")
        }

        // Mark as verified
        verification.verifiedAt = Date()
        try await verification.save(on: req.db)

        // Update user
        verification.user.isEmailVerified = true
        try await verification.user.save(on: req.db)

        return VerifyEmailResponseDTO(
            message: "Email verified successfully",
            user: try verification.user.asPublic()
        )
    }

    @Sendable
    func resendVerification(req: Request) async throws -> MessageResponseDTO {
        let user = try req.auth.require(User.self)

        // Check if already verified
        if user.isEmailVerified {
            throw Abort(.badRequest, reason: "Email is already verified")
        }

        // Delete any existing verification tokens for this user
        try await EmailVerification.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .delete()

        // Create new verification
        let verification = EmailVerification(userId: try user.requireID())
        try await verification.save(on: req.db)

        // Send verification email
        try await req.emailService.sendEmailVerification(
            to: user.email,
            userName: user.name,
            verificationCode: verification.token
        )

        return MessageResponseDTO(message: "Verification email sent")
    }

    @Sendable
    func updateNotificationSettings(req: Request) async throws -> User.Public {
        let user = try req.auth.require(User.self)
        let dto = try req.content.decode(UpdateNotificationSettingsDTO.self)

        if let notifyNewFeedback = dto.notifyNewFeedback {
            user.notifyNewFeedback = notifyNewFeedback
        }
        if let notifyNewComments = dto.notifyNewComments {
            // Only Pro+ users can enable comment notifications
            // Free users silently stay OFF (preserves intent if they upgrade)
            user.notifyNewComments = user.subscriptionTier.meetsRequirement(.pro) ? notifyNewComments : false
        }

        try await user.save(on: req.db)
        return try user.asPublic()
    }

    @Sendable
    func forgotPassword(req: Request) async throws -> MessageResponseDTO {
        try ForgotPasswordDTO.validate(content: req)
        let dto = try req.content.decode(ForgotPasswordDTO.self)

        // Find user by email (case-insensitive)
        if let user = try await User.query(on: req.db)
            .filter(\.$email == dto.email.lowercased())
            .first() {

            // Delete any existing password reset tokens for this user
            try await PasswordReset.query(on: req.db)
                .filter(\.$user.$id == user.requireID())
                .delete()

            // Create new password reset token (1-hour expiry)
            let passwordReset = PasswordReset(userId: try user.requireID())
            try await passwordReset.save(on: req.db)

            // Send password reset email
            try await req.emailService.sendPasswordResetEmail(
                to: user.email,
                userName: user.name,
                resetCode: passwordReset.token
            )
        }

        // Always return success to prevent email enumeration
        return MessageResponseDTO(message: "If an account exists with that email, a password reset code has been sent.")
    }

    @Sendable
    func resetPassword(req: Request) async throws -> MessageResponseDTO {
        let dto = try req.content.decode(ResetPasswordDTO.self)

        // Manual validation
        guard dto.code.count == 8 else {
            throw Abort(.badRequest, reason: "Code must be exactly 8 characters")
        }
        guard dto.newPassword.count >= 8 else {
            throw Abort(.badRequest, reason: "Password must be at least 8 characters")
        }

        // Find the password reset record
        guard let passwordReset = try await PasswordReset.query(on: req.db)
            .filter(\.$token == dto.code.uppercased())
            .with(\.$user)
            .first() else {
            throw Abort(.notFound, reason: "Invalid reset code")
        }

        // Check if already used
        if passwordReset.isUsed {
            throw Abort(.badRequest, reason: "This reset code has already been used")
        }

        // Check if expired
        if passwordReset.isExpired {
            throw Abort(.gone, reason: "Reset code has expired. Please request a new one.")
        }

        // Hash new password and update user
        passwordReset.user.passwordHash = try Bcrypt.hash(dto.newPassword)
        try await passwordReset.user.save(on: req.db)

        // Mark token as used
        passwordReset.usedAt = Date()
        try await passwordReset.save(on: req.db)

        // Delete all user tokens (force re-login on all devices)
        try await UserToken.query(on: req.db)
            .filter(\.$user.$id == passwordReset.$user.id)
            .delete()

        return MessageResponseDTO(message: "Password has been reset successfully. Please log in with your new password.")
    }

    // MARK: - Subscription Endpoints

    /// Get current subscription info
    /// GET /auth/subscription
    @Sendable
    func getSubscription(req: Request) async throws -> SubscriptionInfoDTO {
        let user = try req.auth.require(User.self)

        // Count user's owned projects
        let projectCount = try await Project.query(on: req.db)
            .filter(\.$owner.$id == user.requireID())
            .count()

        let tier = user.subscriptionTier
        let canCreateProject: Bool
        if let maxProjects = tier.maxProjects {
            canCreateProject = projectCount < maxProjects
        } else {
            canCreateProject = true
        }

        return SubscriptionInfoDTO(
            tier: tier,
            status: user.subscriptionStatus,
            productId: user.subscriptionProductId,
            expiresAt: user.subscriptionExpiresAt,
            limits: SubscriptionLimitsDTO(
                maxProjects: tier.maxProjects,
                maxFeedbackPerProject: tier.maxFeedbackPerProject,
                currentProjectCount: projectCount,
                canCreateProject: canCreateProject
            )
        )
    }

    /// Sync subscription status with RevenueCat
    /// POST /auth/subscription/sync
    @Sendable
    func syncSubscription(req: Request) async throws -> SubscriptionInfoDTO {
        let user = try req.auth.require(User.self)

        // Optionally update the RevenueCat app user ID
        if let dto = try? req.content.decode(SyncSubscriptionDTO.self),
           let appUserId = dto.revenueCatAppUserId {
            user.revenueCatAppUserId = appUserId
        }

        // If user has a RevenueCat app user ID, fetch latest subscription info
        if let appUserId = user.revenueCatAppUserId {
            do {
                let subscriber = try await req.revenueCatService.getSubscriber(appUserId: appUserId)
                let entitlements = subscriber.subscriber.entitlements

                // Update user subscription fields
                user.subscriptionTier = req.revenueCatService.mapEntitlementsToTier(entitlements: entitlements)
                user.subscriptionStatus = req.revenueCatService.getSubscriptionStatus(entitlements: entitlements)
                user.subscriptionExpiresAt = req.revenueCatService.getExpirationDate(entitlements: entitlements)
                user.subscriptionProductId = req.revenueCatService.getProductId(entitlements: entitlements)
                user.subscriptionUpdatedAt = Date()
            } catch {
                req.logger.error("Failed to sync subscription with RevenueCat: \(error)")
                // Don't fail the request, just return current subscription info
            }
        }

        try await user.save(on: req.db)

        // Return updated subscription info
        return try await getSubscription(req: req)
    }

    /// Override subscription tier directly (non-production environments only)
    /// PATCH /auth/subscription/tier
    @Sendable
    func overrideSubscriptionTier(req: Request) async throws -> SubscriptionInfoDTO {
        // Only allow in non-production environments
        guard !AppEnvironment.shared.isProduction else {
            throw Abort(.forbidden, reason: "Subscription tier override is only available in non-production environments")
        }

        let user = try req.auth.require(User.self)
        let dto = try req.content.decode(OverrideSubscriptionTierDTO.self)

        user.subscriptionTier = dto.tier
        user.subscriptionUpdatedAt = Date()

        try await user.save(on: req.db)

        return try await getSubscription(req: req)
    }
}
