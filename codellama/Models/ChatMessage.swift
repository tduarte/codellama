//
//  ChatMessage.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import SwiftData

struct ChatImageAttachment: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let fileName: String
    let mimeType: String
    let base64Data: String

    init(id: UUID = UUID(), fileName: String, mimeType: String, base64Data: String) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.base64Data = base64Data
    }
}

/// A single message within a `Conversation`, persisted via SwiftData.
///
/// The `role` field uses raw strings (`"user"`, `"assistant"`, `"tool"`, `"system"`)
/// to stay compatible with the Ollama API without requiring a custom transformer.
///
/// Tool-calling assistant messages store their calls as JSON-encoded `Data`
/// in `toolCallsJSON`, accessible through the computed `toolCalls` property.
@Model
final class ChatMessage: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()

    /// The role of the message sender: `"user"`, `"assistant"`, `"tool"`, or `"system"`.
    var role: String

    /// The textual content of the message.
    var content: String

    /// JSON-encoded `[ToolCall]` for assistant messages that invoke tools.
    var toolCallsJSON: Data?

    /// Identifier linking a tool-result message back to its originating tool call.
    var toolCallId: String?

    /// JSON-encoded image attachments associated with this chat message.
    var imageAttachmentsJSON: Data?

    /// `true` while the assistant response is still being streamed.
    var isStreaming: Bool = false

    var createdAt: Date = Date.now

    @Relationship var conversation: Conversation?

    /// Decoded tool calls from `toolCallsJSON`, or an empty array if absent.
    @Transient
    var toolCalls: [ToolCall] {
        get {
            guard let data = toolCallsJSON else { return [] }
            return (try? JSONDecoder().decode([ToolCall].self, from: data)) ?? []
        }
        set {
            toolCallsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    @Transient
    var imageAttachments: [ChatImageAttachment] {
        get {
            guard let data = imageAttachmentsJSON else { return [] }
            return (try? JSONDecoder().decode([ChatImageAttachment].self, from: data)) ?? []
        }
        set {
            imageAttachmentsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        role: String,
        content: String,
        toolCallsJSON: Data? = nil,
        toolCallId: String? = nil,
        imageAttachmentsJSON: Data? = nil,
        isStreaming: Bool = false
    ) {
        self.role = role
        self.content = content
        self.toolCallsJSON = toolCallsJSON
        self.toolCallId = toolCallId
        self.imageAttachmentsJSON = imageAttachmentsJSON
        self.isStreaming = isStreaming
    }
}
