import SwiftUI
import SwiftData
import Defaults

@MainActor
@Observable
final class AppState {

    // MARK: - MCP

    let mcpHost: MCPHost
    let contextIndexManager: ContextIndexManager

    init() {
        self.mcpHost = MCPHost()
        self.contextIndexManager = ContextIndexManager()
    }

    /// Lightweight instance for Xcode previews — uses an in-memory vector
    /// store and skips all disk I/O so previews render instantly.
    static var preview: AppState {
        let state = AppState(forPreview: true)
        state.status = .ready
        return state
    }

    private init(forPreview: Bool) {
        self.mcpHost = MCPHost()
        self.contextIndexManager = ContextIndexManager(
            vectorStore: VectorStore(inMemory: true)
        )
    }

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
    var isCommandPalettePresented: Bool = false
    private var modelCapabilities: [String: Set<String>] = [:]

    /// Currently selected model name
    var selectedModel: String {
        get { Defaults[.defaultModel] }
        set { Defaults[.defaultModel] = newValue }
    }

    func startup(modelContext: ModelContext? = nil) async {
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
            self.modelCapabilities = [:]

            // Auto-select first model if current selection isn't available
            if !response.models.contains(where: { $0.name == selectedModel }),
               let first = response.models.first {
                selectedModel = first.name
            }

            status = .ready
        } catch {
            status = .error("Failed to fetch models: \(error.localizedDescription)")
            return
        }

        // 4. Connect enabled MCP servers from SwiftData
        if let ctx = modelContext {
            let descriptor = FetchDescriptor<MCPServerConfig>()
            if let configs = try? ctx.fetch(descriptor) {
                for config in configs where config.isEnabled {
                    try? await mcpHost.connect(config: config)
                }
            }
        }

        Task {
            await contextIndexManager.reindexLocalFolders(
                using: client,
                embeddingModel: Defaults[.embeddingModel]
            )
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
        await mcpHost.disconnectAll()
    }

    func modelSupportsVision(_ model: String) async -> Bool {
        if let capabilities = modelCapabilities[model] {
            return capabilities.contains("vision")
        }

        guard let client = ollamaClient else { return false }

        do {
            let response = try await client.showModel(named: model)
            let capabilities = Set((response.capabilities ?? []).map { $0.lowercased() })
            modelCapabilities[model] = capabilities
            return capabilities.contains("vision")
        } catch {
            modelCapabilities[model] = []
            return false
        }
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
