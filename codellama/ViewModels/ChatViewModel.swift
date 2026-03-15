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
import PDFKit
import UniformTypeIdentifiers

struct PendingChatAttachment: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case text
        case pdf
        case image

        var systemImage: String {
            switch self {
            case .text:
                return "doc.text"
            case .pdf:
                return "doc.richtext"
            case .image:
                return "photo"
            }
        }

        var displayLabel: String {
            switch self {
            case .text:
                return "Text"
            case .pdf:
                return "PDF"
            case .image:
                return "Image"
            }
        }
    }

    let id: UUID
    let url: URL
    let kind: Kind
    let displayName: String
    let fileExtension: String
    let content: String
    let byteCount: Int
    let detailText: String
    let imageAttachment: ChatImageAttachment?

    init(
        url: URL,
        kind: Kind,
        content: String,
        byteCount: Int,
        detailText: String,
        imageAttachment: ChatImageAttachment? = nil
    ) {
        self.id = UUID()
        self.url = url
        self.kind = kind
        self.displayName = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        self.content = content
        self.byteCount = byteCount
        self.detailText = detailText
        self.imageAttachment = imageAttachment
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    var promptHeading: String {
        switch kind {
        case .text:
            return "Attached file"
        case .pdf:
            return "Attached PDF"
        case .image:
            return "Attached image"
        }
    }
}

@MainActor
@Observable
final class ChatViewModel {
    // MARK: - State

    var conversations: [Conversation] = []
    var selectedConversation: Conversation?
    var searchText: String = ""
    var inputText: String = ""
    var isGenerating: Bool = false
    var isProcessingAttachmentDrop: Bool = false
    var pendingAttachments: [PendingChatAttachment] = []
    var error: String?
    var launchStarters: [ConversationStarter] = []

    // MARK: - Private

