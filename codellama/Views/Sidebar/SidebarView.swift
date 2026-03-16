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
        .searchable(text: $chatViewModel.searchText, placement: .sidebar)
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
            Image(systemName: statusSymbol(for: state))
                .foregroundStyle(statusColor(for: state))
                .symbolRenderingMode(.hierarchical)
                .font(.subheadline)
                .frame(width: 16)

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

    private func statusSymbol(for state: MCPServerRuntimeState) -> String {
        switch state.lifecycle {
        case .connected:
            return "circle.fill"
        case .connecting, .restarting:
            return "circle.dotted"
        case .failed:
            return "exclamationmark.circle.fill"
        case .disabled, .disconnected:
            return "circle"
        }
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
            return .secondary
        }
    }
}
