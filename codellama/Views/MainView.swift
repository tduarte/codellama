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
            } detail: {
                Group {
                    if let conversation = chatViewModel.selectedConversation {
                        ChatView(conversation: conversation, chatViewModel: chatViewModel)
                    } else {
                        ContentUnavailableView(
                            "Select a Conversation",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Choose a conversation from the sidebar or create a new one.")
                        )
                    }
                }
                .toolbar {
                    ToolbarItem {
                        if let conversation = chatViewModel.selectedConversation {
                            Button {
                                chatViewModel.exportConversation(conversation)
                            } label: {
                                Label("Export Conversation", systemImage: "square.and.arrow.up")
                            }
                        }
                    }

                    ToolbarSpacer(.fixed)

                    ToolbarItem {
                        Button {
                            presentCommandPalette()
                        } label: {
                            Label("Commands", systemImage: "command")
                        }
                    }

                    ToolbarSpacer(.fixed)

                    ToolbarItem {
                        Button {
                            showSkills.toggle()
                        } label: {
                            Label("Skills", systemImage: "wand.and.stars")
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { agentViewModel.showPlanTimeline },
                set: { if !$0 { agentViewModel.dismissTask() } }
            )) {
                if let task = agentViewModel.currentTask {
                    PlanTimelineView(
                        task: task,
                        onApprove: { Task { await agentViewModel.approve() } },
                        onCancel: { agentViewModel.cancel() },
                        onClose: { agentViewModel.dismissTask() }
                    )
                    .frame(minWidth: 500, minHeight: 400)
                }
            }
            .interactiveDismissDisabled(agentViewModel.isRunning)
            .inspector(isPresented: $showSkills) {
                SkillInspectorView(skillViewModel: skillViewModel)
            }
            .inspectorColumnWidth(min: 320, ideal: 380, max: 500)
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
                subtitle: "Browse and edit saved skill sequences.",
                systemImage: "wand.and.stars",
                category: "Quick Action",
                keywords: ["skills", "tools", "automation"]
            ) {
                showSkills.toggle()
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
                id: "skill-\(skill.id.uuidString)",
                title: skill.name,
                subtitle: skill.descriptionText.isEmpty ? "Saved skill" : skill.descriptionText,
                systemImage: "wand.and.stars",
                category: "Skill",
                keywords: skill.toolSequence.map { "\($0.serverName) \($0.toolName)" }
            ) {
                skillViewModel.selectedSkill = skill
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

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Conversation.self, ChatMessage.self, MCPServerConfig.self, Skill.self,
        configurations: config
    )
    let appState = AppState.preview
    let chatViewModel = ChatViewModel(modelContext: container.mainContext)
    let skillViewModel = SkillViewModel(modelContext: container.mainContext)
    let agentViewModel = AgentViewModel(
        ollamaClient: OllamaClient(),
        mcpHost: appState.mcpHost,
        modelContext: container.mainContext,
        contextIndexManager: appState.contextIndexManager
    )
    return MainView(chatViewModel: chatViewModel, agentViewModel: agentViewModel, skillViewModel: skillViewModel)
        .environment(appState)
        .modelContainer(container)
        .frame(width: 900, height: 620)
}
