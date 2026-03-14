//
//  MainView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState

    var chatViewModel: ChatViewModel

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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready:
            NavigationSplitView {
                SidebarView(chatViewModel: chatViewModel)
            } detail: {
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
        }
    }
}
