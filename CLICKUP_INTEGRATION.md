# ClickUp Integration - Technical Specification

> Technical document for integrating ClickUp task creation with SwiftlyFeedback, modeled after the existing GitHub integration.

## Executive Summary

This document outlines the implementation plan for integrating ClickUp with SwiftlyFeedback, allowing users to push feedback items as tasks to ClickUp Lists. The integration follows the same architectural patterns established by the GitHub integration.

## ClickUp API Overview

### Authentication

ClickUp supports two authentication methods:

1. **Personal API Token** (Recommended for our use case)
   - Token format: Begins with `pk_`
   - Header: `Authorization: {personal_token}`
   - Tokens never expire
   - Generated at: Settings > Apps > API Token

2. **OAuth 2.0** (For apps used by multiple users)
   - Authorization URL: `https://app.clickup.com/api`
   - Token URL: `https://api.clickup.com/api/v2/oauth/token`
   - Header: `Authorization: Bearer {access_token}`
   - Access tokens currently do not expire

**Recommendation:** Use Personal API Token for simplicity, matching the GitHub integration pattern.

### ClickUp Hierarchy

Understanding the ClickUp structure is important for configuration:

```
Workspace (team_id in API)
└── Space (space_id)
    ├── Folder (folder_id)
    │   └── List (list_id) ← Tasks are created here
    └── List (folderless list)
```

**Key Point:** Tasks are always created within a **List**, identified by `list_id`.

### Rate Limits

- 100 requests per minute per workspace
- 10 requests per minute per member for endpoints using `team_id`

### Create Task Endpoint

**URL:** `POST https://api.clickup.com/api/v2/list/{list_id}/task`

**Headers:**
```
Authorization: {personal_token}
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "Task Name",
  "description": "Plain text description",
  "markdown_description": "**Markdown** description",
  "assignees": [123456],
  "tags": ["feedback", "feature_request"],
  "status": "Open",
  "priority": 3,
  "due_date": 1508369194377,
  "due_date_time": false,
  "time_estimate": 8640000,
  "notify_all": true,
  "parent": null,
  "custom_fields": [
    {
      "id": "field-uuid",
      "value": "Custom value"
    }
  ]
}
```

**Priority Mapping:**
| Value | Priority |
|-------|----------|
| 1 | Urgent |
| 2 | High |
| 3 | Normal |
| 4 | Low |

**Response (201 Created):**
```json
{
  "id": "task_id",
  "name": "Task Name",
  "status": { "status": "Open" },
  "url": "https://app.clickup.com/t/task_id",
  ...
}
```

### Helper Endpoints (for configuration UI)

| Endpoint | Description |
|----------|-------------|
| `GET /api/v2/team` | Get user's Workspaces |
| `GET /api/v2/team/{team_id}/space` | Get Spaces in Workspace |
| `GET /api/v2/space/{space_id}/folder` | Get Folders in Space |
| `GET /api/v2/folder/{folder_id}/list` | Get Lists in Folder |
| `GET /api/v2/space/{space_id}/list` | Get Folderless Lists |
| `GET /api/v2/list/{list_id}` | Get List details (including statuses) |
| `GET /api/v2/list/{list_id}/field` | Get Custom Fields for a List |

### Create Task Comment Endpoint

**URL:** `POST https://api.clickup.com/api/v2/task/{task_id}/comment`

**Headers:**
```
Authorization: {personal_token}
Content-Type: application/json
```

**Request Body:**
```json
{
  "comment_text": "Comment content here",
  "notify_all": false
}
```

**Response (200 OK):**
```json
{
  "id": "comment_id",
  "comment_text": "Comment content here",
  "user": { ... },
  "date": "1568036964079"
}
```

### Set Custom Field Value Endpoint

**URL:** `POST https://api.clickup.com/api/v2/task/{task_id}/field/{field_id}`

**Request Body (for number field):**
```json
{
  "value": 42
}
```

**Important Notes:**
- ClickUp's native **Voting Custom Field cannot be set via API** - only through UI/Forms
- Use a **Number Custom Field** named "Votes" as an alternative
- Each custom field update counts as 1 API use (Free plans limited to 60 uses)

---

## Implementation Plan

### Phase 1: Database Schema

#### Migration: `AddProjectClickUpIntegration`

Add ClickUp fields to the `projects` table:

