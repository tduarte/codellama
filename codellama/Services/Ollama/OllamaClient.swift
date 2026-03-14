import Foundation

// MARK: - Errors

enum OllamaError: LocalizedError {
    case serverUnreachable
    case invalidResponse(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .serverUnreachable:
            return "Cannot connect to the Ollama server. Make sure Ollama is running."
        case .invalidResponse(let statusCode):
            return "Unexpected response from Ollama (HTTP \(statusCode))."
        case .decodingError(let error):
            return "Failed to parse Ollama response: \(error.localizedDescription)"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Client

actor OllamaClient {
    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let parser: OllamaStreamParser

    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase

        self.parser = OllamaStreamParser()
    }

    // MARK: - Reachability

    /// Check if the Ollama server is reachable by hitting the root endpoint.
    func isReachable() async -> Bool {
        do {
            let (_, response) = try await session.data(from: baseURL)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - List Models

    /// List locally available models (GET /api/tags).
    func listModels() async throws -> OllamaModelsResponse {
        let url = baseURL.appendingPathComponent("api/tags")
        let request = URLRequest(url: url)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OllamaError.serverUnreachable
        }

        try validateHTTPResponse(response)

        do {
            return try decoder.decode(OllamaModelsResponse.self, from: data)
        } catch {
            throw OllamaError.decodingError(error)
        }
    }

    // MARK: - Chat (Streaming)

    /// Chat with streaming (POST /api/chat).
    ///
    /// Returns an `AsyncThrowingStream` that yields `OllamaChatChunk` values
    /// as they arrive from the server via NDJSON.
    func chatStream(request chatRequest: OllamaChatRequest) async -> AsyncThrowingStream<OllamaChatChunk, Error> {
        let session = self.session
        let parser = self.parser
        let encoder = self.encoder
        let baseURL = self.baseURL

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = baseURL.appendingPathComponent("api/chat")
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try encoder.encode(chatRequest)
                    urlRequest.timeoutInterval = 300

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                        throw OllamaError.invalidResponse(statusCode: code)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }

                        let chunk = try parser.parseChatChunk(trimmed)
                        continuation.yield(chunk)

                        if chunk.done {
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Chat (Non-Streaming)

    /// Chat without streaming — returns the complete response as a single chunk.
    func chat(request chatRequest: OllamaChatRequest) async throws -> OllamaChatChunk {
        // Override stream to false for a single response
        var nonStreamRequest = chatRequest
        nonStreamRequest.stream = false

        let urlRequest = try buildPOSTRequest(path: "api/chat", body: nonStreamRequest)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw OllamaError.networkError(error)
        }

        try validateHTTPResponse(response)

        do {
            return try decoder.decode(OllamaChatChunk.self, from: data)
        } catch {
            throw OllamaError.decodingError(error)
        }
    }

    // MARK: - Generate (Streaming)

    /// Generate with streaming (POST /api/generate).
    ///
    /// Returns an `AsyncThrowingStream` that yields `OllamaGenerateChunk` values.
    func generateStream(request generateRequest: OllamaGenerateRequest) async -> AsyncThrowingStream<OllamaGenerateChunk, Error> {
        let session = self.session
        let parser = self.parser
        let encoder = self.encoder
        let baseURL = self.baseURL

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = baseURL.appendingPathComponent("api/generate")
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try encoder.encode(generateRequest)
                    urlRequest.timeoutInterval = 300

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                        throw OllamaError.invalidResponse(statusCode: code)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }

                        let chunk = try parser.parseGenerateChunk(trimmed)
                        continuation.yield(chunk)

                        if chunk.done {
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private Helpers

    private func buildPOSTRequest<Body: Encodable>(path: String, body: Body) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw OllamaError.networkError(URLError(.badServerResponse))
        }
        guard (200...299).contains(http.statusCode) else {
            throw OllamaError.invalidResponse(statusCode: http.statusCode)
        }
    }
}
