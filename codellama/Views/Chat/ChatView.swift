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
        VStack(spacing: 0) {
            messageList
            Divider()
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
        .padding()
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

        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, ChatMessage.self, configurations: config)

    let conversation = Conversation(title: "Quicksort Discussion", model: "llama3.1:8b")
    let userMsg = ChatMessage(role: "user", content: "Explain quicksort and its time complexity.")
    let assistantMsg = ChatMessage(
        role: "assistant",
        content: "Quicksort is a **divide-and-conquer** sorting algorithm with **O(n log n)** average time complexity.\n\n```swift\nfunc quicksort<T: Comparable>(_ arr: [T]) -> [T] {\n    guard arr.count > 1 else { return arr }\n    let pivot = arr[arr.count / 2]\n    return quicksort(arr.filter { $0 < pivot })\n        + arr.filter { $0 == pivot }\n        + quicksort(arr.filter { $0 > pivot })\n}\n```"
    )
    container.mainContext.insert(conversation)
    container.mainContext.insert(userMsg)
    container.mainContext.insert(assistantMsg)
    userMsg.conversation = conversation
    assistantMsg.conversation = conversation

    let chatViewModel = ChatViewModel(modelContext: container.mainContext)

    return ChatView(conversation: conversation, chatViewModel: chatViewModel)
        .environment(AppState())
        .modelContainer(container)
        .frame(width: 700, height: 520)
}
