//
//  Defaults+Keys.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import Defaults

/// Application-wide user defaults keys managed by the `Defaults` library.
extension Defaults.Keys {
    /// The base URL of the Ollama server (e.g., `http://localhost:11434`).
    static let ollamaHost = Key<String>("ollamaHost", default: "http://localhost:11434")

    /// The default model identifier used for new conversations.
    static let defaultModel = Key<String>("defaultModel", default: "llama3.1:8b")

    /// The embedding model identifier used for local RAG indexing.
    static let embeddingModel = Key<String>("embeddingModel", default: "nomic-embed-text")

    /// The system prompt prepended to every new conversation.
    static let systemPrompt = Key<String>("systemPrompt", default: "You are a helpful coding assistant.")

    /// Whether to stream responses token-by-token from the Ollama API.
    static let streamResponses = Key<Bool>("streamResponses", default: true)
}
