//
//  ToolCall.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation

/// Represents a tool invocation requested by the assistant.
///
/// This is an app-level type (not SwiftData) that bridges between Ollama's
/// `OllamaToolCall` wire format and the persisted `ChatMessage.toolCallsJSON`.
struct ToolCall: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this tool call.
    let id: String

    /// The MCP server that owns the tool, if applicable.
    let serverName: String

    /// The name of the tool being invoked.
    let toolName: String

    /// The arguments to pass to the tool, keyed by parameter name.
    let arguments: [String: JSONValue]

    /// Best-effort heuristic used to identify discovery-style MCP calls that
    /// can be safely batched across different servers.
    var isLikelyReadOnly: Bool {
        let normalizedName = toolName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let readOnlyPrefixes = [
            "get",
            "list",
            "read",
            "search",
            "find",
            "fetch",
            "query",
            "show",
            "lookup",
            "stat"
        ]

        return readOnlyPrefixes.contains { prefix in
            normalizedName == prefix || normalizedName.hasPrefix(prefix + "_")
        }
    }
}
