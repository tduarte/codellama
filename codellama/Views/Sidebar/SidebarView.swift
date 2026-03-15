//
//  SidebarView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    @Bindable var chatViewModel: ChatViewModel

    var body: some View {
        List(selection: $chatViewModel.selectedConversation) {
            if !appState.mcpHost.sortedServerStates.isEmpty {
                Section("Servers") {
                    ForEach(appState.mcpHost.sortedServerStates) { state in
                        serverRow(state)
                    }
                }
            }

            Section(chatViewModel.searchText.isEmpty ? "Conversations" : "Results") {
                ForEach(chatViewModel.filteredConversations) { conversation in
                    ConversationListItem(
                        conversation: conversation,
                        isSearchResult: !chatViewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                        .tag(conversation)
                        .contextMenu {
                            Button {
                                chatViewModel.exportConversation(conversation)
                            } label: {
                                Label("Export Markdown", systemImage: "square.and.arrow.up")
                            }

                            Button(role: .destructive) {
                                chatViewModel.deleteConversation(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        chatViewModel.deleteConversation(chatViewModel.filteredConversations[index])
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    chatViewModel.createConversation(model: appState.selectedModel)
                } label: {
                    Label("New Conversation", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .onAppear {
            chatViewModel.fetchConversations()
        }
    }

    @ViewBuilder
    private func serverRow(_ state: MCPServerRuntimeState) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor(for: state))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.serverName)
                    .font(.subheadline)
                Text(state.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            if state.lifecycle == .failed || state.lifecycle == .disconnected {
                Button {
                    Task { await appState.mcpHost.restart(serverName: state.serverName) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Restart \(state.serverName)")
            }
        }
        .padding(.vertical, 2)
    }

    private func statusColor(for state: MCPServerRuntimeState) -> Color {
        switch state.lifecycle {
        case .connected:
            return .green
        case .connecting, .restarting:
            return .orange
        case .failed:
            return .red
        case .disabled, .disconnected:
            return Color.secondary.opacity(0.5)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, ChatMessage.self, configurations: config)

    let conv1 = Conversation(title: "Build a REST API in Swift", model: "llama3.1:8b")
    let conv2 = Conversation(title: "SwiftUI layout tips", model: "codellama:7b")
    let conv3 = Conversation(title: "Explain actor isolation", model: "llama3.1:8b")
    container.mainContext.insert(conv1)
    container.mainContext.insert(conv2)
    container.mainContext.insert(conv3)

    let chatViewModel = ChatViewModel(modelContext: container.mainContext)
    chatViewModel.conversations = [conv1, conv2, conv3]

    return NavigationStack {
        SidebarView(chatViewModel: chatViewModel)
    }
    .environment(AppState.preview)
    .modelContainer(container)
    .frame(width: 280, height: 500)
}