```swift
// SwiftlyFeedbackServer/Sources/App/Migrations/AddProjectClickUpIntegration.swift

import Fluent

struct AddProjectClickUpIntegration: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Add ClickUp fields to projects table
        try await database.schema("projects")
            .field("clickup_token", .string)
            .field("clickup_list_id", .string)
            .field("clickup_workspace_name", .string)  // For display only
            .field("clickup_list_name", .string)       // For display only
            .field("clickup_default_tags", .array(of: .string))
            .field("clickup_sync_status", .bool, .required, .sql(.default(false)))
            .field("clickup_sync_comments", .bool, .required, .sql(.default(false)))
            .field("clickup_votes_field_id", .string)  // Optional: Custom field ID for vote count
            .update()

        // Add ClickUp fields to feedbacks table
        try await database.schema("feedbacks")
            .field("clickup_task_url", .string)
            .field("clickup_task_id", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("projects")
            .deleteField("clickup_token")
            .deleteField("clickup_list_id")
            .deleteField("clickup_workspace_name")
            .deleteField("clickup_list_name")
            .deleteField("clickup_default_tags")
            .deleteField("clickup_sync_status")
            .deleteField("clickup_sync_comments")
            .deleteField("clickup_votes_field_id")
            .update()

        try await database.schema("feedbacks")
            .deleteField("clickup_task_url")
            .deleteField("clickup_task_id")
            .update()
    }
}
```

#### Updated Models

**Project Model Fields:**
```swift
// Add to Project.swift

@OptionalField(key: "clickup_token")
var clickupToken: String?

@OptionalField(key: "clickup_list_id")
var clickupListId: String?

@OptionalField(key: "clickup_workspace_name")
var clickupWorkspaceName: String?

@OptionalField(key: "clickup_list_name")
var clickupListName: String?

@OptionalField(key: "clickup_default_tags")
var clickupDefaultTags: [String]?

@Field(key: "clickup_sync_status")
var clickupSyncStatus: Bool

@Field(key: "clickup_sync_comments")
var clickupSyncComments: Bool

@OptionalField(key: "clickup_votes_field_id")
var clickupVotesFieldId: String?  // Custom field ID for syncing vote count
```

**Feedback Model Fields:**
```swift
// Add to Feedback.swift

@OptionalField(key: "clickup_task_url")
var clickupTaskURL: String?

@OptionalField(key: "clickup_task_id")
var clickupTaskId: String?
```

---

### Phase 2: Server Service

#### ClickUpService

```swift
// SwiftlyFeedbackServer/Sources/App/Services/ClickUpService.swift

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

    struct ClickUpCommentResponse: Codable {
        let id: String
        let commentText: String
        let date: String
    }

    /// Add a comment to a ClickUp task
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

    /// Update a number custom field on a task (used for vote count sync)
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

    struct ClickUpCustomField: Codable {
        let id: String
        let name: String
        let type: String
    }

    /// Get custom fields available for a list (for settings UI to select vote field)
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
```

---

### Phase 3: DTOs

```swift
// Add to SwiftlyFeedbackServer/Sources/App/DTOs/ProjectDTO.swift

// MARK: - ClickUp Integration

struct UpdateProjectClickUpDTO: Content {
    let clickupToken: String?
    let clickupListId: String?
    let clickupWorkspaceName: String?
    let clickupListName: String?
    let clickupDefaultTags: [String]?
    let clickupSyncStatus: Bool?
    let clickupSyncComments: Bool?
    let clickupVotesFieldId: String?  // Optional: Custom field ID for vote count
}

struct CreateClickUpTaskDTO: Content, Validatable {
    let feedbackId: UUID
    let additionalTags: [String]?

    static func validations(_ validations: inout Validations) {
        validations.add("feedbackId", as: UUID.self, is: .valid)
    }
}

struct CreateClickUpTaskResponseDTO: Content {
    let feedbackId: UUID
    let taskUrl: String
    let taskId: String
}

struct BulkCreateClickUpTasksDTO: Content {
    let feedbackIds: [UUID]
    let additionalTags: [String]?
}

struct BulkCreateClickUpTasksResponseDTO: Content {
    let created: [CreateClickUpTaskResponseDTO]
    let failed: [UUID]
}

// ClickUp hierarchy DTOs for settings UI
struct ClickUpWorkspaceDTO: Content {
    let id: String
    let name: String
}

struct ClickUpSpaceDTO: Content {
    let id: String
    let name: String
}

struct ClickUpFolderDTO: Content {
    let id: String
    let name: String
}

struct ClickUpListDTO: Content {
    let id: String
    let name: String
}

struct ClickUpCustomFieldDTO: Content {
    let id: String
    let name: String
    let type: String  // "number", "text", "dropdown", etc.
}
```

---

### Phase 4: Controller Endpoints

Add to `ProjectController.swift`:

