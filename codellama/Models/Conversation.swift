//
//  Conversation.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import SwiftData

/// A persisted chat conversation containing an ordered sequence of messages.
///
/// Each conversation tracks the model used, an optional system prompt, and
/// cascade-deletes its child `ChatMessage` instances when removed.
@Model
final class Conversation: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var model: String
    var systemPrompt: String?
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage] = []

    init(title: String, model: String, systemPrompt: String? = nil) {
        self.title = title
        self.model = model
        self.systemPrompt = systemPrompt
    }
}
