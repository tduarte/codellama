//
//  ChunkIndexer.swift
//  codellama
//
//  Created by Codex on 3/14/26.
//

import CryptoKit
import Foundation

/// Splits MCP resource text into overlapping chunks and indexes them into the vector store.
struct ChunkIndexer {
    let embeddingService: EmbeddingService
    let vectorStore: VectorStore

    private let chunkSize: Int
    private let overlap: Int

    init(
        embeddingService: EmbeddingService,
        vectorStore: VectorStore,
        chunkSize: Int = 1_200,
        overlap: Int = 200
    ) {
        self.embeddingService = embeddingService
        self.vectorStore = vectorStore
        self.chunkSize = chunkSize
        self.overlap = overlap
    }

    func indexResource(
        serverName: String,
        uri: String,
        description: String,
        text: String,
        model: String
    ) async throws {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return }

        let chunks = split(text: normalizedText)
        guard !chunks.isEmpty else { return }

        var indexedChunks: [(chunkIndex: Int, text: String, embedding: [Double])] = []
        indexedChunks.reserveCapacity(chunks.count)

        for (chunkIndex, chunkText) in chunks.enumerated() {
            let embedding = try await embeddingService.embedding(for: chunkText, model: model)
            guard !embedding.isEmpty else { continue }
            indexedChunks.append((chunkIndex: chunkIndex, text: chunkText, embedding: embedding))
        }

        guard !indexedChunks.isEmpty else { return }

        await vectorStore.upsertResource(
            serverName: serverName,
            uri: uri,
            description: description,
            resourceFingerprint: fingerprint(for: normalizedText),
            chunks: indexedChunks
        )
    }

    private func split(text: String) -> [String] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [] }

        var chunks: [String] = []
        var start = 0
        let effectiveOverlap = min(overlap, max(chunkSize - 1, 0))

        while start < characters.count {
            let end = min(start + chunkSize, characters.count)
            let chunk = String(characters[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)

            if !chunk.isEmpty {
                chunks.append(chunk)
            }

            guard end < characters.count else { break }
            start = max(end - effectiveOverlap, start + 1)
        }

        return chunks
    }

    private func fingerprint(for text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