```swift
// MARK: - ClickUp Integration

// Route registration (in boot method):
// protected.patch(":projectId", "clickup", use: updateClickUpSettings)
// protected.post(":projectId", "clickup", "task", use: createClickUpTask)
// protected.post(":projectId", "clickup", "tasks", use: bulkCreateClickUpTasks)
// protected.get(":projectId", "clickup", "workspaces", use: getClickUpWorkspaces)
// protected.get(":projectId", "clickup", "spaces", ":workspaceId", use: getClickUpSpaces)
// protected.get(":projectId", "clickup", "folders", ":spaceId", use: getClickUpFolders)
// protected.get(":projectId", "clickup", "lists", ":folderId", use: getClickUpLists)
// protected.get(":projectId", "clickup", "folderless-lists", ":spaceId", use: getClickUpFolderlessLists)
// protected.get(":projectId", "clickup", "custom-fields", use: getClickUpCustomFields)

@Sendable
func updateClickUpSettings(req: Request) async throws -> ProjectResponseDTO {
    let user = try req.auth.require(User.self)
    let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

    let dto = try req.content.decode(UpdateProjectClickUpDTO.self)

    if let token = dto.clickupToken {
        project.clickupToken = token.isEmpty ? nil : token
    }
    if let listId = dto.clickupListId {
        project.clickupListId = listId.isEmpty ? nil : listId
    }
    if let workspaceName = dto.clickupWorkspaceName {
        project.clickupWorkspaceName = workspaceName.isEmpty ? nil : workspaceName
    }
    if let listName = dto.clickupListName {
        project.clickupListName = listName.isEmpty ? nil : listName
    }
    if let tags = dto.clickupDefaultTags {
        project.clickupDefaultTags = tags.isEmpty ? nil : tags
    }
    if let syncStatus = dto.clickupSyncStatus {
        project.clickupSyncStatus = syncStatus
    }
    if let syncComments = dto.clickupSyncComments {
        project.clickupSyncComments = syncComments
    }
    if let votesFieldId = dto.clickupVotesFieldId {
        project.clickupVotesFieldId = votesFieldId.isEmpty ? nil : votesFieldId
    }

    try await project.save(on: req.db)

    try await project.$feedbacks.load(on: req.db)
    try await project.$members.load(on: req.db)
    try await project.$owner.load(on: req.db)

    return ProjectResponseDTO(
        project: project,
        feedbackCount: project.feedbacks.count,
        memberCount: project.members.count,
        ownerEmail: project.owner.email
    )
}

@Sendable
func createClickUpTask(req: Request) async throws -> CreateClickUpTaskResponseDTO {
    let user = try req.auth.require(User.self)
    let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

    guard let token = project.clickupToken,
          let listId = project.clickupListId else {
        throw Abort(.badRequest, reason: "ClickUp integration not configured")
    }

    let dto = try req.content.decode(CreateClickUpTaskDTO.self)

    guard let feedback = try await Feedback.query(on: req.db)
        .filter(\.$id == dto.feedbackId)
        .filter(\.$project.$id == project.id!)
        .with(\.$votes)
        .first() else {
        throw Abort(.notFound, reason: "Feedback not found")
    }

    if feedback.clickupTaskURL != nil {
        throw Abort(.conflict, reason: "Feedback already has a ClickUp task")
    }

    // Build tags
    var tags = project.clickupDefaultTags ?? []
    if let additional = dto.additionalTags {
        tags.append(contentsOf: additional)
    }
    tags.append(feedback.category.rawValue)

    // Calculate MRR
    let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
    let sdkUsers = try await SDKUser.query(on: req.db)
        .filter(\.$project.$id == project.id!)
        .filter(\.$userId ~~ Array(allUserIds))
        .all()
    let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

    var totalMrr: Double = 0
    if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
        totalMrr += creatorMrr
    }
    for vote in feedback.votes {
        if let voterMrr = mrrByUserId[vote.userId] ?? nil {
            totalMrr += voterMrr
        }
    }

    let description = req.clickupService.buildTaskDescription(
        feedback: feedback,
        projectName: project.name,
        voteCount: feedback.voteCount,
        mrr: totalMrr > 0 ? totalMrr : nil
    )

    let response = try await req.clickupService.createTask(
        listId: listId,
        token: token,
        name: feedback.title,
        markdownDescription: description,
        tags: tags.isEmpty ? nil : tags
    )

    feedback.clickupTaskURL = response.url
    feedback.clickupTaskId = response.id
    try await feedback.save(on: req.db)

    // Sync initial vote count if votes field is configured
    if let votesFieldId = project.clickupVotesFieldId {
        Task {
            try? await req.clickupService.setCustomFieldValue(
                taskId: response.id,
                fieldId: votesFieldId,
                token: token,
                value: feedback.voteCount
            )
        }
    }

    return CreateClickUpTaskResponseDTO(
        feedbackId: feedback.id!,
        taskUrl: response.url,
        taskId: response.id
    )
}

@Sendable
func bulkCreateClickUpTasks(req: Request) async throws -> BulkCreateClickUpTasksResponseDTO {
    let user = try req.auth.require(User.self)
    let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

    guard let token = project.clickupToken,
          let listId = project.clickupListId else {
        throw Abort(.badRequest, reason: "ClickUp integration not configured")
    }

    let dto = try req.content.decode(BulkCreateClickUpTasksDTO.self)

    var created: [CreateClickUpTaskResponseDTO] = []
    var failed: [UUID] = []

    for feedbackId in dto.feedbackIds {
        do {
            guard let feedback = try await Feedback.query(on: req.db)
                .filter(\.$id == feedbackId)
                .filter(\.$project.$id == project.id!)
                .with(\.$votes)
                .first() else {
                failed.append(feedbackId)
                continue
            }

            if feedback.clickupTaskURL != nil {
                failed.append(feedbackId)
                continue
            }

            var tags = project.clickupDefaultTags ?? []
            if let additional = dto.additionalTags {
                tags.append(contentsOf: additional)
            }
            tags.append(feedback.category.rawValue)

            // Calculate MRR
            let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
            let sdkUsers = try await SDKUser.query(on: req.db)
                .filter(\.$project.$id == project.id!)
                .filter(\.$userId ~~ Array(allUserIds))
                .all()
            let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

            var totalMrr: Double = 0
            if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
                totalMrr += creatorMrr
            }
            for vote in feedback.votes {
                if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                    totalMrr += voterMrr
                }
            }

            let description = req.clickupService.buildTaskDescription(
                feedback: feedback,
                projectName: project.name,
                voteCount: feedback.voteCount,
                mrr: totalMrr > 0 ? totalMrr : nil
            )

            let response = try await req.clickupService.createTask(
                listId: listId,
                token: token,
                name: feedback.title,
                markdownDescription: description,
                tags: tags.isEmpty ? nil : tags
            )

            feedback.clickupTaskURL = response.url
            feedback.clickupTaskId = response.id
            try await feedback.save(on: req.db)

            created.append(CreateClickUpTaskResponseDTO(
                feedbackId: feedback.id!,
                taskUrl: response.url,
                taskId: response.id
            ))
        } catch {
            req.logger.error("Failed to create ClickUp task for \(feedbackId): \(error)")
            failed.append(feedbackId)
        }
    }

    return BulkCreateClickUpTasksResponseDTO(created: created, failed: failed)
}

// Hierarchy endpoints for settings UI
@Sendable
func getClickUpWorkspaces(req: Request) async throws -> [ClickUpWorkspaceDTO] {
    let user = try req.auth.require(User.self)
    let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

    guard let token = project.clickupToken else {
        throw Abort(.badRequest, reason: "ClickUp token not configured")
    }

    let workspaces = try await req.clickupService.getWorkspaces(token: token)
    return workspaces.map { ClickUpWorkspaceDTO(id: $0.id, name: $0.name) }
}

// Similar implementations for getClickUpSpaces, getClickUpFolders, getClickUpLists, getClickUpFolderlessLists...

@Sendable
func getClickUpCustomFields(req: Request) async throws -> [ClickUpCustomFieldDTO] {
    let user = try req.auth.require(User.self)
    let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

    guard let token = project.clickupToken,
          let listId = project.clickupListId else {
        throw Abort(.badRequest, reason: "ClickUp integration not configured")
    }

    let fields = try await req.clickupService.getListCustomFields(listId: listId, token: token)
    // Filter to only return number fields (suitable for vote count)
    return fields
        .filter { $0.type == "number" }
        .map { ClickUpCustomFieldDTO(id: $0.id, name: $0.name, type: $0.type) }
}
```

