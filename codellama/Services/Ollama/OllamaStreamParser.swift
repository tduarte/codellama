import Foundation

/// Parses NDJSON lines from Ollama streaming responses.
///
/// Ollama's streaming endpoints return newline-delimited JSON (NDJSON),
/// where each line is a complete JSON object representing a chunk of the response.
struct OllamaStreamParser {

    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    /// Parse a single NDJSON line into a chat completion chunk.
    func parseChatChunk(_ line: String) throws -> OllamaChatChunk {
        guard let data = line.data(using: .utf8) else {
            throw OllamaError.decodingError(
                DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Invalid UTF-8 in stream line")
                )
            )
        }
        do {
            return try decoder.decode(OllamaChatChunk.self, from: data)
        } catch {
            throw OllamaError.decodingError(error)
        }
    }

    /// Parse a single NDJSON line into a text generation chunk.
    func parseGenerateChunk(_ line: String) throws -> OllamaGenerateChunk {
        guard let data = line.data(using: .utf8) else {
            throw OllamaError.decodingError(
                DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Invalid UTF-8 in stream line")
                )
            )
        }
        do {
            return try decoder.decode(OllamaGenerateChunk.self, from: data)
        } catch {
            throw OllamaError.decodingError(error)
        }
    }

    /// Parse a single NDJSON line into a pull-progress update.
    func parsePullProgress(_ line: String) throws -> OllamaPullProgress {
        guard let data = line.data(using: .utf8) else {
            throw OllamaError.decodingError(
                DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Invalid UTF-8 in stream line")
                )
            )
        }
        do {
            return try decoder.decode(OllamaPullProgress.self, from: data)
        } catch {
            throw OllamaError.decodingError(error)
        }
    }
}
