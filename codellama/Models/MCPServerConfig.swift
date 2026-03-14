//
//  MCPServerConfig.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import SwiftData

/// A persisted configuration for a single MCP (Model Context Protocol) server.
///
/// Each config stores the command, arguments, and optional environment variables
/// needed to spawn and manage a stdio-based MCP server process.
@Model
final class MCPServerConfig: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()

    /// A human-readable name for this server (e.g. "filesystem", "github").
    var name: String

    /// The executable command to run (e.g. "npx" or "/usr/local/bin/mcp-server").
    var command: String

    /// Command-line arguments to pass to the server process.
    var arguments: [String]

    /// JSON-encoded `[String: String]` environment variables for the subprocess.
    var environmentJSON: Data?

    /// Whether this server should be auto-connected at startup.
    var isEnabled: Bool = true

    var createdAt: Date = Date.now

    // MARK: - Computed Properties

    /// Decoded environment variables, or nil if none are configured.
    @Transient
    var environment: [String: String]? {
        get {
            guard let data = environmentJSON else { return nil }
            return try? JSONDecoder().decode([String: String].self, from: data)
        }
        set {
            if let newValue {
                environmentJSON = try? JSONEncoder().encode(newValue)
            } else {
                environmentJSON = nil
            }
        }
    }

    // MARK: - Init

    init(
        name: String,
        command: String,
        arguments: [String],
        environment: [String: String]? = nil
    ) {
        self.name = name
        self.command = command
        self.arguments = arguments
        if let environment {
            self.environmentJSON = try? JSONEncoder().encode(environment)
        }
    }
}