---

### Phase 5: Admin App Updates

#### Models

```swift
// Add to SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Models/ProjectModels.swift

// In Project struct, add:
let clickupToken: String?
let clickupListId: String?
let clickupWorkspaceName: String?
let clickupListName: String?
let clickupDefaultTags: [String]?
let clickupSyncStatus: Bool
let clickupSyncComments: Bool
let clickupVotesFieldId: String?

var isClickUpConfigured: Bool {
    clickupToken != nil && clickupListId != nil
}

// Add request/response types
struct UpdateProjectClickUpRequest: Encodable {
    let clickupToken: String?
    let clickupListId: String?
    let clickupWorkspaceName: String?
    let clickupListName: String?
    let clickupDefaultTags: [String]?
    let clickupSyncStatus: Bool?
    let clickupSyncComments: Bool?
    let clickupVotesFieldId: String?
}

struct CreateClickUpTaskRequest: Encodable {
    let feedbackId: UUID
    let additionalTags: [String]?
}

struct CreateClickUpTaskResponse: Decodable {
    let feedbackId: UUID
    let taskUrl: String
    let taskId: String
}

struct BulkCreateClickUpTasksRequest: Encodable {
    let feedbackIds: [UUID]
    let additionalTags: [String]?
}

struct BulkCreateClickUpTasksResponse: Decodable {
    let created: [CreateClickUpTaskResponse]
    let failed: [UUID]
}

// ClickUp hierarchy models
struct ClickUpWorkspace: Codable, Identifiable {
    let id: String
    let name: String
}

struct ClickUpSpace: Codable, Identifiable {
    let id: String
    let name: String
}

struct ClickUpFolder: Codable, Identifiable {
    let id: String
    let name: String
}

struct ClickUpList: Codable, Identifiable {
    let id: String
    let name: String
}

struct ClickUpCustomField: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
}
```

