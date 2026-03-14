//
//  MCPProcessManager.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation

/// Manages the lifecycle of child processes spawned for MCP stdio servers.
///
/// Each server is tracked by name. Uses `NSLock` for thread-safe access
/// to the internal process map without requiring actor isolation.
final class MCPProcessManager: @unchecked Sendable {

    // MARK: - Private State

    private var processes: [String: Process] = [:]
    private let lock = NSLock()

    // MARK: - Spawning

    /// Spawn a server process with connected stdin/stdout pipes.
    ///
    /// The command is resolved via `/usr/bin/env` so that commands like `npx`
    /// that live on the user's PATH work correctly.
    ///
    /// - Returns: A tuple of `(process, stdinPipe, stdoutPipe)` for use
    ///   by the MCP transport layer.
    func spawn(
        serverName: String,
        command: String,
        arguments: [String],
        environment: [String: String]?
    ) throws -> (Process, Pipe, Pipe) {
        let process = Process()

        // Use /usr/bin/env to resolve the command from PATH
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments

        // Merge provided environment with the current process environment
        if let environment {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                env[key] = value
            }
            process.environment = env
        }

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        lock.lock()
        processes[serverName] = process
        lock.unlock()

        return (process, stdinPipe, stdoutPipe)
    }

    // MARK: - Lifecycle Management

    /// Terminate the process for a specific server.
    func terminate(serverName: String) {
        lock.lock()
        let process = processes.removeValue(forKey: serverName)
        lock.unlock()

        if let process, process.isRunning {
            process.terminate()
        }
    }

    /// Terminate all managed processes gracefully.
    func terminateAll() {
        lock.lock()
        let allProcesses = processes
        processes.removeAll()
        lock.unlock()

        for (_, process) in allProcesses where process.isRunning {
            process.terminate()
        }
    }

    /// Returns `true` if the process for the given server is still running.
    func isRunning(serverName: String) -> Bool {
        lock.lock()
        let process = processes[serverName]
        lock.unlock()
        return process?.isRunning ?? false
    }
}
