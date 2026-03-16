//
//  OllamaSettingsView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct OllamaSettingsView: View {
    @Environment(AppState.self) private var appState

    @AppStorage("ollamaHost") private var host: String = Defaults.Keys.ollamaHost.defaultValue
    @AppStorage("systemPrompt") private var systemPrompt: String = Defaults.Keys.systemPrompt.defaultValue
    @AppStorage("streamResponses") private var streamResponses: Bool = Defaults.Keys.streamResponses.defaultValue

    @State private var displayedEmbeddingModel: String? = Defaults[.embeddingModel]
    @State private var committedEmbeddingModel: String? = Defaults[.embeddingModel]
    @State private var lastIndexedEmbeddingModel: String? = Defaults[.embeddingModel]
    @State private var connectionResult: ConnectionTestResult?
    @State private var isTesting: Bool = false
    @State private var pendingPullOption: EmbeddingModelOption?
    @State private var isPullConfirmationPresented: Bool = false
    @State private var isPullingEmbeddingModel: Bool = false
    @State private var pullProgress: OllamaPullProgress?
    @State private var pullErrorMessage: String?
    @State private var reindexTask: Task<Void, Never>?
    @State private var pullTask: Task<Void, Never>?
    @State private var isFolderImporterPresented: Bool = false
    @State private var isCancellingEmbeddingModelPull: Bool = false

    private let settingsLabelWidth: CGFloat = 220
    private let controlColumnWidth: CGFloat = 420

    enum ConnectionTestResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section("Ollama Server") {
                settingsRow("Host URL") {
                    TextField("http://localhost:11434", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: controlColumnWidth)
                }

                settingsRow("Embedding Model", alignment: .top) {
                    VStack(alignment: .trailing, spacing: 8) {
                        embeddingModelPicker

                        if isPullingEmbeddingModel, let pullProgress {
                            VStack(alignment: .trailing, spacing: 4) {
                                Group {
                                    if let completed = pullProgress.completed,
                                       let total = pullProgress.total,
                                       total > 0 {
                                        ProgressView(value: Double(completed), total: Double(total))
                                            .progressViewStyle(.linear)
                                    } else {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                                .frame(width: controlColumnWidth, alignment: .trailing)

                                HStack(spacing: 8) {
                                    Text(pullProgress.status)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Button {
                                        cancelEmbeddingModelPull()
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.circle)
                                    .controlSize(.small)
                                    .accessibilityLabel("Cancel Download")
                                }
                                .frame(width: controlColumnWidth, alignment: .trailing)
                            }
                        }

                        if let pullErrorMessage {
                            Text(pullErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: controlColumnWidth, alignment: .leading)
                        }
                    }
                }

                settingsRow("Connection") {
                    HStack(spacing: 10) {
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
            }

            Section("Chat Defaults") {
                settingsRow("Default Model") {
                    if appState.availableModels.isEmpty {
                        TextField("Model", text: selectedModelBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 240)
                    } else {
                        Picker("Default Model", selection: selectedModelBinding) {
                            if !appState.availableModels.contains(where: { $0.name == appState.selectedModel }) {
                                Text("\(appState.selectedModel) (Unavailable)")
                                    .tag(appState.selectedModel)
                            }

                            ForEach(appState.availableModels) { model in
                                Text(model.name).tag(model.name)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 240, alignment: .trailing)
                    }
                }

                settingsRow("Stream responses") {
                    Toggle("", isOn: $streamResponses)
                        .labelsHidden()
                }

                Text("When enabled, assistant responses render token-by-token during generation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Default System Prompt") {
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
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
                                        embeddingModel: committedEmbeddingModel
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
                        isFolderImporterPresented = true
                    }

                    Button("Reindex Now") {
                        Task {
                            await appState.contextIndexManager.reindexLocalFolders(
                                using: appState.ollamaClient,
                                embeddingModel: committedEmbeddingModel
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
        .controlSize(.regular)
        .environment(\.defaultMinListRowHeight, 30)
        .scrollIndicators(.never)
        .confirmationDialog(
            "Download Embedding Model?",
            isPresented: $isPullConfirmationPresented,
            presenting: pendingPullOption
        ) { option in
            Button("Pull Model") {
                startPull(for: option)
            }
            .keyboardShortcut(.defaultAction)

            Button("Cancel", role: .cancel) {
                revertPendingEmbeddingSelection()
            }
        } message: { option in
            Text("\(option.title) isn't installed on this Ollama server yet. Download it now?\n\n\(option.subtitle)")
        }
        .onChange(of: isPullConfirmationPresented) { _, isPresented in
            if !isPresented, pendingPullOption != nil, !isPullingEmbeddingModel {
                revertPendingEmbeddingSelection()
            }
        }
        .onDisappear {
            reindexTask?.cancel()
            pullTask?.cancel()
        }
        .fileImporter(
            isPresented: $isFolderImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result,
                  let url = urls.first else { return }

            Task {
                await appState.contextIndexManager.addFolder(
                    url.path(percentEncoded: false),
                    ollamaClient: appState.ollamaClient,
                    embeddingModel: committedEmbeddingModel
                )
            }
        }
    }

    // MARK: - Actions

    private func scheduleReindexForEmbeddingModel(_ model: String?) {
        guard model != lastIndexedEmbeddingModel else { return }
        reindexTask?.cancel()
        let currentEmbeddingModel = model
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

    private func selectEmbeddingOption(_ option: EmbeddingModelOption) {
        guard !isPullingEmbeddingModel else { return }

        pullErrorMessage = nil
        displayedEmbeddingModel = option.storageValue

        guard option.storageValue != committedEmbeddingModel else { return }

        guard let modelName = option.modelName else {
            commitEmbeddingModel(nil)
            return
        }

        guard !isEmbeddingModelInstalled(modelName) else {
            commitEmbeddingModel(modelName)
            return
        }

        pendingPullOption = option
        isPullConfirmationPresented = true
    }

    private func commitEmbeddingModel(_ model: String?) {
        committedEmbeddingModel = model
        displayedEmbeddingModel = model
        Defaults[.embeddingModel] = model
        scheduleReindexForEmbeddingModel(model)
    }

    private func revertPendingEmbeddingSelection() {
        displayedEmbeddingModel = committedEmbeddingModel
        pendingPullOption = nil
    }

    private func startPull(for option: EmbeddingModelOption) {
        guard let modelName = option.modelName else { return }
        guard let ollamaClient = appState.ollamaClient else {
            pullErrorMessage = "Cannot download models because Ollama is unavailable."
            revertPendingEmbeddingSelection()
            return
        }

        pullTask?.cancel()
        pullErrorMessage = nil
        isCancellingEmbeddingModelPull = false
        isPullingEmbeddingModel = true
        pullProgress = OllamaPullProgress(
            status: "Preparing download…",
            digest: nil,
            total: nil,
            completed: nil,
            error: nil
        )

        pullTask = Task {
            do {
                for try await progress in await ollamaClient.pullModel(named: modelName) {
                    await MainActor.run {
                        pullProgress = progress
                    }
                }

                if Task.isCancelled || isCancellingEmbeddingModelPull {
                    await MainActor.run {
                        finishCancelledEmbeddingModelPull()
                    }
                    return
                }

                do {
                    try await appState.refreshModels()
                } catch {
                    if Task.isCancelled || isCancellingEmbeddingModelPull {
                        await MainActor.run {
                            finishCancelledEmbeddingModelPull()
                        }
                        return
                    }

                    await MainActor.run {
                        pullErrorMessage = "Downloaded \(modelName), but failed to refresh local models: \(error.localizedDescription)"
                    }
                }

                if Task.isCancelled || isCancellingEmbeddingModelPull {
                    await MainActor.run {
                        finishCancelledEmbeddingModelPull()
                    }
                    return
                }

                await MainActor.run {
                    pendingPullOption = nil
                    isCancellingEmbeddingModelPull = false
                    isPullingEmbeddingModel = false
                    pullProgress = nil
                    commitEmbeddingModel(modelName)
                    pullTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    finishCancelledEmbeddingModelPull()
                }
            } catch {
                if Task.isCancelled || isCancellingEmbeddingModelPull {
                    await MainActor.run {
                        finishCancelledEmbeddingModelPull()
                    }
                    return
                }

                await MainActor.run {
                    pullErrorMessage = "Failed to pull \(modelName): \(error.localizedDescription)"
                    isPullingEmbeddingModel = false
                    pullProgress = nil
                    isCancellingEmbeddingModelPull = false
                    revertPendingEmbeddingSelection()
                    pullTask = nil
                }
            }
        }
    }

    private func cancelEmbeddingModelPull() {
        guard isPullingEmbeddingModel else { return }
        isCancellingEmbeddingModelPull = true
        pullTask?.cancel()
    }

    private func finishCancelledEmbeddingModelPull() {
        pullErrorMessage = nil
        isCancellingEmbeddingModelPull = false
        isPullingEmbeddingModel = false
        pullProgress = nil
        revertPendingEmbeddingSelection()
        pullTask = nil
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

    // MARK: - Embedding Model UI

    private var embeddingModelPicker: some View {
        Picker("Embedding Model", selection: embeddingSelectionBinding) {
            ForEach(embeddingOptions) { option in
                Text(option.title)
                    .tag(option.id)
            }
        }
        .labelsHidden()
        .frame(width: controlColumnWidth, alignment: .trailing)
        .disabled(isPullingEmbeddingModel)
    }

    private var embeddingOptions: [EmbeddingModelOption] {
        var options = EmbeddingModelOption.curated
        let currentValue = displayedEmbeddingModel ?? committedEmbeddingModel

        if let currentValue,
           !options.contains(where: { $0.storageValue == currentValue }) {
            options.append(.custom(currentValue))
        }

        return options
    }

    private var selectedEmbeddingOption: EmbeddingModelOption {
        if let option = embeddingOptions.first(where: { $0.storageValue == displayedEmbeddingModel }) {
            return option
        }

        if let displayedEmbeddingModel {
            return .custom(displayedEmbeddingModel)
        }

        return .none
    }

    private func isEmbeddingModelInstalled(_ modelName: String) -> Bool {
        appState.availableModels.contains { installedModel in
            installedModel.name == modelName
                || baseModelName(installedModel.name) == baseModelName(modelName)
        }
    }

    private func baseModelName(_ modelName: String) -> String {
        modelName.split(separator: ":").first.map(String.init) ?? modelName
    }

    private var embeddingSelectionBinding: Binding<String> {
        Binding(
            get: { selectedEmbeddingOption.id },
            set: { newValue in
                guard let option = embeddingOptions.first(where: { $0.id == newValue }) else { return }
                selectEmbeddingOption(option)
            }
        )
    }

    private func settingsRow<Content: View>(
        _ label: String,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: alignment, spacing: 20) {
            Text(label)
                .frame(width: settingsLabelWidth, alignment: .leading)

            Spacer(minLength: 12)

            content()
                .frame(width: controlColumnWidth, alignment: .trailing)
        }
    }

    private var selectedModelBinding: Binding<String> {
        Binding(
            get: { appState.selectedModel },
            set: { appState.selectedModel = $0 }
        )
    }
}
