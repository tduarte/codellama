//
//  MainView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import AppKit
import SwiftUI
import SwiftData
import Defaults

struct MainView: View {
    @Environment(AppState.self) private var appState

    var chatViewModel: ChatViewModel
    var agentViewModel: AgentViewModel
    var skillViewModel: SkillViewModel

    @State private var showSkills = false

    var body: some View {
        switch appState.status {
        case .checking, .connecting:
            ProgressView("Connecting to Ollama...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ollamaNotFound:
            ContentUnavailableView {
                Label("Ollama Not Found", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Ollama is not installed on this Mac.")
            } actions: {
                Link("Download Ollama", destination: URL(string: "https://ollama.com/download")!)
                    .buttonStyle(.borderedProminent)

                Button("Retry") {
                    Task { await appState.startup() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ollamaNotRunning:
            ContentUnavailableView {
                Label("Ollama Not Running", systemImage: "bolt.slash")
            } description: {
                Text("Ollama is installed but not currently running.")
            } actions: {
                Button("Start Ollama") {
                    Task { await appState.startOllama() }
                }
                .buttonStyle(.borderedProminent)

                Button("Retry") {
                    Task { await appState.startup() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let message):
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.octagon")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await appState.startup() }
                }
                .buttonStyle(.borderedProminent)

                Button("Copy Error") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message, forType: .string)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready:
            NavigationSplitView {
                SidebarView(chatViewModel: chatViewModel)
                    .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 320)
            } detail: {
                NavigationStack {
                    detailContent
                        .toolbar {
                            ToolbarItem {
                                Button {
                                    chatViewModel.createConversation(model: appState.selectedModel)
                                } label: {
                                    Label("New Conversation", systemImage: "plus")
                                        .symbolRenderingMode(.hierarchical)
                                }
                                .keyboardShortcut("n", modifiers: .command)
                            }

                            ToolbarItem {
                                if let conversation = chatViewModel.selectedConversation {
                                    Button {
                                        chatViewModel.exportConversation(conversation)
                                    } label: {
                                        Label("Export Conversation", systemImage: "square.and.arrow.up")
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                }
                            }

                            ToolbarSpacer(.fixed)

                            ToolbarItem {
                                Button {
                                    presentCommandPalette()
                                } label: {
                                    Label("Commands", systemImage: "command")
                                        .symbolRenderingMode(.hierarchical)
                                }
                            }

                            ToolbarSpacer(.fixed)

                            ToolbarItem {
                                Button {
                                    showSkills.toggle()
                                } label: {
                                    Label("Skills", systemImage: "sidebar.right")
                                        .symbolRenderingMode(.hierarchical)
                                }
                            }
                        }
                        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
                }
            }
            .navigationSplitViewStyle(.balanced)
            .inspector(isPresented: $showSkills) {
                SkillInspectorView(skillViewModel: skillViewModel)
                    .inspectorColumnWidth(min: 280, ideal: 300, max: 400)
            }
            .sheet(isPresented: Binding(
                get: { agentViewModel.showPlanTimeline },
                set: { if !$0 { agentViewModel.dismissTask() } }
            )) {
                if let task = agentViewModel.currentTask {
                    PlanTimelineView(
                        task: task,
                        isRunning: agentViewModel.isRunning,
                        onApprove: { Task { await agentViewModel.approve() } },
                        onCancel: { agentViewModel.cancel() },
                        onClose: { agentViewModel.dismissTask() }
                    )
                    .frame(minWidth: 500, minHeight: 400)
                    .presentationDetents([.medium, .large])
                }
            }
            .interactiveDismissDisabled(agentViewModel.isRunning)
            .sheet(
                isPresented: Binding(
                    get: { appState.isCommandPalettePresented },
                    set: { appState.isCommandPalettePresented = $0 }
                )
            ) {
                CommandPaletteView(
                    isPresented: Binding(
                        get: { appState.isCommandPalettePresented },
                        set: { appState.isCommandPalettePresented = $0 }
                    ),
                    items: commandPaletteItems
                )
            }
            .onChange(of: appState.isCommandPalettePresented) { _, isPresented in
                if isPresented {
                    chatViewModel.fetchConversations()
                    skillViewModel.fetchSkills()
                }
            }
        }
    }

    private var commandPaletteItems: [CommandPaletteItem] {
        var items: [CommandPaletteItem] = [
            CommandPaletteItem(
                id: "new-conversation",
                title: "New Conversation",
                subtitle: "Create a fresh chat with the current default model.",
                systemImage: "square.and.pencil",
                category: "Quick Action",
                keywords: ["new chat", "conversation", "compose"]
            ) {
                chatViewModel.createConversation(model: appState.selectedModel)
            },
            CommandPaletteItem(
                id: "open-skills",
                title: "Open Skills",
                subtitle: "Browse installed SKILL.md skills from configured roots.",
                systemImage: "wand.and.stars",
                category: "Quick Action",
                keywords: ["skills", "tools", "automation"]
            ) {
                showSkills = true
            },
            CommandPaletteItem(
                id: "open-settings",
                title: "Open Settings",
                subtitle: "Change Ollama, MCP server, and indexing settings.",
                systemImage: "gearshape",
                category: "Quick Action",
                keywords: ["preferences", "settings", "configuration"]
            ) {
                openSettings()
            },
            CommandPaletteItem(
                id: "reindex-context",
                title: "Reindex Local Context",
                subtitle: "Refresh embeddings for attached folders.",
                systemImage: "arrow.triangle.2.circlepath",
                category: "Quick Action",
                keywords: ["index", "embeddings", "context", "rag"]
            ) {
                Task {
                    await appState.contextIndexManager.reindexLocalFolders(
                        using: appState.ollamaClient,
                        embeddingModel: Defaults[.embeddingModel]
                    )
                }
            }
        ]

        if chatViewModel.isGenerating {
            items.append(
                CommandPaletteItem(
                    id: "stop-generation",
                    title: "Stop Response",
                    subtitle: "Cancel the active streaming response.",
                    systemImage: "stop.circle",
                    category: "Quick Action",
                    keywords: ["cancel", "stop", "generation", "stream"]
                ) {
                    chatViewModel.stopGenerating()
                }
            )
        }

        if let conversation = chatViewModel.selectedConversation {
            items.append(
                CommandPaletteItem(
                    id: "export-\(conversation.id.uuidString)",
                    title: "Export Current Conversation",
                    subtitle: conversation.title,
                    systemImage: "square.and.arrow.up",
                    category: "Quick Action",
                    keywords: ["export", "markdown", "share"]
                ) {
                    chatViewModel.exportConversation(conversation)
                }
            )
        }

        let unhealthyServers = appState.mcpHost.sortedServerStates.filter {
            $0.lifecycle == .failed || $0.lifecycle == .disconnected
        }
        items.append(contentsOf: unhealthyServers.map { state in
            CommandPaletteItem(
                id: "restart-\(state.serverName)",
                title: "Restart \(state.serverName)",
                subtitle: state.statusSummary,
                systemImage: "arrow.clockwise",
                category: "Server",
                keywords: ["restart", "server", state.serverName]
            ) {
                Task { await appState.mcpHost.restart(serverName: state.serverName) }
            }
        })

        items.append(contentsOf: chatViewModel.conversations.map { conversation in
            CommandPaletteItem(
                id: "conversation-\(conversation.id.uuidString)",
                title: conversation.title,
                subtitle: "Conversation • \(conversation.model)",
                systemImage: "bubble.left.and.bubble.right",
                category: "Conversation",
                keywords: [conversation.model, conversation.systemPrompt ?? ""]
            ) {
                chatViewModel.selectConversation(conversation)
            }
        })

        items.append(contentsOf: skillViewModel.skills.map { skill in
            CommandPaletteItem(
                id: "skill-\(skill.id)",
                title: skill.name,
                subtitle: skill.descriptionText.isEmpty ? skill.sourceLabel : skill.descriptionText,
                systemImage: "wand.and.stars",
                category: "Skill",
                keywords: skill.headings + [skill.sourceLabel]
            ) {
                skillViewModel.selectSkill(skill)
                showSkills = true
            }
        })

        return items
    }

    private func presentCommandPalette() {
        chatViewModel.fetchConversations()
        skillViewModel.fetchSkills()
        appState.isCommandPalettePresented = true
    }

    @ViewBuilder
    private var detailContent: some View {
        if let conversation = chatViewModel.selectedConversation {
            ChatView(
                conversation: conversation,
                chatViewModel: chatViewModel,
                agentViewModel: agentViewModel,
                installedSkillNames: skillViewModel.skills.map(\.name)
            )
        } else {
            LaunchConversationView(
                chatViewModel: chatViewModel,
                agentViewModel: agentViewModel
            )
        }
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

private struct LaunchConversationView: View {
    @Environment(AppState.self) private var appState

    @Bindable var chatViewModel: ChatViewModel
    @Bindable var agentViewModel: AgentViewModel

    @State private var isTargetingFileDrop = false

    var body: some View {
        ConversationEmptyStateView(
            starters: chatViewModel.starters(for: nil),
            onStarterSelected: { starter in
                chatViewModel.applyStarter(starter, appState: appState)
            },
            onExploreMore: {
                chatViewModel.reshuffleStarters(for: nil)
            }
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            chatInput
        }
        .navigationTitle("New Conversation")
        .navigationSubtitle(appState.selectedModel)
        .dropDestination(for: URL.self) { items, _ in
            Task {
                await chatViewModel.addDroppedFiles(items.filter(\.isFileURL))
            }
            return true
        } isTargeted: { isTargetingFileDrop = $0 }
        .alert("Chat Error", isPresented: errorBinding) {
            Button("OK") {
                chatViewModel.error = nil
            }
        } message: {
            Text(chatViewModel.error ?? "Unknown error")
        }
    }

    private var chatInput: some View {
        ChatInputView(
            text: $chatViewModel.inputText,
            composerMode: Binding(
                get: { chatViewModel.composerMode },
                set: { chatViewModel.composerMode = $0 }
            ),
            attachments: chatViewModel.pendingAttachments,
            canSend: chatViewModel.canSendInCurrentMode,
            isGenerating: chatViewModel.isGenerating,
            isAgentBusy: agentViewModel.currentTask != nil,
            isProcessingDrop: chatViewModel.isProcessingAttachmentDrop,
            isDropTargeted: isTargetingFileDrop,
            selectedModel: appState.selectedModel,
            availableModels: appState.availableModels,
            isCurrentModelAvailable: isCurrentModelAvailable,
            modelSelection: launchModelSelection,
            onSendChat: {
                Task { await chatViewModel.send(appState: appState) }
            },
            onSendAgent: {
                Task { await runAgentFromLaunch() }
            },
            onStop: {
                chatViewModel.stopGenerating()
            },
            onRemoveAttachment: { attachment in
                chatViewModel.removePendingAttachment(attachment)
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var launchModelSelection: Binding<String> {
        Binding(
            get: { appState.selectedModel },
            set: { newValue in
                appState.selectedModel = newValue
            }
        )
    }

    private var isCurrentModelAvailable: Bool {
        appState.availableModels.contains { $0.name == appState.selectedModel }
    }

    private func runAgentFromLaunch() async {
        guard chatViewModel.pendingAttachments.isEmpty else {
            chatViewModel.error = "Attachments are only supported in chat mode."
            return
        }

        let prompt = chatViewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        let conversation = chatViewModel.selectedConversation ?? chatViewModel.createConversation(model: appState.selectedModel)
        chatViewModel.inputText = ""
        chatViewModel.error = nil

        do {
            try await agentViewModel.runAgent(
                prompt: prompt,
                model: conversation.model,
                conversation: conversation
            )
        } catch {
            chatViewModel.error = error.localizedDescription
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { chatViewModel.error != nil },
            set: { newValue in
                if !newValue {
                    chatViewModel.error = nil
                }
            }
        )
    }
}
