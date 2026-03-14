//
//  ChatView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState

    @Bindable var conversation: Conversation
    @Bindable var chatViewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            chatInput
        }
        .navigationTitle(conversation.title)
        .navigationSubtitle(conversation.model)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Model", selection: modelSelection) {
                    if !isCurrentModelAvailable {
                        Text("\(conversation.model) (Unavailable)")
                            .tag(conversation.model)
                    }

                    ForEach(appState.availableModels) { model in
                        Text(model.name).tag(model.name)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 180)
                .disabled(chatViewModel.isGenerating)
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sortedMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: sortedMessages.last?.content) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: sortedMessages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: - Chat Input

    private var chatInput: some View {
        ChatInputView(
            text: $chatViewModel.inputText,
            isGenerating: chatViewModel.isGenerating,
            onSend: {
                Task { await chatViewModel.send(appState: appState) }
            },
            onStop: {
                chatViewModel.stopGenerating()
            }
        )
        .padding()
    }

    // MARK: - Helpers

    private var sortedMessages: [ChatMessage] {
        conversation.messages.sorted { $0.createdAt < $1.createdAt }
    }

    private var modelSelection: Binding<String> {
        Binding(
            get: { conversation.model },
            set: { newValue in
                chatViewModel.updateModel(newValue, for: conversation)
                appState.selectedModel = newValue
            }
        )
    }

    private var isCurrentModelAvailable: Bool {
        appState.availableModels.contains { $0.name == conversation.model }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = sortedMessages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}