    private var modelContext: ModelContext
    private var generationTask: Task<Void, Never>?
    private var conversationStarterIDs: [UUID: [String]] = [:]
    private let fileManager = FileManager.default
    private let starterCatalog = ConversationStarter.all
    private let textAttachmentExtensions: Set<String> = [
        "c", "cc", "cpp", "css", "go", "h", "hpp", "html", "java", "js", "json", "jsx",
        "md", "mjs", "py", "rb", "rs", "sh", "sql", "swift", "toml", "ts", "tsx", "txt",
        "xml", "yaml", "yml"
    ]
    private let imageAttachmentExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "bmp", "tif", "tiff", "webp", "heic", "heif"
    ]
    private let pdfAttachmentExtensions: Set<String> = ["pdf"]
    private let maxTextAttachmentFileSizeBytes = 128_000
    private let maxBinaryAttachmentFileSizeBytes = 8_000_000
    private let maxAttachmentCount = 6
    private let maxAttachmentCharacters = 20_000
    private let maxPDFPages = 12

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.launchStarters = Array(starterCatalog.shuffled().prefix(3))
    }

    // MARK: - Conversation Management

    func fetchConversations() {
        let sortDescriptor = SortDescriptor(\Conversation.modifiedAt, order: .reverse)
        let fetchDescriptor = FetchDescriptor<Conversation>(sortBy: [sortDescriptor])

        do {
            conversations = try modelContext.fetch(fetchDescriptor)
            for conversation in conversations where conversation.messages.isEmpty {
                if conversationStarterIDs[conversation.id] == nil {
                    conversationStarterIDs[conversation.id] = starterIDs()
                }
            }
        } catch {
            self.error = "Failed to fetch conversations: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createConversation(model: String) -> Conversation {
        let conversation = Conversation(title: "New Conversation", model: model)
        modelContext.insert(conversation)
        conversationStarterIDs[conversation.id] = starterIDs()
        try? modelContext.save()

        fetchConversations()
        selectedConversation = conversation

        return conversation
    }

    func deleteConversation(_ conversation: Conversation) {
        if selectedConversation?.id == conversation.id {
            selectedConversation = nil
        }

        conversationStarterIDs.removeValue(forKey: conversation.id)
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

    var canSendCurrentInput: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty
    }

    var hasPendingImageAttachments: Bool {
        pendingAttachments.contains { $0.kind == .image }
    }

    func send(appState: AppState) async {
        let attachments = pendingAttachments
        let prompt = composedPrompt(using: attachments)
        guard !prompt.isEmpty else { return }
        guard let client = appState.ollamaClient else {
            error = "Ollama is not connected."
            return
        }
        let conversation = selectedConversation ?? createConversation(model: appState.selectedModel)
        if attachments.contains(where: { $0.kind == .image }) {
            let supportsVision = await appState.modelSupportsVision(conversation.model)
            guard supportsVision else {
                error = "\(conversation.model) does not support image inputs."
                return
            }
        }

        // Clear input immediately
        inputText = ""
        pendingAttachments.removeAll()
        error = nil

        // Create user message
        let userMessage = ChatMessage(role: "user", content: prompt)
        userMessage.imageAttachments = attachments.compactMap(\.imageAttachment)
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

                // Accumulate tokens between flushes so SwiftUI re-renders at most every
                // 50 ms instead of on every individual token.
                var pendingContent = ""
                var lastFlushTime = ContinuousClock.now
                let flushInterval: Duration = .milliseconds(50)

                for try await chunk in await client.chatStream(request: request) {
                    if Task.isCancelled { break }

                    if let content = chunk.message?.content {
                        pendingContent += content
                    }

                    let now = ContinuousClock.now
                    if now - lastFlushTime >= flushInterval, !pendingContent.isEmpty {
                        assistantMessage.content += pendingContent
                        pendingContent = ""
                        lastFlushTime = now
                    }

                    if chunk.done {
                        // Flush the remainder of the buffer at stream end.
                        if !pendingContent.isEmpty {
                            assistantMessage.content += pendingContent
                            pendingContent = ""
                        }
                        conversation.modifiedAt = .now

                        // Auto-generate title from first exchange
                        if conversation.messages.count <= 2 {
                            generateTitle(client: client, conversation: conversation)
                        }
                    }
                }

                // Flush any tokens accumulated after the last timed flush (cancellation path).
                if !pendingContent.isEmpty {
                    assistantMessage.content += pendingContent
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

    func addDroppedFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }

        isProcessingAttachmentDrop = true
        defer { isProcessingAttachmentDrop = false }

        var attachments = pendingAttachments
        var failures: [String] = []
        let uniqueURLs = Array(Set(urls.map { $0.standardizedFileURL })).sorted { $0.path < $1.path }

        for url in uniqueURLs {
            if attachments.count >= maxAttachmentCount {
                failures.append("Only \(maxAttachmentCount) files can be attached at once.")
                break
            }

            if attachments.contains(where: { $0.url.standardizedFileURL == url }) {
                continue
            }

            do {
                let kind = try attachmentKind(for: url)
                let data = try Data(contentsOf: url)
                let content = try extractAttachmentContent(from: url, data: data, kind: kind)
                let imageAttachment = try makeImageAttachment(from: url, data: data, kind: kind)

                guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    failures.append("\(url.lastPathComponent): no readable content found.")
                    continue
                }

                attachments.append(
                    PendingChatAttachment(
                        url: url,
                        kind: kind,
                        content: content,
                        byteCount: data.count,
                        detailText: "\(kind.displayLabel) • \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))",
                        imageAttachment: imageAttachment
                    )
                )
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        pendingAttachments = attachments
        if failures.isEmpty {
            error = nil
        } else {
            error = failures.prefix(5).joined(separator: "\n")
        }
    }

    func removePendingAttachment(_ attachment: PendingChatAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
    }

    func starters(for conversation: Conversation?) -> [ConversationStarter] {
        if let conversation {
            return starters(for: conversationStarterIDs[conversation.id] ?? starterIDs())
        }

        return launchStarters
    }

    func reshuffleStarters(for conversation: Conversation?) {
        if let conversation {
            let currentIDs = Set(conversationStarterIDs[conversation.id] ?? [])
            let nextIDs = starterIDs(excluding: currentIDs)
            conversationStarterIDs[conversation.id] = nextIDs
            return
        }

        let currentIDs = Set(launchStarters.map(\.id))
        launchStarters = starters(for: starterIDs(excluding: currentIDs))
    }

    func applyStarter(_ starter: ConversationStarter, appState: AppState) {
        if selectedConversation == nil {
            _ = createConversation(model: appState.selectedModel)
        }

        pendingAttachments.removeAll()
        inputText = starter.prompt
        error = nil
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
            ollamaMessages.append(
                OllamaChatMessage(
                    role: role,
                    content: message.content,
                    images: message.imageAttachments.map(\.base64Data)
                )
            )
        }

        return ollamaMessages
    }

    private func composedPrompt(using attachments: [PendingChatAttachment]) -> String {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty || !attachments.isEmpty else { return "" }

        let documentAttachments = attachments.filter { $0.kind != .image }
        let imageAttachments = attachments.filter { $0.kind == .image }

        guard !documentAttachments.isEmpty else {
            if !trimmedInput.isEmpty {
                return trimmedInput
            }
            return imageAttachments.count == 1
                ? "Please analyze the attached image."
                : "Please analyze the attached images."
        }

        var sections: [String] = []
        if !trimmedInput.isEmpty {
            sections.append(trimmedInput)
        } else {
            sections.append("Please use the attached file context.")
        }

        let attachmentSections = documentAttachments.map { attachment in
            let fence = attachment.content.contains("```") ? "````" : "```"
            let language = attachment.kind == .text && fence == "```" ? attachment.fileExtension : "text"
            return [
                "\(attachment.promptHeading): \(attachment.url.path(percentEncoded: false))",
                "Source: \(attachment.detailText)",
                "",
                "\(fence)\(language)",
                attachment.content,
                fence
            ].joined(separator: "\n")
        }

        sections.append((["Attached file context:"] + attachmentSections).joined(separator: "\n\n"))

        if !imageAttachments.isEmpty {
            let names = imageAttachments.map(\.displayName).joined(separator: ", ")
            sections.append("Attached image\(imageAttachments.count == 1 ? "" : "s"): \(names)")
        }

        return sections.joined(separator: "\n\n")
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

    private func starters(for ids: [String]) -> [ConversationStarter] {
        ids.compactMap { id in
            starterCatalog.first(where: { $0.id == id })
        }
    }

    private func starterIDs(excluding excludedIDs: Set<String> = []) -> [String] {
        let eligibleStarters = starterCatalog.filter { !excludedIDs.contains($0.id) }
        let pool = eligibleStarters.count >= 3 ? eligibleStarters : starterCatalog
        return Array(pool.shuffled().prefix(3)).map(\.id)
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

    private func attachmentKind(for url: URL) throws -> PendingChatAttachment.Kind {
        let path = url.path(percentEncoded: false)
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw AttachmentError.fileNotFound
        }
        guard !isDirectory.boolValue else {
            throw AttachmentError.directoriesUnsupported
        }

        let ext = url.pathExtension.lowercased()
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        let size = values.fileSize ?? 0

        if textAttachmentExtensions.contains(ext) {
            if size > maxTextAttachmentFileSizeBytes {
                throw AttachmentError.fileTooLarge(maxTextAttachmentFileSizeBytes)
            }
            return .text
        }

        if pdfAttachmentExtensions.contains(ext) {
            if size > maxBinaryAttachmentFileSizeBytes {
                throw AttachmentError.fileTooLarge(maxBinaryAttachmentFileSizeBytes)
            }
            return .pdf
        }

        if imageAttachmentExtensions.contains(ext) {
            if size > maxBinaryAttachmentFileSizeBytes {
                throw AttachmentError.fileTooLarge(maxBinaryAttachmentFileSizeBytes)
            }
            return .image
        }

        throw AttachmentError.unsupportedFileType(ext.isEmpty ? "unknown" : ext)
    }

    private func extractAttachmentContent(
        from url: URL,
        data: Data,
        kind: PendingChatAttachment.Kind
    ) throws -> String {
        switch kind {
        case .text:
            return try clampAttachmentContent(decodeTextAttachment(data, from: url))
        case .pdf:
            return try extractPDFContent(from: url)
        case .image:
            return url.lastPathComponent
        }
    }

    private func makeImageAttachment(
        from url: URL,
        data: Data,
        kind: PendingChatAttachment.Kind
    ) throws -> ChatImageAttachment? {
        guard kind == .image else { return nil }
        guard let mimeType = imageMimeType(for: url) else {
            throw AttachmentError.unsupportedImageFormat
        }

        return ChatImageAttachment(
            fileName: url.lastPathComponent,
            mimeType: mimeType,
            base64Data: data.base64EncodedString()
        )
    }

    private func decodeTextAttachment(_ data: Data, from url: URL) throws -> String {
        for encoding in [String.Encoding.utf8, .utf16, .ascii, .isoLatin1] {
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }

        throw AttachmentError.unsupportedEncoding(url.lastPathComponent)
    }

    private func extractPDFContent(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw AttachmentError.unreadablePDF
        }

        let pageCount = min(document.pageCount, maxPDFPages)
        var pageSections: [String] = []

        for index in 0..<pageCount {
            guard let page = document.page(at: index) else { continue }

            let directText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !directText.isEmpty {
                pageSections.append("Page \(index + 1)\n\(directText)")
            }
        }

        guard !pageSections.isEmpty else {
            throw AttachmentError.noExtractableContent
        }

        return try clampAttachmentContent(pageSections.joined(separator: "\n\n"))
    }

    private func imageMimeType(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "bmp":
            return "image/bmp"
        case "tif", "tiff":
            return "image/tiff"
        case "webp":
            return "image/webp"
        case "heic":
            return "image/heic"
        case "heif":
            return "image/heif"
        default:
            return nil
        }
    }

    private func clampAttachmentContent(_ content: String) throws -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AttachmentError.noExtractableContent
        }

        guard trimmed.count > maxAttachmentCharacters else { return trimmed }

        let index = trimmed.index(trimmed.startIndex, offsetBy: maxAttachmentCharacters)
        return String(trimmed[..<index]) + "\n\n[Truncated after \(maxAttachmentCharacters) characters.]"
    }
}

enum AttachmentError: LocalizedError {
    case directoriesUnsupported
    case fileNotFound
    case fileTooLarge(Int)
    case noExtractableContent
    case unreadablePDF
    case unsupportedEncoding(String)
    case unsupportedFileType(String)
    case unsupportedImageFormat

    var errorDescription: String? {
        switch self {
        case .directoriesUnsupported:
            return "folders are not supported."
        case .fileNotFound:
            return "file could not be found."
        case .fileTooLarge(let bytes):
            let size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            return "file exceeds the \(size) attachment limit."
        case .noExtractableContent:
            return "no readable text could be extracted."
        case .unreadablePDF:
            return "PDF could not be opened."
        case .unsupportedEncoding:
            return "file could not be decoded as text."
        case .unsupportedFileType(let type):
            return "unsupported file type (\(type))."
        case .unsupportedImageFormat:
            return "image format is not supported for upload."
        }
    }
}
