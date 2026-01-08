import Vapor

struct EmailService {
    private let apiKey: String
    private let client: Client
    private let baseURL = "https://api.resend.com"

    init(client: Client) {
        self.apiKey = Environment.get("RESEND_API_KEY") ?? "re_Tx4Gv22o_75qkTKVeceK9KD8LZ5NdDsiW"
        self.client = client
    }

    func sendProjectInvite(
        to email: String,
        inviterName: String,
        projectName: String,
        inviteCode: String,
        role: ProjectRole
    ) async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
                <h1 style="color: white; margin: 0; font-size: 24px;">You're Invited!</h1>
            </div>
            <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 12px 12px;">
                <p style="font-size: 16px; margin-bottom: 20px;">Hi there,</p>
                <p style="font-size: 16px; margin-bottom: 20px;">
                    <strong>\(inviterName)</strong> has invited you to join <strong>\(projectName)</strong> on Feedback Kit as a <strong>\(role.rawValue)</strong>.
                </p>
                <p style="font-size: 16px; margin-bottom: 25px;">
                    Feedback Kit helps teams collect and manage user feedback for their apps.
                </p>
                <p style="font-size: 16px; margin-bottom: 10px; text-align: center;">
                    Your invite code is:
                </p>
                <div style="text-align: center; margin: 20px 0;">
                    <div style="background: #f5f5f5; border: 2px dashed #667eea; border-radius: 8px; padding: 20px; display: inline-block;">
                        <span style="font-family: 'SF Mono', Monaco, 'Courier New', monospace; font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #667eea;">\(inviteCode)</span>
                    </div>
                </div>
                <p style="font-size: 14px; color: #666; margin-top: 25px; text-align: center;">
                    Open the Feedback Kit app and enter this code to accept your invitation.
                </p>
                <p style="font-size: 14px; color: #666; margin-top: 10px; text-align: center;">
                    If you don't have a Feedback Kit account yet, create one first, then enter this code.
                </p>
                <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 25px 0;">
                <p style="font-size: 12px; color: #999; text-align: center;">
                    If you didn't expect this invitation, you can safely ignore this email.
                </p>
            </div>
        </body>
        </html>
        """

        let request = ResendEmailRequest(
            from: "Feedback Kit <noreply@swiftly-workspace.com>",
            to: [email],
            subject: "\(inviterName) invited you to \(projectName)",
            html: html
        )

        try await sendEmail(request)
    }

    func sendEmailVerification(
        to email: String,
        userName: String,
        verificationCode: String
    ) async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
                <h1 style="color: white; margin: 0; font-size: 24px;">Verify Your Email</h1>
            </div>
            <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 12px 12px;">
                <p style="font-size: 16px; margin-bottom: 20px;">Hi \(userName),</p>
                <p style="font-size: 16px; margin-bottom: 20px;">
                    Welcome to Feedback Kit! Please verify your email address to complete your registration.
                </p>
                <p style="font-size: 16px; margin-bottom: 10px; text-align: center;">
                    Your verification code is:
                </p>
                <div style="text-align: center; margin: 20px 0;">
                    <div style="background: #f5f5f5; border: 2px dashed #667eea; border-radius: 8px; padding: 20px; display: inline-block;">
                        <span style="font-family: 'SF Mono', Monaco, 'Courier New', monospace; font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #667eea;">\(verificationCode)</span>
                    </div>
                </div>
                <p style="font-size: 14px; color: #666; margin-top: 25px; text-align: center;">
                    Enter this code in the Feedback Kit app to verify your email.
                </p>
                <p style="font-size: 14px; color: #666; margin-top: 10px; text-align: center;">
                    This code expires in 24 hours.
                </p>
                <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 25px 0;">
                <p style="font-size: 12px; color: #999; text-align: center;">
                    If you didn't create an account with Feedback Kit, you can safely ignore this email.
                </p>
            </div>
        </body>
        </html>
        """

        let request = ResendEmailRequest(
            from: "Feedback Kit <noreply@swiftly-workspace.com>",
            to: [email],
            subject: "Verify your email for Feedback Kit",
            html: html
        )

