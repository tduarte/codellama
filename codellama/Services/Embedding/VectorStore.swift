//
//  VectorStore.swift
//  codellama
//
//  Created by Codex on 3/14/26.
//

import Foundation
import SQLite3

/// SQLite-backed vector store for indexed MCP resource chunks.
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

    private let databaseURL: URL
    private var database: OpaquePointer?
    private var fallbackEntries: [EmbeddingEntry] = []
    private var fallbackFingerprints: [String: String] = [:]

    init(databaseURL: URL? = nil) {
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()

        do {
            try Self.prepareDatabaseDirectory(for: self.databaseURL)
            self.database = try Self.openDatabase(at: self.databaseURL)
            try Self.configureDatabase(self.database)
            try Self.createSchema(in: self.database)
        } catch {
            self.database = nil
            NSLog("VectorStore falling back to in-memory storage: \(error.localizedDescription)")
        }
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func resourceFingerprint(serverName: String, uri: String) -> String? {
        let key = resourceKey(serverName: serverName, uri: uri)

        guard let database else {
            return fallbackFingerprints[key]
        }

        let sql = """
        SELECT resource_fingerprint
        FROM resources
        WHERE server_name = ? AND resource_uri = ?
        LIMIT 1;
        """

        guard let statement = try? Self.prepareStatement(sql, database: database) else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        Self.bindText(serverName, to: statement, at: 1)
        Self.bindText(uri, to: statement, at: 2)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let fingerprint = sqlite3_column_text(statement, 0).flatMap({ String(cString: $0) })
        else {
            return nil
        }

        return fingerprint
    }

    func upsertResource(
        serverName: String,
        uri: String,
        description: String,
        resourceFingerprint: String,
        chunks: [(chunkIndex: Int, text: String, embedding: [Double])]
    ) throws {
        let key = resourceKey(serverName: serverName, uri: uri)

        guard let database else {
            fallbackEntries.removeAll { $0.serverName == serverName && $0.resourceURI == uri }
            fallbackFingerprints[key] = resourceFingerprint

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
            fallbackEntries.append(contentsOf: newEntries)
            return
        }

        try Self.execute(sql: "BEGIN IMMEDIATE TRANSACTION;", database: database)
        var shouldCommit = false

        do {
            try deleteResource(serverName: serverName, uri: uri, database: database)
            try insertResource(
                serverName: serverName,
                uri: uri,
                description: description,
                resourceFingerprint: resourceFingerprint,
                updatedAt: Date.now,
                database: database
            )

            for chunk in chunks {
                try insertChunk(
                    serverName: serverName,
                    uri: uri,
                    description: description,
                    resourceFingerprint: resourceFingerprint,
                    chunkIndex: chunk.chunkIndex,
                    text: chunk.text,
                    embedding: chunk.embedding,
                    createdAt: Date.now,
                    database: database
                )
            }

            try Self.execute(sql: "COMMIT;", database: database)
            shouldCommit = true
        } catch {
            if !shouldCommit {
                try? Self.execute(sql: "ROLLBACK;", database: database)
            }
            throw error
        }
    }

    func removeResources(serverName: String) throws {
        guard let database else {
            fallbackEntries.removeAll { $0.serverName == serverName }
            fallbackFingerprints = fallbackFingerprints.filter { !$0.key.hasPrefix("\(serverName)::") }
            return
        }

        let sql = "DELETE FROM resources WHERE server_name = ?;"
        let statement = try Self.prepareStatement(sql, database: database)
        defer { sqlite3_finalize(statement) }

        Self.bindText(serverName, to: statement, at: 1)
        try Self.stepDone(statement, database: database)
    }

    func pruneResources(serverName: String, keepingURIs: Set<String>) throws {
        let existingURIs = try resourceURIs(serverName: serverName)
        let staleURIs = existingURIs.filter { !keepingURIs.contains($0) }

        for uri in staleURIs {
            try removeResource(serverName: serverName, uri: uri)
        }
    }

    func resourceURIs(serverName: String) throws -> [String] {
        guard let database else {
            let uris = fallbackEntries
                .filter { $0.serverName == serverName }
                .map(\.resourceURI)
            return Array(Set(uris)).sorted()
        }

        let sql = """
        SELECT resource_uri
        FROM resources
        WHERE server_name = ?;
        """

        let statement = try Self.prepareStatement(sql, database: database)
        defer { sqlite3_finalize(statement) }

        Self.bindText(serverName, to: statement, at: 1)

        var uris: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let uri = sqlite3_column_text(statement, 0).flatMap({ String(cString: $0) }) {
                uris.append(uri)
            }
        }

        return uris
    }

    func search(
        _ queryEmbedding: [Double],
        topK: Int = 5,
        minimumScore: Double = 0.15,
        allowedServerNames: Set<String>? = nil
    ) -> [SearchResult] {
        guard !queryEmbedding.isEmpty else { return [] }

        let entries: [EmbeddingEntry]
        if database == nil {
            entries = fallbackEntries
        } else {
            entries = (try? loadEntries()) ?? []
        }

        let filteredEntries = entries.filter { entry in
            guard let allowedServerNames else { return true }
            return allowedServerNames.contains(entry.serverName)
        }

        let results = filteredEntries.compactMap { entry -> SearchResult? in
            let score = cosineSimilarity(queryEmbedding, entry.embedding)
            guard score >= minimumScore else { return nil }
            return SearchResult(entry: entry, score: score)
        }

        return Array(results.sorted { $0.score > $1.score }.prefix(topK))
    }

    func indexedChunkCount() -> Int {
        guard let database else {
            return fallbackEntries.count
        }

        let sql = "SELECT COUNT(*) FROM chunks;"
        guard let statement = try? Self.prepareStatement(sql, database: database) else {
            return 0
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func removeResource(serverName: String, uri: String) throws {
        guard let database else {
            let key = resourceKey(serverName: serverName, uri: uri)
            fallbackEntries.removeAll { $0.serverName == serverName && $0.resourceURI == uri }
            fallbackFingerprints.removeValue(forKey: key)
            return
        }

        try deleteResource(serverName: serverName, uri: uri, database: database)
    }

    private func loadEntries() throws -> [EmbeddingEntry] {
        guard let database else { return fallbackEntries }

        let sql = """
        SELECT id, server_name, resource_uri, resource_description, chunk_index, text, embedding_json, resource_fingerprint, created_at
        FROM chunks;
        """

        let statement = try Self.prepareStatement(sql, database: database)
        defer { sqlite3_finalize(statement) }

        var entries: [EmbeddingEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = sqlite3_column_text(statement, 0).flatMap({ String(cString: $0) }),
                  let serverName = sqlite3_column_text(statement, 1).flatMap({ String(cString: $0) }),
                  let resourceURI = sqlite3_column_text(statement, 2).flatMap({ String(cString: $0) }),
                  let resourceDescription = sqlite3_column_text(statement, 3).flatMap({ String(cString: $0) }),
                  let text = sqlite3_column_text(statement, 5).flatMap({ String(cString: $0) }),
                  let embeddingJSONString = sqlite3_column_text(statement, 6).flatMap({ String(cString: $0) }),
                  let resourceFingerprint = sqlite3_column_text(statement, 7).flatMap({ String(cString: $0) })
            else {
                continue
            }

            let chunkIndex = Int(sqlite3_column_int64(statement, 4))
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
            let embedding = try Self.decodeEmbedding(from: embeddingJSONString)

            entries.append(
                EmbeddingEntry(
                    id: id,
                    serverName: serverName,
                    resourceURI: resourceURI,
                    resourceDescription: resourceDescription,
                    chunkIndex: chunkIndex,
                    text: text,
                    embedding: embedding,
                    resourceFingerprint: resourceFingerprint,
                    createdAt: createdAt
                )
            )
        }

        return entries
    }

    private func insertResource(
        serverName: String,
        uri: String,
        description: String,
        resourceFingerprint: String,
        updatedAt: Date,
        database: OpaquePointer
    ) throws {
        let sql = """
        INSERT INTO resources (
            server_name,
            resource_uri,
            resource_description,
            resource_fingerprint,
            updated_at
        ) VALUES (?, ?, ?, ?, ?);
        """

        let statement = try Self.prepareStatement(sql, database: database)
        defer { sqlite3_finalize(statement) }

        Self.bindText(serverName, to: statement, at: 1)
        Self.bindText(uri, to: statement, at: 2)
        Self.bindText(description, to: statement, at: 3)
        Self.bindText(resourceFingerprint, to: statement, at: 4)
        sqlite3_bind_double(statement, 5, updatedAt.timeIntervalSince1970)
        try Self.stepDone(statement, database: database)
    }

    private func insertChunk(
        serverName: String,
        uri: String,
        description: String,
        resourceFingerprint: String,
        chunkIndex: Int,
        text: String,
        embedding: [Double],
        createdAt: Date,
        database: OpaquePointer
    ) throws {
        let sql = """
        INSERT INTO chunks (
            id,
            server_name,
            resource_uri,
            resource_description,
            chunk_index,
            text,
            embedding_json,
            resource_fingerprint,
            created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        let statement = try Self.prepareStatement(sql, database: database)
        defer { sqlite3_finalize(statement) }

        Self.bindText("\(resourceKey(serverName: serverName, uri: uri))#\(chunkIndex)", to: statement, at: 1)
        Self.bindText(serverName, to: statement, at: 2)
        Self.bindText(uri, to: statement, at: 3)
        Self.bindText(description, to: statement, at: 4)
        sqlite3_bind_int64(statement, 5, sqlite3_int64(chunkIndex))
        Self.bindText(text, to: statement, at: 6)
        Self.bindText(try Self.encodeEmbedding(embedding), to: statement, at: 7)
        Self.bindText(resourceFingerprint, to: statement, at: 8)
        sqlite3_bind_double(statement, 9, createdAt.timeIntervalSince1970)
        try Self.stepDone(statement, database: database)
    }

    private func deleteResource(serverName: String, uri: String, database: OpaquePointer) throws {
        let sql = """
        DELETE FROM resources
        WHERE server_name = ? AND resource_uri = ?;
        """

        let statement = try Self.prepareStatement(sql, database: database)
        defer { sqlite3_finalize(statement) }

        Self.bindText(serverName, to: statement, at: 1)
        Self.bindText(uri, to: statement, at: 2)
        try Self.stepDone(statement, database: database)
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

    private static func defaultDatabaseURL() -> URL {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return supportDirectory
            .appendingPathComponent("codellama", isDirectory: true)
            .appendingPathComponent("vector-store.sqlite", isDirectory: false)
    }

    private static func prepareDatabaseDirectory(for databaseURL: URL) throws {
        let directoryURL = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private static func openDatabase(at url: URL) throws -> OpaquePointer {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(url.path(percentEncoded: false), &database, flags, nil) == SQLITE_OK,
              let database
        else {
            let message = database.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unknown SQLite error"
            if let database {
                sqlite3_close(database)
            }
            throw VectorStoreError.sqlite(message)
        }

        return database
    }

    private static func configureDatabase(_ database: OpaquePointer?) throws {
        try execute(sql: "PRAGMA foreign_keys = ON;", database: database)
        try execute(sql: "PRAGMA journal_mode = WAL;", database: database)
    }

    private static func createSchema(in database: OpaquePointer?) throws {
        try execute(
            sql: """
            CREATE TABLE IF NOT EXISTS resources (
                server_name TEXT NOT NULL,
                resource_uri TEXT NOT NULL,
                resource_description TEXT NOT NULL,
                resource_fingerprint TEXT NOT NULL,
                updated_at REAL NOT NULL,
                PRIMARY KEY (server_name, resource_uri)
            );
            """,
            database: database
        )

        try execute(
            sql: """
            CREATE TABLE IF NOT EXISTS chunks (
                id TEXT PRIMARY KEY,
                server_name TEXT NOT NULL,
                resource_uri TEXT NOT NULL,
                resource_description TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                text TEXT NOT NULL,
                embedding_json TEXT NOT NULL,
                resource_fingerprint TEXT NOT NULL,
                created_at REAL NOT NULL,
                FOREIGN KEY (server_name, resource_uri)
                    REFERENCES resources(server_name, resource_uri)
                    ON DELETE CASCADE
            );
            """,
            database: database
        )

        try execute(
            sql: "CREATE INDEX IF NOT EXISTS idx_chunks_resource ON chunks(server_name, resource_uri);",
            database: database
        )
    }

    private static func prepareStatement(_ sql: String, database: OpaquePointer?) throws -> OpaquePointer {
        guard let database else {
            throw VectorStoreError.sqlite("Database is unavailable.")
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw VectorStoreError.sqlite(lastErrorMessage(in: database))
        }

        return statement
    }

    private static func execute(sql: String, database: OpaquePointer?) throws {
        guard let database else {
            throw VectorStoreError.sqlite("Database is unavailable.")
        }

        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw VectorStoreError.sqlite(lastErrorMessage(in: database))
        }
    }

    private static func stepDone(_ statement: OpaquePointer?, database: OpaquePointer?) throws {
        let code = sqlite3_step(statement)
        guard code == SQLITE_DONE else {
            throw VectorStoreError.sqlite(lastErrorMessage(in: database))
        }
    }

    private static func bindText(_ text: String, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_text(statement, index, text, -1, sqliteTransientDestructor)
    }

    private static func encodeEmbedding(_ embedding: [Double]) throws -> String {
        let data = try JSONEncoder().encode(embedding)
        guard let string = String(data: data, encoding: .utf8) else {
            throw VectorStoreError.encoding("Could not encode embedding payload.")
        }
        return string
    }

    private static func decodeEmbedding(from string: String) throws -> [Double] {
        guard let data = string.data(using: .utf8) else {
            throw VectorStoreError.encoding("Could not decode embedding payload.")
        }
        return try JSONDecoder().decode([Double].self, from: data)
    }

    private static func lastErrorMessage(in database: OpaquePointer?) -> String {
        guard let database, let message = sqlite3_errmsg(database) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }

    private static let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

enum VectorStoreError: LocalizedError {
    case sqlite(String)
    case encoding(String)

    var errorDescription: String? {
        switch self {
        case .sqlite(let message), .encoding(let message):
            return message
        }
    }
}
