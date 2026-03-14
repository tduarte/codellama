//
//  VectorStore.swift
//  codellama
//
//  Created by Codex on 3/14/26.
//

import Foundation

/// In-memory vector store for indexed MCP resource chunks.
actor VectorStore {
    struct EmbeddingEntry: Identifiable, Sendable {
        let id: String
        let serverName: String
        let resourceURI: String
        let resourceDescription: String
        let chunkIndex: Int
        let text: String
        let embedding: [Double]
        let resourceFingerprint: String
        let createdAt: Date
    }

    struct SearchResult: Identifiable, Sendable {
        let entry: EmbeddingEntry
        let score: Double

        var id: String { entry.id }
    }

    private var entries: [EmbeddingEntry] = []
    private var resourceFingerprints: [String: String] = [:]

    func upsertResource(
        serverName: String,
        uri: String,
        description: String,
        resourceFingerprint: String,
        chunks: [(chunkIndex: Int, text: String, embedding: [Double])]
    ) {
        let key = resourceKey(serverName: serverName, uri: uri)
        guard resourceFingerprints[key] != resourceFingerprint else { return }

        entries.removeAll { $0.serverName == serverName && $0.resourceURI == uri }
        resourceFingerprints[key] = resourceFingerprint

        let now = Date.now
        let newEntries = chunks.map { chunk in
            EmbeddingEntry(
                id: "\(key)#\(chunk.chunkIndex)",
                serverName: serverName,
                resourceURI: uri,
                resourceDescription: description,
                chunkIndex: chunk.chunkIndex,
                text: chunk.text,
                embedding: chunk.embedding,
                resourceFingerprint: resourceFingerprint,
                createdAt: now
            )
        }

        entries.append(contentsOf: newEntries)
    }

    func search(_ queryEmbedding: [Double], topK: Int = 5, minimumScore: Double = 0.15) -> [SearchResult] {
        guard !queryEmbedding.isEmpty else { return [] }

        let results = entries.compactMap { entry -> SearchResult? in
            let score = cosineSimilarity(queryEmbedding, entry.embedding)
            guard score >= minimumScore else { return nil }
            return SearchResult(entry: entry, score: score)
        }

        return Array(results.sorted { $0.score > $1.score }.prefix(topK))
    }

    func indexedChunkCount() -> Int {
        entries.count
    }

    private func resourceKey(serverName: String, uri: String) -> String {
        "\(serverName)::\(uri)"
    }

    private func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }

        var dotProduct = 0.0
        var lhsMagnitude = 0.0
        var rhsMagnitude = 0.0

        for index in lhs.indices {
            dotProduct += lhs[index] * rhs[index]
            lhsMagnitude += lhs[index] * lhs[index]
            rhsMagnitude += rhs[index] * rhs[index]
        }

        guard lhsMagnitude > 0, rhsMagnitude > 0 else { return 0 }
        return dotProduct / (sqrt(lhsMagnitude) * sqrt(rhsMagnitude))
    }
}
