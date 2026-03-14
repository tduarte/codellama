//
//  MCPServerConnection.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import System
import MCP

/// Manages a single MCP server connection using the official Swift SDK.
///
/// Handles the full lifecycle: spawning the child process, initializing
/// the MCP client over stdio, listing available tools/resources, and
/// routing tool calls.
@MainActor
final class MCPServerConnection {

    // MARK: - Public State

    let config: MCPServerConfig
    private(set) var client: Client?
    private(set) var availableTools: [Tool] = []
    private(set) var availableResources: [Resource] = []
    private(set) var isConnected: Bool = false
    private(set) var connectionError: String?

    // MARK: - Private

    private var process: Process?
    private var processManager: MCPProcessManager?

    // MARK: - Init

    init(config: MCPServerConfig) {
        self.config = config
    }

    // MARK: - Connect

    /// Spawn the server process and establish an MCP connection over stdio.
    func connect(
        processManager: MCPProcessManager,
        onUnexpectedTermination: (@Sendable (Int32) -> Void)? = nil
    ) async throws {
        connectionError = nil
        self.processManager = processManager

        do {
            let (proc, stdinPipe, stdoutPipe) = try processManager.spawn(
                serverName: config.name,
                command: config.command,
                arguments: config.arguments,
                environment: config.environment,
                onUnexpectedExit: onUnexpectedTermination
            )
            self.process = proc

            // Bridge Foundation Pipe FileHandles to System FileDescriptors
            let inputFD = FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor)
            let outputFD = FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)

            // Create the transport using the pipes' FileDescriptors
            let transport = StdioTransport(input: inputFD, output: outputFD)

            // Create and connect the MCP client
            let mcpClient = Client(name: "CodeLlama", version: "1.0.0")
            _ = try await mcpClient.connect(transport: transport)
            self.client = mcpClient

            try await refreshCapabilities()
            isConnected = true
        } catch {
            connectionError = error.localizedDescription
            isConnected = false
            client = nil
            process = nil
            processManager.terminate(serverName: config.name)
            throw error
        }
    }

    // MARK: - Disconnect

    /// Disconnect the client and terminate the child process.
    func disconnect() async {
        if let client {
            await client.disconnect()
        }
        client = nil
        processManager?.terminate(serverName: config.name)
        process = nil
        isConnected = false
        connectionError = nil
        availableTools = []
        availableResources = []
    }

    func handleUnexpectedTermination(exitCode: Int32) async {
        if let client {
            await client.disconnect()
        }
        client = nil
        process = nil
        isConnected = false
        connectionError = "Process exited unexpectedly with status \(exitCode)."
        availableTools = []
        availableResources = []
    }

    // MARK: - Tool Calls

    /// Call a tool by name with the given arguments, returning a `ToolResult`.
    func callTool(name: String, arguments: [String: Value]?) async throws -> ToolResult {
        guard let client else {
            throw MCPConnectionError.notConnected(serverName: config.name)
        }

        let (content, isError) = try await client.callTool(name: name, arguments: arguments)

        // Flatten all content items into a single string
        let contentString = content.compactMap { item -> String? in
            switch item {
            case .text(let text):
                return text
            case .image(let data, let mimeType, _):
                return "[image/\(mimeType): \(data.prefix(20))...]"
            case .audio(let data, let mimeType):
                return "[audio/\(mimeType): \(data.prefix(20))...]"
            case .resource(let resource, _, _):
                return resource.text ?? "[resource: \(resource.uri)]"
            case .resourceLink(let uri, _, _, _, _, _):
                return "[resource link: \(uri)]"
            @unknown default:
                return nil
            }
        }.joined(separator: "\n")

        return ToolResult(
            id: UUID().uuidString,
            toolCallId: name,
            content: contentString,
            isError: isError ?? false
        )
    }

    // MARK: - Resources

    /// List all resources exposed by this server.
    func listResources() async throws -> [Resource] {
        guard let client else {
            throw MCPConnectionError.notConnected(serverName: config.name)
        }
        let (resources, _) = try await client.listResources()
        self.availableResources = resources
        return resources
    }

    /// Read the content of a resource by URI, returning it as a string.
    func readResource(uri: String) async throws -> String {
        guard let client else {
            throw MCPConnectionError.notConnected(serverName: config.name)
        }
        let contents = try await client.readResource(uri: uri)
        return contents.compactMap { item -> String? in
            if let text = item.text { return text }
            if let blob = item.blob { return "[blob: \(blob.prefix(20))...]" }
            return nil
        }.joined(separator: "\n")
    }

    private func refreshCapabilities() async throws {
        guard let client else { return }

        let toolsResult = try? await client.listTools()
        self.availableTools = toolsResult?.tools ?? []

        let resourcesResult = try? await client.listResources()
        self.availableResources = resourcesResult?.resources ?? []
    }
}

// MARK: - Errors

enum MCPConnectionError: LocalizedError {
    case notConnected(serverName: String)

    var errorDescription: String? {
        switch self {
        case .notConnected(let name):
            return "MCP server '\(name)' is not connected."
        }
    }
}