#### Add to FeedbackModels.swift

```swift
// Add to Feedback struct:
let clickupTaskUrl: String?
let clickupTaskId: String?

var hasClickUpTask: Bool {
    clickupTaskUrl != nil
}
```

#### ClickUpSettingsView

```swift
// SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Views/Projects/ClickUpSettingsView.swift

import SwiftUI

struct ClickUpSettingsView: View {
    let project: Project
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var token: String
    @State private var selectedListId: String
    @State private var selectedListName: String
    @State private var selectedWorkspaceName: String
    @State private var defaultTags: String
    @State private var syncStatus: Bool
    @State private var showingTokenInfo = false

    // Hierarchy selection states
    @State private var workspaces: [ClickUpWorkspace] = []
    @State private var spaces: [ClickUpSpace] = []
    @State private var folders: [ClickUpFolder] = []
    @State private var lists: [ClickUpList] = []
    @State private var selectedWorkspaceId: String = ""
    @State private var selectedSpaceId: String = ""
    @State private var selectedFolderId: String = ""
    @State private var isLoadingHierarchy = false

    // New: Comment sync and vote field
    @State private var syncComments: Bool
    @State private var customFields: [ClickUpCustomField] = []
    @State private var selectedVotesFieldId: String

    init(project: Project, viewModel: ProjectViewModel) {
        self.project = project
        self.viewModel = viewModel
        _token = State(initialValue: project.clickupToken ?? "")
        _selectedListId = State(initialValue: project.clickupListId ?? "")
        _selectedListName = State(initialValue: project.clickupListName ?? "")
        _selectedWorkspaceName = State(initialValue: project.clickupWorkspaceName ?? "")
        _defaultTags = State(initialValue: (project.clickupDefaultTags ?? []).joined(separator: ", "))
        _syncStatus = State(initialValue: project.clickupSyncStatus)
        _syncComments = State(initialValue: project.clickupSyncComments)
        _selectedVotesFieldId = State(initialValue: project.clickupVotesFieldId ?? "")
    }

    private var hasChanges: Bool {
        token != (project.clickupToken ?? "") ||
        selectedListId != (project.clickupListId ?? "") ||
        tagsArray != (project.clickupDefaultTags ?? []) ||
        syncStatus != project.clickupSyncStatus ||
        syncComments != project.clickupSyncComments ||
        selectedVotesFieldId != (project.clickupVotesFieldId ?? "")
    }

    private var isConfigured: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedListId.isEmpty
    }

    private var tagsArray: [String] {
        defaultTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Personal API Token", text: $token)

                    Button {
                        showingTokenInfo = true
                    } label: {
                        Label("How to get a token", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Generate a token at ClickUp Settings > Apps > API Token")
                }

                if !token.isEmpty {
                    Section {
                        if isLoadingHierarchy {
                            ProgressView()
                        } else {
                            // Workspace picker
                            Picker("Workspace", selection: $selectedWorkspaceId) {
                                Text("Select...").tag("")
                                ForEach(workspaces) { workspace in
                                    Text(workspace.name).tag(workspace.id)
                                }
                            }
                            .onChange(of: selectedWorkspaceId) { _, newValue in
                                if !newValue.isEmpty {
                                    loadSpaces(workspaceId: newValue)
                                }
                            }

                            // Space picker
                            if !selectedWorkspaceId.isEmpty {
                                Picker("Space", selection: $selectedSpaceId) {
                                    Text("Select...").tag("")
                                    ForEach(spaces) { space in
                                        Text(space.name).tag(space.id)
                                    }
                                }
                                .onChange(of: selectedSpaceId) { _, newValue in
                                    if !newValue.isEmpty {
                                        loadFolders(spaceId: newValue)
                                    }
                                }
                            }

                            // Folder picker (optional)
                            if !selectedSpaceId.isEmpty {
                                Picker("Folder (optional)", selection: $selectedFolderId) {
                                    Text("No folder").tag("")
                                    ForEach(folders) { folder in
                                        Text(folder.name).tag(folder.id)
                                    }
                                }
                                .onChange(of: selectedFolderId) { _, newValue in
                                    loadLists(folderId: newValue.isEmpty ? nil : newValue, spaceId: selectedSpaceId)
                                }
                            }

                            // List picker
                            if !lists.isEmpty {
                                Picker("List", selection: $selectedListId) {
                                    Text("Select...").tag("")
                                    ForEach(lists) { list in
                                        Text(list.name).tag(list.id)
                                    }
                                }
                                .onChange(of: selectedListId) { _, newValue in
                                    if let list = lists.first(where: { $0.id == newValue }) {
                                        selectedListName = list.name
                                    }
                                    if let workspace = workspaces.first(where: { $0.id == selectedWorkspaceId }) {
                                        selectedWorkspaceName = workspace.name
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Target List")
                    } footer: {
                        Text("Select the ClickUp List where tasks will be created.")
                    }
                }

                Section {
                    TextField("Tags (comma-separated)", text: $defaultTags)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text("Default Tags")
                } footer: {
                    Text("Tags to apply to all created tasks. Feedback category is added automatically.")
                }

                Section {
                    Toggle("Sync status changes", isOn: $syncStatus)
                    Toggle("Sync comments", isOn: $syncComments)
                } header: {
                    Text("Sync Options")
                } footer: {
                    Text("Status sync updates ClickUp task status when feedback status changes. Comment sync pushes SwiftlyFeedback comments to ClickUp tasks.")
                }

                // Vote count custom field (optional)
                if isConfigured {
                    Section {
                        Picker("Votes Field", selection: $selectedVotesFieldId) {
                            Text("None (don't sync votes)").tag("")
                            ForEach(customFields) { field in
                                Text(field.name).tag(field.id)
                            }
                        }
                    } header: {
                        Text("Vote Count Sync (Optional)")
                    } footer: {
                        Text("Select a Number custom field to sync vote counts. Create a 'Votes' number field in your ClickUp List first.")
                    }
                    .task {
                        await loadCustomFields()
                    }
                }

                if isConfigured {
                    Section {
                        Button(role: .destructive) {
                            token = ""
                            selectedListId = ""
                            selectedListName = ""
                            selectedWorkspaceName = ""
                            defaultTags = ""
                            syncStatus = false
                            syncComments = false
                            selectedVotesFieldId = ""
                            workspaces = []
                            spaces = []
                            folders = []
                            lists = []
                            customFields = []
                        } label: {
                            Label("Remove ClickUp Integration", systemImage: "trash")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("ClickUp Integration")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges || viewModel.isLoading)
                }
            }
            .task {
                if !token.isEmpty {
                    await loadWorkspaces()
                }
            }
            .onChange(of: token) { _, newValue in
                if !newValue.isEmpty && workspaces.isEmpty {
                    Task {
                        await loadWorkspaces()
                    }
                }
            }
            .alert("Get Your API Token", isPresented: $showingTokenInfo) {
                Button("Open ClickUp") {
                    if let url = URL(string: "https://app.clickup.com/settings/apps") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Go to ClickUp Settings > Apps > API Token. Click 'Generate' to create a new token. Copy the token (starts with 'pk_').")
            }
        }
    }

    private func loadWorkspaces() async {
        // Implementation calls API to fetch workspaces
    }

    private func loadSpaces(workspaceId: String) {
        // Implementation calls API to fetch spaces
    }

    private func loadFolders(spaceId: String) {
        // Implementation calls API to fetch folders
    }

    private func loadLists(folderId: String?, spaceId: String) {
        // Implementation calls API to fetch lists
    }

    private func loadCustomFields() async {
        // Implementation calls API to fetch number custom fields for the selected list
        // customFields = await viewModel.getClickUpCustomFields(projectId: project.id)
    }

    private func saveSettings() {
        Task {
            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

            let success = await viewModel.updateClickUpSettings(
                projectId: project.id,
                clickupToken: trimmedToken.isEmpty ? "" : trimmedToken,
                clickupListId: selectedListId.isEmpty ? "" : selectedListId,
                clickupWorkspaceName: selectedWorkspaceName.isEmpty ? "" : selectedWorkspaceName,
                clickupListName: selectedListName.isEmpty ? "" : selectedListName,
                clickupDefaultTags: tagsArray.isEmpty ? [] : tagsArray,
                clickupSyncStatus: syncStatus,
                clickupSyncComments: syncComments,
                clickupVotesFieldId: selectedVotesFieldId.isEmpty ? "" : selectedVotesFieldId
            )
            if success {
                dismiss()
            }
        }
    }
}
```

