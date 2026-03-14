//
//  Skill.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import SwiftData

/// A persisted user-defined skill — a named sequence of MCP tool calls
/// that can be invoked as a single unit by the agent.
///
/// `toolSequenceJSON` encodes `[ToolCall]` and is decoded lazily via the
/// `toolSequence` computed property.
@Model
final class Skill: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()

    /// Human-readable name shown in the Skills list (e.g. "Refactor Function").
    var name: String

    /// Optional description shown as a subtitle and surfaced to the agent as context.
    var descriptionText: String

    /// JSON-encoded `[ToolCall]` — the ordered sequence of MCP tool calls this skill executes.
    var toolSequenceJSON: Data

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // MARK: - Computed Properties

    /// Decoded tool sequence, or an empty array if decoding fails.
    @Transient
    var toolSequence: [ToolCall] {
        get {
            (try? JSONDecoder().decode([ToolCall].self, from: toolSequenceJSON)) ?? []
        }
        set {
            toolSequenceJSON = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = Date.now
        }
    }

    // MARK: - Init

    init(name: String, descriptionText: String = "", toolSequence: [ToolCall] = []) {
        self.name = name
        self.descriptionText = descriptionText
        self.toolSequenceJSON = (try? JSONEncoder().encode(toolSequence)) ?? Data()
    }
}
