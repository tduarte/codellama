//
//  SidebarView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    @Bindable var chatViewModel: ChatViewModel

    var body: some View {
        List(selection: $chatViewModel.selectedConversation) {
            ForEach(chatViewModel.conversations) { conversation in
                ConversationListItem(conversation: conversation)
                    .tag(conversation)
                    .contextMenu {
                        Button(role: .destructive) {
                            chatViewModel.deleteConversation(conversation)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    chatViewModel.deleteConversation(chatViewModel.conversations[index])
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
}