---

### Phase 6: Comment Sync

When a comment is added to feedback in SwiftlyFeedback, push it to the linked ClickUp task.

Add to `CommentController.swift` (or wherever comments are created):

```swift
// After successfully creating a comment on feedback:

// Sync comment to ClickUp if enabled
if project.clickupSyncComments,
   let taskId = feedback.clickupTaskId,
   let token = project.clickupToken {

    // Build comment text with context
    let commenterType = comment.isAdmin ? "Admin" : "User"
    let commenterName = comment.authorName ?? "Anonymous"
    let commentText = """
    **[\(commenterType)] \(commenterName):**

    \(comment.content)

    ---
    _Synced from SwiftlyFeedback_
    """

    Task {
        try? await req.clickupService.createTaskComment(
            taskId: taskId,
            token: token,
            commentText: commentText,
            notifyAll: false
        )
    }
}
```

**Comment Format in ClickUp:**
```
**[Admin] John Doe:**

Thanks for the feedback! We're looking into this.

---
_Synced from SwiftlyFeedback_
```

---

### Phase 7: Vote Count Sync

When a vote is added or removed from feedback, update the ClickUp custom field.

Add to `VoteController.swift` (or wherever votes are created/deleted):

```swift
// After vote is added or removed:

// Sync vote count to ClickUp if configured
if let votesFieldId = project.clickupVotesFieldId,
   let taskId = feedback.clickupTaskId,
   let token = project.clickupToken {

    // Recalculate vote count
    let voteCount = try await Vote.query(on: req.db)
        .filter(\.$feedback.$id == feedback.id!)
        .count()

    Task {
        try? await req.clickupService.setCustomFieldValue(
            taskId: taskId,
            fieldId: votesFieldId,
            token: token,
            value: voteCount
        )
    }
}
```