        try await sendEmail(request)
    }

    func sendNewFeedbackNotification(
        to emails: [String],
        projectName: String,
        feedbackTitle: String,
        feedbackCategory: String,
        feedbackDescription: String
    ) async throws {
        guard !emails.isEmpty else { return }

        let truncatedDescription = feedbackDescription.count > 200
            ? String(feedbackDescription.prefix(200)) + "..."
            : feedbackDescription

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
                <h1 style="color: white; margin: 0; font-size: 24px;">New Feedback Received</h1>
            </div>
            <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 12px 12px;">
                <p style="font-size: 16px; margin-bottom: 20px;">
                    A new feedback has been submitted to <strong>\(projectName)</strong>.
                </p>
                <div style="background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 20px 0;">
                    <p style="font-size: 12px; color: #666; margin: 0 0 5px 0; text-transform: uppercase; letter-spacing: 1px;">\(feedbackCategory.replacingOccurrences(of: "_", with: " "))</p>
                    <h2 style="font-size: 18px; margin: 0 0 10px 0; color: #333;">\(feedbackTitle)</h2>
                    <p style="font-size: 14px; color: #555; margin: 0;">\(truncatedDescription)</p>
                </div>
                <p style="font-size: 14px; color: #666; margin-top: 25px; text-align: center;">
                    Open the Feedback Kit app to view and respond to this feedback.
                </p>
                <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 25px 0;">
                <p style="font-size: 12px; color: #999; text-align: center;">
                    You received this email because you are a member of \(projectName).
                </p>
            </div>
        </body>
        </html>
        """

        let request = ResendEmailRequest(
            from: "Feedback Kit <noreply@swiftly-workspace.com>",
            to: emails,
            subject: "[\(projectName)] New feedback: \(feedbackTitle)",
            html: html
        )

        try await sendEmail(request)
    }

    func sendNewCommentNotification(
        to emails: [String],
        projectName: String,
        feedbackTitle: String,
        commentContent: String,
        commenterName: String
    ) async throws {
        guard !emails.isEmpty else { return }

        let truncatedComment = commentContent.count > 300
            ? String(commentContent.prefix(300)) + "..."
            : commentContent

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
                <h1 style="color: white; margin: 0; font-size: 24px;">New Comment</h1>
            </div>
            <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 12px 12px;">
                <p style="font-size: 16px; margin-bottom: 20px;">
                    A new comment was added to feedback in <strong>\(projectName)</strong>.
                </p>
                <div style="background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 20px 0;">
                    <p style="font-size: 12px; color: #666; margin: 0 0 5px 0; text-transform: uppercase; letter-spacing: 1px;">FEEDBACK</p>
                    <h2 style="font-size: 18px; margin: 0 0 15px 0; color: #333;">\(feedbackTitle)</h2>
                    <div style="border-left: 3px solid #667eea; padding-left: 15px; margin-top: 15px;">
                        <p style="font-size: 12px; color: #667eea; margin: 0 0 5px 0; font-weight: 600;">\(commenterName)</p>
                        <p style="font-size: 14px; color: #555; margin: 0;">\(truncatedComment)</p>
                    </div>
                </div>
                <p style="font-size: 14px; color: #666; margin-top: 25px; text-align: center;">
                    Open the Feedback Kit app to view and respond to this comment.
                </p>
                <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 25px 0;">
                <p style="font-size: 12px; color: #999; text-align: center;">
                    You received this email because you are a member of \(projectName).
                </p>
            </div>
        </body>
        </html>
        """

        let request = ResendEmailRequest(
            from: "Feedback Kit <noreply@swiftly-workspace.com>",
            to: emails,
            subject: "[\(projectName)] New comment on: \(feedbackTitle)",
            html: html
        )

        try await sendEmail(request)
    }

    func sendFeedbackStatusChangeNotification(
        to emails: [String],
        projectName: String,
        feedbackTitle: String,
        oldStatus: String,
        newStatus: String
    ) async throws {
        guard !emails.isEmpty else { return }

        let statusEmoji = switch newStatus {
        case "approved": "✅"
        case "in_progress": "🔄"
        case "completed": "🎉"
        case "rejected": "❌"
        default: "📋"
        }

        let statusMessage = switch newStatus {
        case "approved": "Your feedback has been approved and will be considered for implementation."
        case "in_progress": "Great news! Work has started on your feedback."
        case "completed": "Your feedback has been implemented!"
        case "rejected": "After review, this feedback will not be implemented at this time."
        default: "The status of your feedback has been updated."
        }

        let formattedOldStatus = oldStatus.replacingOccurrences(of: "_", with: " ").capitalized
        let formattedNewStatus = newStatus.replacingOccurrences(of: "_", with: " ").capitalized

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
                <h1 style="color: white; margin: 0; font-size: 24px;">\(statusEmoji) Status Update</h1>
            </div>
            <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 12px 12px;">
                <p style="font-size: 16px; margin-bottom: 20px;">
                    Your feedback in <strong>\(projectName)</strong> has a status update.
                </p>
                <div style="background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 20px 0;">
                    <h2 style="font-size: 18px; margin: 0 0 15px 0; color: #333;">\(feedbackTitle)</h2>
                    <div style="display: flex; align-items: center; gap: 10px; margin-top: 15px;">
                        <span style="background: #e0e0e0; color: #666; padding: 4px 12px; border-radius: 20px; font-size: 12px; text-decoration: line-through;">\(formattedOldStatus)</span>
                        <span style="color: #999;">→</span>
                        <span style="background: #667eea; color: white; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 600;">\(formattedNewStatus)</span>
                    </div>
                </div>
                <p style="font-size: 14px; color: #555; margin-top: 20px;">
                    \(statusMessage)
                </p>
                <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 25px 0;">
                <p style="font-size: 12px; color: #999; text-align: center;">
                    You received this email because you submitted or voted on this feedback.
                </p>
            </div>
        </body>
        </html>
        """

        let request = ResendEmailRequest(
            from: "Feedback Kit <noreply@swiftly-workspace.com>",
            to: emails,
            subject: "[\(projectName)] \(statusEmoji) \(feedbackTitle) - \(formattedNewStatus)",
            html: html
        )

        try await sendEmail(request)
    }

    func sendPasswordResetEmail(
        to email: String,
        userName: String,
        resetCode: String
    ) async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 12px 12px 0 0; text-align: center;">
                <h1 style="color: white; margin: 0; font-size: 24px;">Reset Your Password</h1>
            </div>
            <div style="background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 12px 12px;">
                <p style="font-size: 16px; margin-bottom: 20px;">Hi \(userName),</p>
                <p style="font-size: 16px; margin-bottom: 20px;">
                    We received a request to reset your password for your Feedback Kit account.
                </p>
                <p style="font-size: 16px; margin-bottom: 10px; text-align: center;">
                    Your password reset code is:
                </p>
                <div style="text-align: center; margin: 20px 0;">
                    <div style="background: #f5f5f5; border: 2px dashed #667eea; border-radius: 8px; padding: 20px; display: inline-block;">
                        <span style="font-family: 'SF Mono', Monaco, 'Courier New', monospace; font-size: 32px; font-weight: bold; letter-spacing: 4px; color: #667eea;">\(resetCode)</span>
                    </div>
                </div>
                <p style="font-size: 14px; color: #666; margin-top: 25px; text-align: center;">
                    Enter this code in the Feedback Kit app to reset your password.
                </p>
                <p style="font-size: 14px; color: #e74c3c; margin-top: 10px; text-align: center; font-weight: 600;">
                    This code expires in 1 hour.
                </p>
                <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 25px 0;">
                <p style="font-size: 12px; color: #999; text-align: center;">
                    If you didn't request a password reset, you can safely ignore this email. Your password will not be changed.
                </p>
            </div>
        </body>
        </html>
        """

        let request = ResendEmailRequest(
            from: "Feedback Kit <noreply@swiftly-workspace.com>",
            to: [email],
            subject: "Reset your Feedback Kit password",
            html: html
        )

        try await sendEmail(request)
    }

    private func sendEmail(_ request: ResendEmailRequest) async throws {
        let response = try await client.post(URI(string: "\(baseURL)/emails")) { req in
            req.headers.add(name: .authorization, value: "Bearer \(apiKey)")
            req.headers.add(name: .contentType, value: "application/json")
            try req.content.encode(request)
        }

        guard response.status == .ok else {
            let errorBody = response.body.map { String(buffer: $0) } ?? "Unknown error"
            throw Abort(.internalServerError, reason: "Failed to send email: \(errorBody)")
        }
    }
}

private struct ResendEmailRequest: Content {
    let from: String
    let to: [String]
    let subject: String
    let html: String
}

extension Request {
    var emailService: EmailService {
        EmailService(client: self.client)
    }
}
