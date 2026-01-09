import Vapor
import Fluent

struct RevenueCatWebhookController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let webhooks = routes.grouped("webhooks")
        webhooks.post("revenuecat", use: handleWebhook)
    }

    /// Handle incoming webhook from RevenueCat
    /// POST /api/v1/webhooks/revenuecat
    @Sendable
    func handleWebhook(req: Request) async throws -> HTTPStatus {
        // Get raw body for signature verification
        guard let bodyData = req.body.data else {
            throw Abort(.badRequest, reason: "Missing request body")
        }

        // Verify webhook signature if configured
        let signature = req.headers.first(name: "X-RevenueCat-Signature") ?? ""
        let rawBody = Data(buffer: bodyData)

        guard req.revenueCatService.verifyWebhookSignature(payload: rawBody, signature: signature) else {
            req.logger.warning("RevenueCat webhook signature verification failed")
            throw Abort(.unauthorized, reason: "Invalid webhook signature")
        }

        // Decode the webhook payload
        let payload: RevenueCatWebhookPayload
        do {
            payload = try req.content.decode(RevenueCatWebhookPayload.self)
        } catch {
            req.logger.error("Failed to decode RevenueCat webhook payload: \(error)")
            throw Abort(.badRequest, reason: "Invalid webhook payload")
        }

        let event = payload.event
        req.logger.info("Received RevenueCat webhook: \(event.type) for user \(event.appUserId)")

        // Process the webhook event
        do {
            try await req.revenueCatService.processWebhookEvent(event: event, on: req.db)
            req.logger.info("Successfully processed RevenueCat webhook: \(event.type)")
        } catch {
            req.logger.error("Failed to process RevenueCat webhook: \(error)")
            // Return 200 to prevent retries for processing errors
            // RevenueCat will retry on 5xx errors
        }

        // Always return 200 OK to acknowledge receipt
        return .ok
    }
}