**Setup Requirements:**
1. Create a **Number** custom field in the target ClickUp List (e.g., named "Votes")
2. In SwiftlyFeedback Admin app, select this field in ClickUp Integration settings
3. Vote count will sync automatically when votes change

**Note:** ClickUp's native Voting field cannot be set via API. This uses a standard Number field as a workaround.

---

### Phase 8: Status Sync (Optional Feature)

Add to `FeedbackController.swift` when updating feedback status:

```swift
// In updateFeedback function, after status change:
if let newStatus = dto.status,
   newStatus != existingStatus,
   project.clickupSyncStatus,
   let taskId = feedback.clickupTaskId,
   let token = project.clickupToken {

    // Map SwiftlyFeedback status to ClickUp status
    let clickupStatus: String
    switch newStatus {
    case .completed:
        clickupStatus = "complete"  // Adjust based on ClickUp List settings
    case .rejected:
        clickupStatus = "closed"
    case .inProgress:
        clickupStatus = "in progress"
    case .approved:
        clickupStatus = "to do"
    default:
        clickupStatus = "open"
    }

    Task {
        try? await req.clickupService.updateTaskStatus(
            taskId: taskId,
            token: token,
            status: clickupStatus
        )
    }
}
```

**Note:** ClickUp status names are customizable per List. Consider either:
1. Using standard status names and documenting requirements
2. Adding status mapping configuration to the project settings

---

## API Endpoints Summary

| Method | Endpoint | Description |
|--------|----------|-------------|
| `PATCH` | `/projects/:id/clickup` | Update ClickUp settings |
| `POST` | `/projects/:id/clickup/task` | Create single task |
| `POST` | `/projects/:id/clickup/tasks` | Bulk create tasks |
| `GET` | `/projects/:id/clickup/workspaces` | Get workspaces (for settings) |
| `GET` | `/projects/:id/clickup/spaces/:workspaceId` | Get spaces |
| `GET` | `/projects/:id/clickup/folders/:spaceId` | Get folders |
| `GET` | `/projects/:id/clickup/lists/:folderId` | Get lists in folder |
| `GET` | `/projects/:id/clickup/folderless-lists/:spaceId` | Get folderless lists |
| `GET` | `/projects/:id/clickup/custom-fields` | Get number custom fields (for vote sync) |

---

## Implementation Checklist

### Server (SwiftlyFeedbackServer)

