//
//  ChatViewModel.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import SwiftData
import Defaults
import AppKit
import UniformTypeIdentifiers

@MainActor
@Observable
final class ChatViewModel {
    // MARK: - State

    var conversations: [Conversation] = []
    var selectedConversation: Conversation?
    var searchText: String = ""
    var inputText: String = ""
    var isGenerating: Bool = false
    var error: String?

    // MARK: - Private

    private var modelContext: ModelContext
    private var generationTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Conversation Management

    func fetchConversations() {
        let sortDescriptor = SortDescriptor(\Conversation.modifiedAt, order: .reverse)
        let fetchDescriptor = FetchDescriptor<Conversation>(sortBy: [sortDescriptor])

        do {
            conversations = try modelContext.fetch(fetchDescriptor)
        } catch {
            self.error = "Failed to fetch conversations: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createConversation(model: String) -> Conversation {
        let conversation = Conversation(title: "New Chat", model: model)
        modelContext.insert(conversation)
        try? modelContext.save()

        fetchConversations()
        selectedConversation = conversation

        return conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }

        modelContext.delete(conversation)
        try? modelContext.save()

        fetchConversations()
    }

    func selectConversation(_ conversation: Conversation) {
        selectedConversation = conversation
    }

    var filteredConversations: [Conversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return conversations }

        return conversations.filter { conversation in
            conversationMatchesSearch(conversation, query: query)
        }
    }

    func updateModel(_ model: String, for conversation: Conversation) {
        guard conversation.model != model else { return }

        conversation.model = model
        conversation.modifiedAt = .now
        try? modelContext.save()
        fetchConversations()
    }

    // MARK: - Messaging

    func send(appState: AppState) async {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        guard let client = appState.ollamaClient else {
            error = "Ollama is not connected."
            return
        }
        guard let conversation = selectedConversation else {
            error = "No conversation selected."
            return
        }

        // Clear input immediately
        inputText = ""
        error = nil

        // Create user message
        let userMessage = ChatMessage(role: "user", content: prompt)
        userMessage.conversation = conversation
        conversation.messages.append(userMessage)
        modelContext.insert(userMessage)

        // Create empty assistant message for streaming
        let assistantMessage = ChatMessage(role: "assistant", content: "", isStreaming: true)
        assistantMessage.conversation = conversation
        conversation.messages.append(assistantMessage)
        modelContext.insert(assistantMessage)

        conversation.modifiedAt = .now
        isGenerating = true

        generationTask = Task {
            defer {
                isGenerating = false
                assistantMessage.isStreaming = false
                try? modelContext.save()
            }

            do {
                let ollamaMessages = buildMessages(for: conversation)
                let request = OllamaChatRequest(
                    model: conversation.model,
                    messages: ollamaMessages,
                    stream: true
                )

                for try await chunk in await client.chatStream(request: request) {
                    if Task.isCancelled { break }

                    if let content = chunk.message?.content {
                        assistantMessage.content += content
                    }

                    if chunk.done {
                        conversation.modifiedAt = .now

                        // Auto-generate title from first exchange
                        if conversation.messages.count <= 2 {
                            generateTitle(client: client, conversation: conversation)
                        }
                    }
                }

                // Handle cancellation: mark the response accordingly
                if Task.isCancelled, !assistantMessage.content.isEmpty {
                    // Close any open code blocks
                    if assistantMessage.content.matches(of: /```/).count % 2 == 1 {
                        assistantMessage.content += "\n```\n"
                    }
                    assistantMessage.content += "\n\n_Generation stopped._"
                }
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                    if assistantMessage.content.isEmpty {
                        assistantMessage.content = "Error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func stopGenerating() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    func exportConversation(_ conversation: Conversation) {
        let panel = NSSavePanel()
        panel.title = "Export Conversation"
        panel.nameFieldStringValue = sanitizedExportFileName(for: conversation)
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try makeMarkdownExport(for: conversation).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            self.error = "Failed to export conversation: \(error.localizedDescription)"
        }
    }

    // MARK: - Title Generation

    private func generateTitle(client: OllamaClient, conversation: Conversation) {
        Task {
            var messages = buildMessages(for: conversation)
            messages.append(OllamaChatMessage(
                role: .user,
                content: "Reply with only a short title (5 words max) for this conversation. No markdown, no quotes."
            ))

            let request = OllamaChatRequest(
                model: conversation.model,
                messages: messages,
                stream: true
            )

            var title = ""

            do {
                for try await chunk in await client.chatStream(request: request) {
                    if Task.isCancelled { break }

                    if let content = chunk.message?.content {
                        title += content
                    }

                    if chunk.done {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                        if !trimmed.isEmpty {
                            conversation.title = trimmed
                            conversation.modifiedAt = .now
                            try? modelContext.save()
                            fetchConversations()
                        }
                    }
                }
            } catch {
                // Title generation is best-effort; ignore errors
            }
        }
    }

    // MARK: - Helpers

    private func buildMessages(for conversation: Conversation) -> [OllamaChatMessage] {
        var ollamaMessages: [OllamaChatMessage] = []

        // Prepend system prompt
        let systemPrompt = conversation.systemPrompt ?? Defaults[.systemPrompt]
        if !systemPrompt.isEmpty {
            ollamaMessages.append(OllamaChatMessage(role: .system, content: systemPrompt))
        }

        // Map conversation messages sorted by creation date
        let sorted = conversation.messages.sorted { $0.createdAt < $1.createdAt }
        for message in sorted {
            guard let role = OllamaRole(rawValue: message.role) else { continue }
            // Skip empty assistant messages (the one currently streaming)
            if role == .assistant && message.isStreaming && message.content.isEmpty {
                continue
            }
            ollamaMessages.append(OllamaChatMessage(role: role, content: message.content))
        }

        return ollamaMessages
    }

    private func conversationMatchesSearch(_ conversation: Conversation, query: String) -> Bool {
        let normalizedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        let searchableFields = [
            conversation.title,
            conversation.model,
            conversation.systemPrompt ?? ""
        ] + conversation.messages.map(\.content)

        return searchableFields.contains { field in
            field.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(normalizedQuery)
        }
    }

    private func makeMarkdownExport(for conversation: Conversation) -> String {
        let header = [
            "# \(conversation.title)",
            "",
            "- Model: \(conversation.model)",
            "- Created: \(conversation.createdAt.formatted(date: .abbreviated, time: .shortened))",
            "- Updated: \(conversation.modifiedAt.formatted(date: .abbreviated, time: .shortened))"
        ]

        let systemPromptSection: [String]
        if let systemPrompt = conversation.systemPrompt, !systemPrompt.isEmpty {
            systemPromptSection = [
                "",
                "## System Prompt",
                "",
                systemPrompt
            ]
        } else {
            systemPromptSection = []
        }

        let messageSections = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { message in
                [
                    "",
                    "## \(message.role.capitalized)",
                    "",
                    message.content.isEmpty ? "_Empty_" : message.content
                ].joined(separator: "\n")
            }

        return (header + systemPromptSection + messageSections).joined(separator: "\n")
    }

    private func sanitizedExportFileName(for conversation: Conversation) -> String {
        let rawName = conversation.title.isEmpty ? "Conversation" : conversation.title
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = rawName.components(separatedBy: invalidCharacters).joined(separator: "-")
        return cleaned + ".md"
    }
}
