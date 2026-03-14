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

    @State private var selectedModelName: String = ""

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
        .safeAreaInset(edge: .bottom) {
            Picker("Model", selection: $selectedModelName) {
                ForEach(appState.availableModels) { model in
                    Text(model.name).tag(model.name)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .labelsHidden()
            .onChange(of: selectedModelName) { _, newValue in
                appState.selectedModel = newValue
            }
        }
        .onAppear {
            selectedModelName = appState.selectedModel
            chatViewModel.fetchConversations()
        }
    }
}
