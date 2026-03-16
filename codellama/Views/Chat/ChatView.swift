//
//  ChatView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(AppState.self) private var appState

    @Bindable var conversation: Conversation
    @Bindable var chatViewModel: ChatViewModel
    @State private var isTargetingFileDrop = false
    @State private var didInitialScroll = false

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                chatInput
            }
            .navigationTitle(conversation.title)
            .navigationSubtitle(conversation.model)
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

    // MARK: - Message List

    @ViewBuilder
    private var content: some View {
        if sortedMessages.isEmpty {
            ConversationEmptyStateView(
                selectedModel: conversation.model,
                availableModels: appState.availableModels,
                isCurrentModelAvailable: isCurrentModelAvailable,
                modelSelection: modelSelection,
                starters: chatViewModel.starters(for: conversation),
                onStarterSelected: { starter in
                    chatViewModel.applyStarter(starter, appState: appState)
                },
                onExploreMore: {
                    chatViewModel.reshuffleStarters(for: conversation)
                }
            )
        } else {
            messageList
        }
    }

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
            .defaultScrollAnchor(.bottom)
            .id(conversation.id)
            .onChange(of: sortedMessages.last?.content) {
                guard didInitialScroll else { return }
                scrollToBottom(proxy: proxy, animated: true)
            }
            .onChange(of: sortedMessages.count) {
                guard didInitialScroll else { return }
                scrollToBottom(proxy: proxy, animated: true)
            }
            .onChange(of: conversation.id) {
                didInitialScroll = false
                scrollToBottom(proxy: proxy, animated: false)
                didInitialScroll = true
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
                didInitialScroll = true
            }
        }
    }

    // MARK: - Chat Input

    private var chatInput: some View {
        ChatInputView(
            text: $chatViewModel.inputText,
            attachments: chatViewModel.pendingAttachments,
            canSend: chatViewModel.canSendCurrentInput,
            isGenerating: chatViewModel.isGenerating,
            isProcessingDrop: chatViewModel.isProcessingAttachmentDrop,
            isDropTargeted: isTargetingFileDrop,
            selectedModel: conversation.model,
            availableModels: appState.availableModels,
            isCurrentModelAvailable: isCurrentModelAvailable,
            modelSelection: modelSelection,
            onSend: {
                Task { await chatViewModel.send(appState: appState) }
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

    // MARK: - Helpers

    private var sortedMessages: [ChatMessage] {
        conversation.messages.sorted { $0.createdAt < $1.createdAt }
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

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMessage = sortedMessages.last else { return }

        guard animated else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
            return
        }

        withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}
