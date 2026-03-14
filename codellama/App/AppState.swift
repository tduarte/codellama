import SwiftUI
import SwiftData
import Defaults

@MainActor
@Observable
final class AppState {
    enum Status: Equatable {
        case checking
        case ollamaNotFound
        case ollamaNotRunning
        case connecting
        case ready
        case error(String)
    }

    private(set) var status: Status = .checking
    private(set) var availableModels: [OllamaModel] = []
    private(set) var ollamaClient: OllamaClient?

    /// Currently selected model name
    var selectedModel: String {
        get { Defaults[.defaultModel] }
        set { Defaults[.defaultModel] = newValue }
    }

    func startup() async {
        status = .checking

        // 1. Check if Ollama binary exists
        guard findOllamaBinary() != nil else {
            status = .ollamaNotFound
            return
        }

        // 2. Create client and check reachability
        let host = Defaults[.ollamaHost]
        guard let url = URL(string: host) else {
            status = .error("Invalid Ollama host URL: \(host)")
            return
        }

        let client = OllamaClient(baseURL: url)

        guard await client.isReachable() else {
            status = .ollamaNotRunning
            return
        }

        self.ollamaClient = client

        // 3. Fetch available models
        status = .connecting
        do {
            let response = try await client.listModels()
            self.availableModels = response.models

            // Auto-select first model if current selection isn't available
            if !response.models.contains(where: { $0.name == selectedModel }),
               let first = response.models.first {
                selectedModel = first.name
            }

            status = .ready
        } catch {
            status = .error("Failed to fetch models: \(error.localizedDescription)")
        }
    }

    /// Attempt to start Ollama serve process
    func startOllama() async {
        guard let path = findOllamaBinary() else { return }
        // Spawn "ollama serve" as background process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["serve"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()

        // Wait briefly then retry startup
        try? await Task.sleep(for: .seconds(2))
        await startup()
    }

    func shutdown() async {
        // Will be expanded in Phase 2 to disconnect MCP servers
    }

    private func findOllamaBinary() -> String? {
        let paths = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "\(NSHomeDirectory())/.ollama/bin/ollama"
        ]
        // Also check PATH via `which ollama`
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? findOllamaInPath()
    }

    private func findOllamaInPath() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ollama"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let path, !path.isEmpty else { return nil }
        return path
    }
}