- [ ] Create migration `AddProjectClickUpIntegration`
- [ ] Add ClickUp fields to `Project` model (including `clickupSyncComments`, `clickupVotesFieldId`)
- [ ] Add ClickUp fields to `Feedback` model
- [ ] Create `ClickUpService.swift` with all methods:
  - [ ] `createTask`
  - [ ] `updateTaskStatus`
  - [ ] `createTaskComment`
  - [ ] `setCustomFieldValue`
  - [ ] `getListCustomFields`
  - [ ] Hierarchy methods (workspaces, spaces, folders, lists)
- [ ] Add ClickUp DTOs to `ProjectDTO.swift`
- [ ] Add ClickUp endpoints to `ProjectController.swift`
- [ ] Register routes in `boot` method
- [ ] Add migration to `configure.swift`
- [ ] Update `ProjectResponseDTO` to include ClickUp fields
- [ ] Update `FeedbackResponseDTO` to include ClickUp fields
- [ ] Add comment sync to `CommentController.swift`
- [ ] Add vote count sync to `VoteController.swift`
- [ ] (Optional) Add status sync to `FeedbackController.swift`

### Admin App (SwiftlyFeedbackAdmin)

- [ ] Update `Project` model with ClickUp fields (including sync options)
- [ ] Update `Feedback` model with ClickUp fields
- [ ] Add ClickUp request/response models
- [ ] Add ClickUp hierarchy models
- [ ] Add `ClickUpCustomField` model
- [ ] Create `ClickUpSettingsView.swift` with:
  - [ ] Token input
  - [ ] Hierarchy pickers (Workspace → Space → Folder → List)
  - [ ] Default tags input
  - [ ] Status sync toggle
  - [ ] Comment sync toggle
  - [ ] Vote field picker (number custom fields)
- [ ] Add API methods to `AdminAPIClient.swift`
- [ ] Add ClickUp methods to `ProjectViewModel.swift`
- [ ] Add ClickUp methods to `FeedbackViewModel.swift`
- [ ] Add "ClickUp Integration" menu item to `ProjectDetailView`
- [ ] Add "Push to ClickUp" context menu to feedback items
- [ ] Add ClickUp badge to feedback cards
- [ ] Add bulk "Push to ClickUp" button to selection action bar

### Documentation

- [ ] Update `CLAUDE.md` with ClickUp integration section
- [ ] Update `SwiftlyFeedbackServer/CLAUDE.md`
- [ ] Update `SwiftlyFeedbackAdmin/CLAUDE.md`

---

## Comparison: GitHub vs ClickUp Integration

| Aspect | GitHub | ClickUp |
|--------|--------|---------|
| Auth | Personal Access Token | Personal API Token |
| Target | Repository | List (within Workspace > Space > Folder) |
| Item Created | Issue | Task |
| Configuration | owner, repo, token | token, list_id |
| Labels/Tags | Labels array | Tags array |
| Status Sync | Close/Reopen issue | Update task status |
| Comment Sync | Not implemented | Push comments to task |
| Vote Count Sync | Not implemented | Update number custom field |
| Link Stored | `github_issue_url`, `github_issue_number` | `clickup_task_url`, `clickup_task_id` |

---

## Security Considerations

1. **Token Storage**: ClickUp tokens are stored in the database like GitHub tokens. Consider encryption at rest.
2. **Token Scope**: Personal tokens have full access to user's ClickUp. Document this for users.
3. **Rate Limiting**: Implement client-side rate limiting to avoid hitting ClickUp limits.

---

## Sources

- [ClickUp API - Create Task](https://developer.clickup.com/reference/createtask)
- [ClickUp API - Create Task Comment](https://developer.clickup.com/reference/createtaskcomment)
- [ClickUp API - Set Custom Field Value](https://developer.clickup.com/reference/setcustomfieldvalue)
- [ClickUp API - Custom Fields Documentation](https://developer.clickup.com/docs/customfields)
- [ClickUp API - Comments Documentation](https://developer.clickup.com/docs/comments)
- [ClickUp API - Authentication](https://developer.clickup.com/docs/authentication)
- [ClickUp API - Tasks Documentation](https://developer.clickup.com/docs/tasks)
- [ClickUp API - Get Folderless Lists](https://clickup.com/api/clickupreference/operation/GetFolderlessLists/)
- [ClickUp Hierarchy Introduction](https://help.clickup.com/hc/en-us/articles/13856392825367-Intro-to-the-Hierarchy)
- [ClickUp Voting Custom Fields](https://help.clickup.com/hc/en-us/articles/24266511749527-Use-Voting-Custom-Fields)
- [ClickUp API Guide - Zuplo](https://zuplo.com/learning-center/clickup-api)
