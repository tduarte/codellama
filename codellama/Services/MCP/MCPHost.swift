//
//  MCPHost.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import SwiftData
import MCP

/// Lightweight metadata about a tool provided by a specific MCP server.
struct MCPToolInfo: Identifiable, Sendable {
    let serverName: String
    let toolName: String
    let description: String
    let inputSchema: JSONValue?

    var id: String { "\(serverName)/\(toolName)" }
}

/// Central manager for all active MCP server connections.
///
/// Maintains a registry of `MCPServerConnection` instances keyed by server name,
/// and provides unified access to all available tools in Ollama-compatible format.
@MainActor
@Observable
final class MCPHost {

    // MARK: - State

    private(set) var connections: [String: MCPServerConnection] = [:]
    let processManager = MCPProcessManager()

    // MARK: - Tool Aggregation

    /// All tools from all connected servers, with server attribution.
    var allMCPTools: [MCPToolInfo] {
        connections.flatMap { serverName, connection in
            connection.availableTools.map { tool in
                MCPToolInfo(
                    serverName: serverName,
                    toolName: tool.name,
                    description: tool.description ?? "",
                    inputSchema: convertValueToJSONValue(tool.inputSchema)
                )
            }
        }
    }

    /// Convert all MCP tools to Ollama's tool format for use in /api/chat requests.
    func ollamaTools() -> [OllamaTool] {
        allMCPTools.map { info in
            OllamaTool(function: OllamaToolFunction(
                name: "\(info.serverName)__\(info.toolName)",
                description: info.description,
                parameters: info.inputSchema ?? .object([:])
            ))
        }
    }

    // MARK: - Connection Management

    /// Connect to an MCP server using its configuration.
    func connect(config: MCPServerConfig) async throws {
        let connection = MCPServerConnection(config: config)
        try await connection.connect(processManager: processManager)
        connections[config.name] = connection
    }

    /// Disconnect and remove a server by name.
    func disconnect(serverName: String) async {
        if let connection = connections[serverName] {
            await connection.disconnect()
            connections.removeValue(forKey: serverName)
        }
    }

    /// Disconnect all active servers.
    func disconnectAll() async {
        for (_, connection) in connections {
            await connection.disconnect()
        }
        connections.removeAll()
        processManager.terminateAll()
    }

    // MARK: - Tool Routing

    /// Route a `ToolCall` to the correct server connection and execute it.
    func callTool(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let connection = connections[toolCall.serverName] else {
            return ToolResult(
                id: UUID().uuidString,
                toolCallId: toolCall.id,
                content: "Server '\(toolCall.serverName)' is not connected.",
                isError: true
            )
        }

        // Convert our JSONValue arguments to MCP SDK Value type
        let mcpArguments: [String: Value]? = toolCall.arguments.isEmpty
            ? nil
            : Dictionary(uniqueKeysWithValues: toolCall.arguments.map { key, value in
                (key, convertJSONValueToValue(value))
            })

        var result = try await connection.callTool(name: toolCall.toolName, arguments: mcpArguments)
        // Attach the correct toolCallId
        result = ToolResult(
            id: result.id,
            toolCallId: toolCall.id,
            content: result.content,
            isError: result.isError
        )
        return result
    }

    /// Find which server provides a given tool name.
    func serverName(for toolName: String) -> String? {
        for (serverName, connection) in connections {
            if connection.availableTools.contains(where: { $0.name == toolName }) {
                return serverName
            }
        }
        return nil
    }

    // MARK: - Type Conversion Helpers

    /// Convert an MCP SDK `Value` to our app's `JSONValue`.
    private func convertValueToJSONValue(_ value: Value) -> JSONValue {
        switch value {
        case .string(let s):
            return .string(s)
        case .int(let i):
            return .number(Double(i))
        case .double(let d):
            return .number(d)
        case .bool(let b):
            return .bool(b)
        case .object(let obj):
            return .object(obj.mapValues { convertValueToJSONValue($0) })
        case .array(let arr):
            return .array(arr.map { convertValueToJSONValue($0) })
        case .null:
            return .null
        case .data(let mimeType, let data):
            // Represent binary data as a base64-encoded string
            return .string("data:\(mimeType ?? "application/octet-stream");base64,\(data.base64EncodedString())")
        }
    }

    /// Convert our app's `JSONValue` to an MCP SDK `Value`.
    private func convertJSONValueToValue(_ jsonValue: JSONValue) -> Value {
        switch jsonValue {
        case .string(let s):
            return .string(s)
        case .number(let d):
            return .double(d)
        case .bool(let b):
            return .bool(b)
        case .object(let obj):
            return .object(obj.mapValues { convertJSONValueToValue($0) })
        case .array(let arr):
            return .array(arr.map { convertJSONValueToValue($0) })
        case .null:
            return .null
        }
    }
}
