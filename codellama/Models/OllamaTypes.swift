//
//  OllamaTypes.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation

// MARK: - JSONValue

/// A type-erased JSON value that supports all JSON primitives.
///
/// Use `JSONValue` wherever you need to represent arbitrary JSON data
/// (e.g., tool arguments, function parameters, or dynamic API payloads).
enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    // MARK: Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        // Try bool before number — `Bool` and `Int`/`Double` overlap in JSON.
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }

        if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
            return
        }

        if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "JSONValue cannot decode the contained value"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - JSONValue Convenience Initializers

extension JSONValue: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSONValue: ExpressibleByFloatLiteral {
    init(floatLiteral value: Double) { self = .number(value) }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    init(nilLiteral: ()) { self = .null }
}

// MARK: - OllamaRole

/// The role of a participant in an Ollama chat conversation.
enum OllamaRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}

// MARK: - OllamaChatMessage

/// A single message within an Ollama chat request or response.
struct OllamaChatMessage: Codable, Sendable {
    let role: OllamaRole
    let content: String
    let toolCalls: [OllamaToolCall]?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
    }

    init(role: OllamaRole, content: String, toolCalls: [OllamaToolCall]? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }
}

// MARK: - OllamaTool

/// A tool definition provided to the Ollama chat API for function calling.
struct OllamaTool: Codable, Sendable {
    let type: String
    let function: OllamaToolFunction

    init(function: OllamaToolFunction) {
        self.type = "function"
        self.function = function
    }
}

/// The function descriptor inside an `OllamaTool`.
struct OllamaToolFunction: Codable, Sendable {
    let name: String
    let description: String
    let parameters: JSONValue
}

// MARK: - OllamaToolCall

/// A tool invocation returned by the model inside a chat response message.
struct OllamaToolCall: Codable, Sendable, Hashable {
    let function: OllamaToolCallFunction
}

/// The function name and arguments within an `OllamaToolCall`.
struct OllamaToolCallFunction: Codable, Sendable, Hashable {
    let name: String
    let arguments: [String: JSONValue]
}

// MARK: - OllamaChatRequest

/// The request body sent to `POST /api/chat`.
struct OllamaChatRequest: Codable, Sendable {
    let model: String
    let messages: [OllamaChatMessage]
    var stream: Bool
    let tools: [OllamaTool]?
    let format: String?
    let options: OllamaOptions?

    init(
        model: String,
        messages: [OllamaChatMessage],
        stream: Bool = true,
        tools: [OllamaTool]? = nil,
        format: String? = nil,
        options: OllamaOptions? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.tools = tools
        self.format = format
        self.options = options
    }
}

// MARK: - OllamaChatChunk

/// A single chunk (or final response) returned by the Ollama chat API when streaming.
struct OllamaChatChunk: Codable, Sendable {
    let model: String
    let message: OllamaChatMessage?
    let done: Bool
    let totalDuration: Int?
    let evalCount: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case message
        case done
        case totalDuration = "total_duration"
        case evalCount = "eval_count"
    }
}

// MARK: - OllamaModelsResponse

/// The response body from `GET /api/tags` listing available models.
struct OllamaModelsResponse: Codable, Sendable {
    let models: [OllamaModel]
}

/// Metadata for a single model available in the Ollama instance.
struct OllamaModel: Codable, Sendable, Identifiable {
    var id: String { name }

    let name: String
    let modifiedAt: String
    let size: Int
    let digest: String
    let details: OllamaModelDetails

    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
        case digest
        case details
    }
}

/// Detailed metadata about a model's architecture and quantization.
struct OllamaModelDetails: Codable, Sendable {
    let format: String?
    let family: String?
    let parameterSize: String?
    let quantizationLevel: String?

    enum CodingKeys: String, CodingKey {
        case format
        case family
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}

// MARK: - OllamaOptions

/// Optional model parameters forwarded to the Ollama runtime.
struct OllamaOptions: Codable, Sendable {
    var temperature: Double?
    var topP: Double?
    var topK: Int?
    var numCtx: Int?
    var seed: Int?
    var numPredict: Int?
    var stop: [String]?
    var repeatPenalty: Double?
    var presencePenalty: Double?
    var frequencyPenalty: Double?

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case numCtx = "num_ctx"
        case seed
        case numPredict = "num_predict"
        case stop
        case repeatPenalty = "repeat_penalty"
        case presencePenalty = "presence_penalty"
        case frequencyPenalty = "frequency_penalty"
    }
}

// MARK: - OllamaGenerateRequest

/// The request body sent to `POST /api/generate`.
struct OllamaGenerateRequest: Codable, Sendable {
    let model: String
    let prompt: String
    let stream: Bool
    let system: String?
    let format: String?

    init(
        model: String,
        prompt: String,
        stream: Bool = true,
        system: String? = nil,
        format: String? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.stream = stream
        self.system = system
        self.format = format
    }
}

// MARK: - OllamaGenerateChunk

/// A single chunk returned by the Ollama generate API when streaming.
struct OllamaGenerateChunk: Codable, Sendable {
    let model: String
    let response: String
    let done: Bool
}
