import Vapor

struct ClickUpService {
    private let client: Client
    private let baseURL = "https://api.clickup.com/api/v2"

    init(client: Client) {
        self.client = client
    }

    // MARK: - Response Types

    struct ClickUpTaskResponse: Codable {
        let id: String
        let name: String
        let url: String
        let status: TaskStatus

        struct TaskStatus: Codable {
            let status: String
        }
    }

    struct ClickUpWorkspace: Codable {
        let id: String
        let name: String
    }

    struct ClickUpSpace: Codable {
        let id: String
        let name: String
    }

    struct ClickUpFolder: Codable {
        let id: String
        let name: String
    }

    struct ClickUpList: Codable {
        let id: String
        let name: String
    }

    struct ClickUpCustomField: Codable {
        let id: String
        let name: String
        let type: String
    }

    struct ClickUpCommentResponse: Codable {
        let id: String
        let commentText: String
        let date: String
    }

    struct ClickUpErrorResponse: Codable {
        let err: String
        let ECODE: String?
    }

    // MARK: - Create Task

    func createTask(
        listId: String,
        token: String,
        name: String,
        markdownDescription: String,
        tags: [String]?,
        priority: Int? = nil
    ) async throws -> ClickUpTaskResponse {
        let url = URI(string: "\(baseURL)/list/\(listId)/task")

        struct CreateTaskRequest: Content {
            let name: String
            let markdown_description: String
            let tags: [String]?
            let priority: Int?
            let notify_all: Bool
        }

        let requestBody = CreateTaskRequest(
            name: name,
            markdown_description: markdownDescription,
            tags: tags,
            priority: priority,
            notify_all: false
        )

        let response = try await client.post(url) { req in
            req.headers.add(name: .authorization, value: token)
            req.headers.add(name: .contentType, value: "application/json")
            try req.content.encode(requestBody)
        }

        guard let bodyData = response.body else {
            throw Abort(.badGateway, reason: "ClickUp API returned empty response")
        }
        let data = Data(buffer: bodyData)

        guard response.status == .ok || response.status == .created else {
            if let errorResponse = try? JSONDecoder().decode(ClickUpErrorResponse.self, from: data) {
                throw Abort(.badGateway, reason: "ClickUp API error: \(errorResponse.err)")
            }
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw Abort(.badGateway, reason: "ClickUp API error (\(response.status)): \(responseBody)")
        }

        do {
            return try JSONDecoder().decode(ClickUpTaskResponse.self, from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "decode failed"
            throw Abort(.badGateway, reason: "Failed to decode ClickUp response: \(error.localizedDescription). Body: \(responseBody)")
        }
    }

    // MARK: - Update Task Status

    func updateTaskStatus(
        taskId: String,
        token: String,
        status: String
    ) async throws {
        let url = URI(string: "\(baseURL)/task/\(taskId)")

        let response = try await client.put(url) { req in
            req.headers.add(name: .authorization, value: token)
            req.headers.add(name: .contentType, value: "application/json")
            try req.content.encode(["status": status])
        }

        guard response.status == .ok else {
            if let bodyData = response.body,
               let errorResponse = try? JSONDecoder().decode(ClickUpErrorResponse.self, from: Data(buffer: bodyData)) {
                throw Abort(.badGateway, reason: "ClickUp API error: \(errorResponse.err)")
            }
            throw Abort(.badGateway, reason: "ClickUp API error: \(response.status)")
        }
    }

    // MARK: - Create Task Comment

    func createTaskComment(
        taskId: String,
        token: String,
        commentText: String,
        notifyAll: Bool = false
    ) async throws -> ClickUpCommentResponse {
        let url = URI(string: "\(baseURL)/task/\(taskId)/comment")

        struct CreateCommentRequest: Content {
            let comment_text: String
            let notify_all: Bool
        }

        let requestBody = CreateCommentRequest(
            comment_text: commentText,
            notify_all: notifyAll
        )

        let response = try await client.post(url) { req in
            req.headers.add(name: .authorization, value: token)
            req.headers.add(name: .contentType, value: "application/json")
            try req.content.encode(requestBody)
        }

        guard let bodyData = response.body else {
            throw Abort(.badGateway, reason: "ClickUp API returned empty response")
        }
        let data = Data(buffer: bodyData)

        guard response.status == .ok || response.status == .created else {
            if let errorResponse = try? JSONDecoder().decode(ClickUpErrorResponse.self, from: data) {
                throw Abort(.badGateway, reason: "ClickUp API error: \(errorResponse.err)")
            }
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw Abort(.badGateway, reason: "ClickUp API error (\(response.status)): \(responseBody)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ClickUpCommentResponse.self, from: data)
    }

    // MARK: - Set Custom Field Value (for Vote Count)

    func setCustomFieldValue(
        taskId: String,
        fieldId: String,
        token: String,
        value: Int
    ) async throws {
        let url = URI(string: "\(baseURL)/task/\(taskId)/field/\(fieldId)")

        let response = try await client.post(url) { req in
            req.headers.add(name: .authorization, value: token)
            req.headers.add(name: .contentType, value: "application/json")
            try req.content.encode(["value": value])
        }

        guard response.status == .ok else {
            if let bodyData = response.body,
               let errorResponse = try? JSONDecoder().decode(ClickUpErrorResponse.self, from: Data(buffer: bodyData)) {
                throw Abort(.badGateway, reason: "ClickUp API error: \(errorResponse.err)")
            }
            throw Abort(.badGateway, reason: "ClickUp API error: \(response.status)")
        }
    }

    // MARK: - Get List Custom Fields

    func getListCustomFields(listId: String, token: String) async throws -> [ClickUpCustomField] {
        let url = URI(string: "\(baseURL)/list/\(listId)/field")
        let response = try await client.get(url) { req in
            req.headers.add(name: .authorization, value: token)
        }

        struct FieldsResponse: Codable {
            let fields: [ClickUpCustomField]
        }

        guard response.status == .ok, let bodyData = response.body else {
            throw Abort(.badGateway, reason: "Failed to fetch ClickUp custom fields")
        }

        let decoded = try JSONDecoder().decode(FieldsResponse.self, from: Data(buffer: bodyData))
        return decoded.fields
    }

    // MARK: - Hierarchy Endpoints (for settings UI)

    func getWorkspaces(token: String) async throws -> [ClickUpWorkspace] {
        let url = URI(string: "\(baseURL)/team")
        let response = try await client.get(url) { req in
            req.headers.add(name: .authorization, value: token)
        }

        struct WorkspacesResponse: Codable {
            let teams: [ClickUpWorkspace]
        }

        guard response.status == .ok, let bodyData = response.body else {
            throw Abort(.badGateway, reason: "Failed to fetch ClickUp workspaces")
        }

        let decoded = try JSONDecoder().decode(WorkspacesResponse.self, from: Data(buffer: bodyData))
        return decoded.teams
    }

    func getSpaces(workspaceId: String, token: String) async throws -> [ClickUpSpace] {
        let url = URI(string: "\(baseURL)/team/\(workspaceId)/space")
        let response = try await client.get(url) { req in
            req.headers.add(name: .authorization, value: token)
        }

        struct SpacesResponse: Codable {
            let spaces: [ClickUpSpace]
        }

        guard response.status == .ok, let bodyData = response.body else {
            throw Abort(.badGateway, reason: "Failed to fetch ClickUp spaces")
        }

        let decoded = try JSONDecoder().decode(SpacesResponse.self, from: Data(buffer: bodyData))
        return decoded.spaces
    }

    func getFolders(spaceId: String, token: String) async throws -> [ClickUpFolder] {
        let url = URI(string: "\(baseURL)/space/\(spaceId)/folder")
        let response = try await client.get(url) { req in
            req.headers.add(name: .authorization, value: token)
        }

        struct FoldersResponse: Codable {
            let folders: [ClickUpFolder]
        }

        guard response.status == .ok, let bodyData = response.body else {
            throw Abort(.badGateway, reason: "Failed to fetch ClickUp folders")
        }

        let decoded = try JSONDecoder().decode(FoldersResponse.self, from: Data(buffer: bodyData))
        return decoded.folders
    }

    func getLists(folderId: String, token: String) async throws -> [ClickUpList] {
        let url = URI(string: "\(baseURL)/folder/\(folderId)/list")
        let response = try await client.get(url) { req in
            req.headers.add(name: .authorization, value: token)
        }

        struct ListsResponse: Codable {
            let lists: [ClickUpList]
        }

        guard response.status == .ok, let bodyData = response.body else {
            throw Abort(.badGateway, reason: "Failed to fetch ClickUp lists")
        }

        let decoded = try JSONDecoder().decode(ListsResponse.self, from: Data(buffer: bodyData))
        return decoded.lists
    }

    func getFolderlessLists(spaceId: String, token: String) async throws -> [ClickUpList] {
        let url = URI(string: "\(baseURL)/space/\(spaceId)/list")
        let response = try await client.get(url) { req in
            req.headers.add(name: .authorization, value: token)
        }

        struct ListsResponse: Codable {
            let lists: [ClickUpList]
        }

        guard response.status == .ok, let bodyData = response.body else {
            throw Abort(.badGateway, reason: "Failed to fetch ClickUp folderless lists")
        }

        let decoded = try JSONDecoder().decode(ListsResponse.self, from: Data(buffer: bodyData))
        return decoded.lists
    }

    // MARK: - Build Task Description

    func buildTaskDescription(
        feedback: Feedback,
        projectName: String,
        voteCount: Int,
        mrr: Double?
    ) -> String {
        var description = """
        ## \(feedback.category.displayName)

        \(feedback.description)

        ---

        **Source:** SwiftlyFeedback
        **Project:** \(projectName)
        **Votes:** \(voteCount)
        """

        if let mrr = mrr, mrr > 0 {
            description += "\n**MRR:** $\(String(format: "%.2f", mrr))"
        }

        if let userEmail = feedback.userEmail {
            description += "\n**Submitted by:** \(userEmail)"
        }

        return description
    }
}

// MARK: - Request Extension

extension Request {
    var clickupService: ClickUpService {
        ClickUpService(client: self.client)
    }
}
