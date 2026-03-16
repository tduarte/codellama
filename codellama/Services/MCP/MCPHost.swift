//
//  MCPHost.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import SwiftData
import MCP

struct MCPServerRuntimeState: Identifiable, Sendable {
    enum Lifecycle: String, Sendable {
        case disabled
        case disconnected
        case connecting
        case connected
        case restarting
        case failed
    }

    let serverName: String
    var lifecycle: Lifecycle
    var isEnabled: Bool
    var toolCount: Int
    var resourceCount: Int
    var lastExitCode: Int32?
    var errorMessage: String?

    var id: String { serverName }

    var statusSummary: String {
        switch lifecycle {
        case .disabled:
            return "Disabled"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting…"
        case .connected:
            return resourceCount == 0
                ? "\(toolCount) tool\(toolCount == 1 ? "" : "s")"
                : "\(toolCount) tools, \(resourceCount) resources"
        case .restarting:
            return "Restarting…"
        case .failed:
            if let errorMessage, !errorMessage.isEmpty {
                return errorMessage
            }
            if let lastExitCode {
                return "Exited with status \(lastExitCode)"
            }
            return "Connection failed"
        }
    }
}

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
    private(set) var serverStates: [String: MCPServerRuntimeState] = [:]
    let processManager = MCPProcessManager()
    private var configs: [String: MCPServerConfig] = [:]
    private var autoRestartTasks: [String: Task<Void, Never>] = [:]

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

    var sortedServerStates: [MCPServerRuntimeState] {
        serverStates.values.sorted { lhs, rhs in
            lhs.serverName.localizedCaseInsensitiveCompare(rhs.serverName) == .orderedAscending
        }
    }

    var connectedServerCount: Int {
        serverStates.values.filter { $0.lifecycle == .connected }.count
    }

    // MARK: - Connection Management

    func register(configs: [MCPServerConfig]) {
        let newConfigs = Dictionary(uniqueKeysWithValues: configs.map { ($0.name, $0) })
        self.configs = newConfigs

        let configNames = Set(newConfigs.keys)
        for config in configs {
            let lifecycle: MCPServerRuntimeState.Lifecycle
            if let existing = serverStates[config.name] {
                lifecycle = existing.lifecycle == .connected ? .connected : (config.isEnabled ? existing.lifecycle : .disabled)
            } else {
                lifecycle = config.isEnabled ? .disconnected : .disabled
            }
            updateState(
                for: config,
                lifecycle: config.isEnabled ? lifecycle : .disabled
            )
        }

        let removedNames = Set(serverStates.keys).subtracting(configNames)
        for serverName in removedNames {
            autoRestartTasks[serverName]?.cancel()
            autoRestartTasks.removeValue(forKey: serverName)
            serverStates.removeValue(forKey: serverName)
            connections.removeValue(forKey: serverName)
        }
    }

    /// Connect to an MCP server using its configuration.
    func connect(config: MCPServerConfig) async throws {
        configs[config.name] = config
        autoRestartTasks[config.name]?.cancel()
        autoRestartTasks.removeValue(forKey: config.name)
        updateState(for: config, lifecycle: .connecting)

        if connections[config.name] != nil {
            await disconnect(serverName: config.name, removeConfig: false, overrideLifecycle: .connecting)
        }

        let connection = MCPServerConnection(config: config)
        let serverName = config.name
        do {
            try await connection.connect(
                processManager: processManager,
                onUnexpectedTermination: { [weak self] exitCode in
                    Task { @MainActor [weak self] in
                        await self?.handleUnexpectedTermination(serverName: serverName, exitCode: exitCode)
                    }
                }
            )
            connections[config.name] = connection
            updateState(
                for: config,
                lifecycle: .connected,
                toolCount: connection.availableTools.count,
                resourceCount: connection.availableResources.count
            )
        } catch {
            updateState(for: config, lifecycle: .failed, errorMessage: error.localizedDescription)
            throw error
        }
    }

    /// Disconnect and remove a server by name.
    func disconnect(serverName: String) async {
        await disconnect(serverName: serverName, removeConfig: false)
    }

    func setEnabled(_ isEnabled: Bool, for config: MCPServerConfig) async {
        configs[config.name] = config

        if isEnabled {
            do {
                try await connect(config: config)
            } catch {
                updateState(for: config, lifecycle: .failed, errorMessage: error.localizedDescription)
            }
        } else {
            await disconnect(serverName: config.name, removeConfig: false, overrideLifecycle: .disabled)
        }
    }

    func restart(serverName: String) async {
        guard let config = configs[serverName] else { return }

        autoRestartTasks[serverName]?.cancel()
        autoRestartTasks.removeValue(forKey: serverName)
        updateState(for: config, lifecycle: .restarting)
        await disconnect(serverName: serverName, removeConfig: false, overrideLifecycle: .restarting)

        do {
            try await connect(config: config)
        } catch {
            updateState(for: config, lifecycle: .failed, errorMessage: error.localizedDescription)
        }
    }

    func removeServer(named serverName: String) async {
        autoRestartTasks[serverName]?.cancel()
        autoRestartTasks.removeValue(forKey: serverName)
        await disconnect(serverName: serverName, removeConfig: true)
        serverStates.removeValue(forKey: serverName)
        configs.removeValue(forKey: serverName)
    }

    private func disconnect(
        serverName: String,
        removeConfig: Bool,
        overrideLifecycle: MCPServerRuntimeState.Lifecycle? = nil
    ) async {
        autoRestartTasks[serverName]?.cancel()
        autoRestartTasks.removeValue(forKey: serverName)

        if let connection = connections[serverName] {
            await connection.disconnect()
            connections.removeValue(forKey: serverName)
        } else {
            processManager.terminate(serverName: serverName)
        }

        if removeConfig {
            configs.removeValue(forKey: serverName)
            return
        }

        guard let config = configs[serverName] else { return }
        let lifecycle = overrideLifecycle ?? (config.isEnabled ? .disconnected : .disabled)
        updateState(for: config, lifecycle: lifecycle)
    }

    /// Disconnect all active servers.
    func disconnectAll() async {
        autoRestartTasks.values.forEach { $0.cancel() }
        autoRestartTasks.removeAll()
        for (_, connection) in connections {
            await connection.disconnect()
        }
        connections.removeAll()
        processManager.terminateAll()
        for config in configs.values {
            updateState(for: config, lifecycle: config.isEnabled ? .disconnected : .disabled)
        }
    }

    // MARK: - Tool Routing

    /// Route a `ToolCall` to the correct server connection and execute it.
    func callTool(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let connection = connections[toolCall.serverName] else {
            return makeErrorResult(
                for: toolCall,
                message: "Server '\(toolCall.serverName)' is not connected."
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

    /// Execute multiple tool calls concurrently. Intended for independent,
    /// read-only work across different MCP servers.
    func callToolsInParallel(_ toolCalls: [ToolCall]) async -> [ToolResult] {
        guard !toolCalls.isEmpty else { return [] }

        let indexedToolCalls = Array(toolCalls.enumerated())

        return await withTaskGroup(of: (Int, ToolResult).self, returning: [ToolResult].self) { group in
            for (index, toolCall) in indexedToolCalls {
                group.addTask { @MainActor in
                    do {
                        let result = try await self.callTool(toolCall)
                        return (index, result)
                    } catch {
                        return (
                            index,
                            self.makeErrorResult(for: toolCall, message: error.localizedDescription)
                        )
                    }
                }
            }

            var orderedResults = Array<ToolResult?>(repeating: nil, count: indexedToolCalls.count)
            for await (index, result) in group {
                orderedResults[index] = result
            }

            return orderedResults.compactMap { $0 }
        }
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

    private func updateState(
        for config: MCPServerConfig,
        lifecycle: MCPServerRuntimeState.Lifecycle,
        toolCount: Int = 0,
        resourceCount: Int = 0,
        lastExitCode: Int32? = nil,
        errorMessage: String? = nil
    ) {
        serverStates[config.name] = MCPServerRuntimeState(
            serverName: config.name,
            lifecycle: lifecycle,
            isEnabled: config.isEnabled,
            toolCount: toolCount,
            resourceCount: resourceCount,
            lastExitCode: lastExitCode,
            errorMessage: errorMessage
        )
    }

    private func handleUnexpectedTermination(serverName: String, exitCode: Int32) async {
        guard let config = configs[serverName] else { return }

        if let connection = connections[serverName] {
            await connection.handleUnexpectedTermination(exitCode: exitCode)
        }
        connections.removeValue(forKey: serverName)
        updateState(
            for: config,
            lifecycle: .failed,
            lastExitCode: exitCode,
            errorMessage: "Process exited unexpectedly with status \(exitCode)."
        )

        guard config.isEnabled else { return }

        updateState(
            for: config,
            lifecycle: .restarting,
            lastExitCode: exitCode,
            errorMessage: "Process exited unexpectedly with status \(exitCode)."
        )

        autoRestartTasks[serverName]?.cancel()
        autoRestartTasks[serverName] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.restart(serverName: serverName)
        }
    }

    private func makeErrorResult(for toolCall: ToolCall, message: String) -> ToolResult {
        ToolResult(
            id: UUID().uuidString,
            toolCallId: toolCall.id,
            content: message,
            isError: true
        )
    }
}
