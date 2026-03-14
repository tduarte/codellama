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
    let embeddingService: EmbeddingService?
    let vectorStore: VectorStore?

    // MARK: - ContextMap

    /// A snapshot of available MCP resources and a human-readable summary.
    struct ContextMap {
        var resources: [(serverName: String, uri: String, description: String)] = []
        var indexedChunkCount: Int = 0
        var relevantContext: [String] = []
        var summary: String = ""
    }

    // MARK: - Building

    /// List available resources from all connected MCP servers.
    ///
    /// Errors from individual servers are silently swallowed — a partial
    /// context map is still useful for planning.
    func buildContextMap(for prompt: String, embeddingModel: String? = nil) async -> ContextMap {
        var map = ContextMap()
        var summaryLines: [String] = []
        var ragErrors: [String] = []
        let chunkIndexer = makeChunkIndexer()

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

                    guard let chunkIndexer, let embeddingModel else { continue }

                    do {
                        let resourceText = try await connection.readResource(uri: resource.uri)
                        try await chunkIndexer.indexResource(
                            serverName: serverName,
                            uri: resource.uri,
                            description: description,
                            text: resourceText,
                            model: embeddingModel
                        )
                    } catch {
                        ragErrors.append("[\(serverName)] \(resource.uri): \(error.localizedDescription)")
                    }
                }
            } catch {
                // Resource listing is best-effort
                summaryLines.append("[\(serverName)] (resource listing unavailable: \(error.localizedDescription))")
            }
        }

        if let vectorStore {
            map.indexedChunkCount = await vectorStore.indexedChunkCount()

            if let embeddingService,
               let embeddingModel,
               !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                do {
                    let promptEmbedding = try await embeddingService.embedding(for: prompt, model: embeddingModel)
                    let matches = await vectorStore.search(promptEmbedding)
                    map.relevantContext = matches.map { match in
                        let snippet = match.entry.text.replacingOccurrences(of: "\n", with: " ")
                        let preview = snippet.count > 280 ? String(snippet.prefix(280)) + "…" : snippet
                        return String(
                            format: "[%@] %@ (score %.2f): %@",
                            match.entry.serverName,
                            match.entry.resourceURI,
                            match.score,
                            preview
                        )
                    }
                } catch {
                    ragErrors.append("Embedding query failed: \(error.localizedDescription)")
                }
            }
        }

        if summaryLines.isEmpty {
            map.summary = "No MCP resources are currently available."
        } else {
            map.summary = "Available MCP resources:\n" + summaryLines.joined(separator: "\n")
        }

        if map.indexedChunkCount > 0 {
            map.summary += "\n\nIndexed resource chunks: \(map.indexedChunkCount)"
        }

        if !map.relevantContext.isEmpty {
            map.summary += "\n\nRelevant indexed context:\n" + map.relevantContext.joined(separator: "\n")
        }

        if !ragErrors.isEmpty {
            map.summary += "\n\nRAG indexing notes:\n" + ragErrors.joined(separator: "\n")
        }

        return map
    }

    private func makeChunkIndexer() -> ChunkIndexer? {
        guard let embeddingService, let vectorStore else { return nil }
        return ChunkIndexer(embeddingService: embeddingService, vectorStore: vectorStore)
    }
}
