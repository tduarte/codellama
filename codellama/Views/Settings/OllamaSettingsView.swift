//
//  OllamaSettingsView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import AppKit
import SwiftUI
import Defaults

struct OllamaSettingsView: View {
    @Environment(AppState.self) private var appState

    @AppStorage("ollamaHost") private var host: String = Defaults.Keys.ollamaHost.defaultValue
    @AppStorage("embeddingModel") private var embeddingModel: String = Defaults.Keys.embeddingModel.defaultValue
    @AppStorage("defaultModel") private var defaultModel: String = Defaults.Keys.defaultModel.defaultValue
    @AppStorage("systemPrompt") private var systemPrompt: String = Defaults.Keys.systemPrompt.defaultValue
    @AppStorage("streamResponses") private var streamResponses: Bool = Defaults.Keys.streamResponses.defaultValue

    @State private var lastIndexedEmbeddingModel: String = Defaults[.embeddingModel]
    @State private var connectionResult: ConnectionTestResult?
    @State private var isTesting: Bool = false
    @State private var reindexTask: Task<Void, Never>?

    enum ConnectionTestResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section("Ollama Server") {
                TextField("Host URL", text: $host)

                TextField("Embedding Model", text: $embeddingModel)

                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(isTesting)

                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if let result = connectionResult {
                        switch result {
                        case .success:
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }

            Section("Chat Defaults") {
                if appState.availableModels.isEmpty {
                    TextField("Default Model", text: $defaultModel)
                } else {
                    Picker("Default Model", selection: $defaultModel) {
                        if !appState.availableModels.contains(where: { $0.name == defaultModel }) {
                            Text("\(defaultModel) (Unavailable)")
                                .tag(defaultModel)
                        }

                        ForEach(appState.availableModels) { model in
                            Text(model.name).tag(model.name)
                        }
                    }
                }

                Toggle("Stream responses", isOn: $streamResponses)
                Text("When enabled, assistant responses render token-by-token during generation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Default System Prompt") {
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.quaternary, lineWidth: 1)
                    )
            }

            Section("Context Index") {
                LabeledContent("Status") {
                    if appState.contextIndexManager.isIndexing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(appState.contextIndexManager.statusMessage)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(appState.contextIndexManager.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Indexed Files") {
                    Text("\(appState.contextIndexManager.indexedFileCount)")
                        .monospacedDigit()
                }

                if let lastIndexedAt = appState.contextIndexManager.lastIndexedAt {
                    LabeledContent("Last Indexed") {
                        Text(lastIndexedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                if appState.contextIndexManager.attachedFolders.isEmpty {
                    Text("Attach one or more folders to index local project files into the agent context.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.contextIndexManager.attachedFolders, id: \.self) { folderPath in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(URL(fileURLWithPath: folderPath).lastPathComponent)
                                Text(folderPath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                Task {
                                    await appState.contextIndexManager.removeFolder(
                                        folderPath,
                                        ollamaClient: appState.ollamaClient,
                                        embeddingModel: Defaults[.embeddingModel]
                                    )
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                HStack {
                    Button("Attach Folder") {
                        attachFolder()
                    }

                    Button("Reindex Now") {
                        Task {
                            await appState.contextIndexManager.reindexLocalFolders(
                                using: appState.ollamaClient,
                                embeddingModel: embeddingModel
                            )
                        }
                    }
                    .disabled(appState.contextIndexManager.isIndexing)
                }

                if let lastError = appState.contextIndexManager.lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .environment(\.defaultMinListRowHeight, 30)
        .onChange(of: embeddingModel) {
            scheduleReindexForEmbeddingModel()
        }
        .onDisappear {
            reindexTask?.cancel()
        }
    }

    // MARK: - Actions

    private func scheduleReindexForEmbeddingModel() {
        guard embeddingModel != lastIndexedEmbeddingModel else { return }

        reindexTask?.cancel()
        let currentEmbeddingModel = embeddingModel
        reindexTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }

            await appState.contextIndexManager.reindexLocalFolders(
                using: appState.ollamaClient,
                embeddingModel: currentEmbeddingModel
            )
            await MainActor.run {
                lastIndexedEmbeddingModel = currentEmbeddingModel
            }
        }
    }

    private func testConnection() {
        isTesting = true
        connectionResult = nil

        Task {
            guard let url = URL(string: host) else {
                connectionResult = .failure("Invalid URL")
                isTesting = false
                return
            }

            let client = OllamaClient(baseURL: url)
            let reachable = await client.isReachable()

            connectionResult = reachable ? .success : .failure("Cannot reach Ollama")
            isTesting = false
        }
    }

    private func attachFolder() {
        let panel = NSOpenPanel()
        panel.title = "Attach Folder to Context Index"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await appState.contextIndexManager.addFolder(
                url.path(percentEncoded: false),
                ollamaClient: appState.ollamaClient,
                embeddingModel: embeddingModel
            )
        }
    }
}

#Preview {
    OllamaSettingsView()
        .environment(AppState.preview)
        .frame(width: 700, height: 560)
}
