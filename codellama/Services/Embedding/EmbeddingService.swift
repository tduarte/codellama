//
//  EmbeddingService.swift
//  codellama
//
//  Created by Codex on 3/14/26.
//

import Foundation

/// Thin wrapper around Ollama's embeddings endpoint.
actor EmbeddingService {
    private let ollamaClient: OllamaClient

    init(ollamaClient: OllamaClient) {
        self.ollamaClient = ollamaClient
    }

    func embedding(for text: String, model: String) async throws -> [Double] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let response = try await ollamaClient.embed(
            request: OllamaEmbeddingsRequest(model: model, prompt: trimmed)
        )

        return response.embedding
    }
}
