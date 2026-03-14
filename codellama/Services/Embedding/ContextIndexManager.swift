//
//  ContextIndexManager.swift
//  codellama
//
//  Created by Codex on 3/14/26.
//

import Foundation
import Defaults

@MainActor
@Observable
final class ContextIndexManager {
    private(set) var attachedFolders: [String]
    private(set) var indexedFileCount: Int = 0
    private(set) var lastIndexedAt: Date?
    private(set) var isIndexing: Bool = false
    private(set) var statusMessage: String = "No folders attached."
    private(set) var lastError: String?

    let vectorStore: VectorStore

    private let fileManager = FileManager.default
    private let supportedExtensions: Set<String> = [
        "c", "cc", "cpp", "css", "go", "h", "hpp", "html", "java", "js", "json", "jsx",
        "md", "mjs", "py", "rb", "rs", "sh", "sql", "swift", "toml", "ts", "tsx", "txt",
        "xml", "yaml", "yml"
    ]
    private let maxFileSizeBytes = 512_000

    init(vectorStore: VectorStore = VectorStore()) {
        self.vectorStore = vectorStore
        self.attachedFolders = Defaults[.indexedFolderPaths]
        if !attachedFolders.isEmpty {
            self.statusMessage = "Ready to index \(attachedFolders.count) folder(s)."
        }
    }

    func addFolder(_ path: String, ollamaClient: OllamaClient?, embeddingModel: String) async {
        guard !attachedFolders.contains(path) else { return }
        attachedFolders.append(path)
        attachedFolders.sort()
        Defaults[.indexedFolderPaths] = attachedFolders
        await reindexLocalFolders(using: ollamaClient, embeddingModel: embeddingModel)
    }

    func removeFolder(_ path: String, ollamaClient: OllamaClient?, embeddingModel: String) async {
        attachedFolders.removeAll { $0 == path }
        Defaults[.indexedFolderPaths] = attachedFolders
        await reindexLocalFolders(using: ollamaClient, embeddingModel: embeddingModel)
    }

    func reindexLocalFolders(using ollamaClient: OllamaClient?, embeddingModel: String) async {
        guard let ollamaClient else {
            statusMessage = attachedFolders.isEmpty
                ? "No folders attached."
                : "Ollama is unavailable. Start Ollama before indexing."
            lastError = attachedFolders.isEmpty ? nil : "Ollama is unavailable."
            return
        }

        guard !attachedFolders.isEmpty else {
            indexedFileCount = 0
            try? await vectorStore.removeResources(serverName: "local")
            statusMessage = "No folders attached."
            lastError = nil
            return
        }

        isIndexing = true
        lastError = nil
        statusMessage = "Indexing \(attachedFolders.count) folder(s)…"
        indexedFileCount = 0

        let embeddingService = EmbeddingService(ollamaClient: ollamaClient)
        let chunkIndexer = ChunkIndexer(embeddingService: embeddingService, vectorStore: vectorStore)

        var filesByFolder: [(folderURL: URL, fileURLs: [URL])] = []
        var discoveredLocalURIs: Set<String> = []

        for folderPath in attachedFolders {
            let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
            let fileURLs = discoverIndexableFiles(in: folderURL)
            filesByFolder.append((folderURL: folderURL, fileURLs: fileURLs))
            discoveredLocalURIs.formUnion(fileURLs.map(\.absoluteString))
        }

        try? await vectorStore.pruneResources(serverName: "local", keepingURIs: discoveredLocalURIs)

        var totalIndexedFiles = 0
        var failures: [String] = []

        for (folderURL, fileURLs) in filesByFolder {
            for fileURL in fileURLs {
                do {
                    let content = try readTextFile(at: fileURL)
                    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                    try await chunkIndexer.indexResource(
                        serverName: "local",
                        uri: fileURL.absoluteString,
                        description: displayPath(for: fileURL, relativeTo: folderURL),
                        text: content,
                        model: embeddingModel
                    )
                    totalIndexedFiles += 1
                } catch {
                    failures.append("\(fileURL.path): \(error.localizedDescription)")
                }
            }
        }

        indexedFileCount = totalIndexedFiles
        lastIndexedAt = Date.now
        isIndexing = false

        if failures.isEmpty {
            statusMessage = "Indexed \(totalIndexedFiles) file(s) from \(attachedFolders.count) folder(s)."
            lastError = nil
        } else {
            statusMessage = "Indexed \(totalIndexedFiles) file(s) with \(failures.count) error(s)."
            lastError = failures.prefix(5).joined(separator: "\n")
        }
    }

    private func discoverIndexableFiles(in folderURL: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let fileURL as URL in enumerator {
            guard shouldIndex(fileURL) else { continue }
            urls.append(fileURL)
        }
        return urls
    }

    private func shouldIndex(_ fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else { return false }

        let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values?.isRegularFile == true else { return false }

        if let size = values?.fileSize, size > maxFileSizeBytes {
            return false
        }

        return true
    }

    private func readTextFile(at fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        for encoding in [String.Encoding.utf8, .utf16, .ascii, .isoLatin1] {
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }

        throw ContextIndexError.unsupportedEncoding(fileURL.path)
    }

    private func displayPath(for fileURL: URL, relativeTo folderURL: URL) -> String {
        let folderPath = folderURL.path(percentEncoded: false)
        let filePath = fileURL.path(percentEncoded: false)

        if filePath.hasPrefix(folderPath + "/") {
            return String(filePath.dropFirst(folderPath.count + 1))
        }

        return fileURL.lastPathComponent
    }
}

enum ContextIndexError: LocalizedError {
    case unsupportedEncoding(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedEncoding(let path):
            return "Could not decode text file: \(path)"
        }
    }
}
