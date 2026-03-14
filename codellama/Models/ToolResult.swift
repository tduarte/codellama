//
//  ToolResult.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation

/// The result returned after executing a `ToolCall`.
///
/// Contains the output content and whether the execution encountered an error,
/// along with a back-reference to the originating tool call via `toolCallId`.
struct ToolResult: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this result.
    let id: String

    /// The identifier of the `ToolCall` that produced this result.
    let toolCallId: String

    /// The textual output of the tool execution.
    let content: String

    /// `true` if the tool execution resulted in an error.
    let isError: Bool
}
