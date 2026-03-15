//
//  EmbeddingModelOption.swift
//  codellama
//
//  Created by Codex on 3/15/26.
//

import Foundation

struct EmbeddingModelOption: Identifiable, Hashable, Sendable {
    let storageValue: String?
    let title: String
    let subtitle: String
    let isCustom: Bool

    var id: String {
        storageValue ?? "__none__"
    }

    var modelName: String? {
        storageValue
    }

    static let none = EmbeddingModelOption(
        storageValue: nil,
        title: "None",
        subtitle: "Disable embeddings",
        isCustom: false
    )

    static let curated: [EmbeddingModelOption] = [
        .none,
        EmbeddingModelOption(storageValue: "nomic-embed-text", title: "nomic-embed-text", subtitle: "Small (274MB)", isCustom: false),
        EmbeddingModelOption(storageValue: "mxbai-embed-large", title: "mxbai-embed-large", subtitle: "Medium (670MB)", isCustom: false),
        EmbeddingModelOption(storageValue: "bge-m3", title: "bge-m3", subtitle: "Large (1.2GB)", isCustom: false),
        EmbeddingModelOption(storageValue: "all-minilm", title: "all-minilm", subtitle: "Small (46MB)", isCustom: false),
        EmbeddingModelOption(storageValue: "snowflake-arctic-embed", title: "snowflake-arctic-embed", subtitle: "Medium (669MB)", isCustom: false),
        EmbeddingModelOption(storageValue: "qwen3-embedding", title: "qwen3-embedding", subtitle: "Large (4.7GB)", isCustom: false)
    ]

    static func custom(_ value: String) -> EmbeddingModelOption {
        EmbeddingModelOption(
            storageValue: value,
            title: value,
            subtitle: "Current model",
            isCustom: true
        )
    }
}
