//
//  ContextBuilder.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import MCP

/// Phase 1 of the agent loop: queries MCP resources to build a context map.
///
/// Iterates through all connected MCP servers and collects their available
/// resources to give the planning agent situational awareness.
struct ContextBuilder {

    let mcpHost: MCPHost

    // MARK: - ContextMap

    /// A snapshot of available MCP resources and a human-readable summary.
    struct ContextMap {
        var resources: [(serverName: String, uri: String, description: String)] = []
        var summary: String = ""
    }

    // MARK: - Building

    /// List available resources from all connected MCP servers.
    ///
    /// Errors from individual servers are silently swallowed — a partial
    /// context map is still useful for planning.
    func buildContextMap(for prompt: String) async -> ContextMap {
        var map = ContextMap()
        var summaryLines: [String] = []

        for (serverName, connection) in await mcpHost.connections {
            guard connection.isConnected else { continue }

            do {
                let resources = try await connection.listResources()
                for resource in resources {
                    let description = resource.description ?? resource.name
                    map.resources.append((
                        serverName: serverName,
                        uri: resource.uri,
                        description: description
                    ))
                    summaryLines.append("[\(serverName)] \(resource.uri): \(description)")
                }
            } catch {
                // Resource listing is best-effort
                summaryLines.append("[\(serverName)] (resource listing unavailable: \(error.localizedDescription))")
            }
        }

        if summaryLines.isEmpty {
            map.summary = "No MCP resources are currently available."
        } else {
            map.summary = "Available MCP resources:\n" + summaryLines.joined(separator: "\n")
        }

        return map
    }
}
